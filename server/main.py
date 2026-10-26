"""Single-worker SimpleLFG relay. Client credentials are issued automatically."""
import asyncio
from contextlib import asynccontextmanager
import hmac
import json
import math
import os
from pathlib import Path
import re
import secrets
import time
import unicodedata
from typing import Literal
from relay_testing import TestResponder

from fastapi import Depends, FastAPI, HTTPException, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, RedirectResponse
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from messaging import MessagingStore
from moderation import ModerationStore
from security import RequestGuard, budgets, client_ip, setting
from events import EventHub, EventResponse

LISTING_TTL_SECONDS = 900
STARTED_AT = time.monotonic()
moderation = ModerationStore()
messaging = MessagingStore()
events = EventHub()


def clean_text(value, multiline=False):
    if not isinstance(value, str):
        return value
    if any(unicodedata.category(c) in ('Cc', 'Cs') and c not in ('\t', '\n', '\r') for c in value):
        raise ValueError('Control characters are not allowed.')
    if multiline:
        return value.replace('\r\n', '\n').replace('\r', '\n').strip()
    return ' '.join(value.split())


class StrictModel(BaseModel):
    model_config = ConfigDict(strict=True, extra='forbid')


class LfgPostRequest(StrictModel):
    kind: Literal["LFG", "LFM"] = "LFM"
    player_class: Literal["", "Warrior", "Mage", "Priest", "Rogue"] = ""
    host: str = Field(min_length=1, max_length=24)
    steam_id: str = Field(default='', pattern=r'^[0-9]{0,20}$')
    activity: str = Field(min_length=1, max_length=32)
    warriors: int = Field(default=0, ge=0, le=4)
    mages: int = Field(default=0, ge=0, le=4)
    priests: int = Field(default=0, ge=0, le=4)
    rogues: int = Field(default=0, ge=0, le=4)
    undefined: int = Field(default=0, ge=0, le=4)
    note: str = Field(default='', max_length=64)
    share_steam_public: bool = False
    tanks: int = Field(default=0, ge=0, le=4)
    heals: int = Field(default=0, ge=0, le=4)
    dps: int = Field(default=0, ge=0, le=4)

    @field_validator('host', 'activity', 'note', mode='before')
    @classmethod
    def text(cls, value):
        return clean_text(value)

    @model_validator(mode='after')
    def composition(self):
        if self.warriors + self.mages + self.priests + self.rogues + self.undefined == 0:
            self.warriors, self.priests, self.undefined = self.tanks, self.heals, self.dps
        if self.kind == 'LFG' and self.warriors + self.mages + self.priests + self.rogues + self.undefined != 0:
            raise ValueError('Solo LFG posts cannot advertise recruiting slots.')
        if self.warriors + self.mages + self.priests + self.rogues + self.undefined > 4:
            raise ValueError('Farever parties support at most four open slots.')
        return self


class LfgListing(BaseModel):
    kind: Literal["LFG", "LFM"] = "LFM"
    player_class: Literal["", "Warrior", "Mage", "Priest", "Rogue"] = ""
    is_test: bool = False
    id: str
    relay_session: str = ''
    host: str
    steam_id: str
    activity: str
    warriors: int
    mages: int
    priests: int
    rogues: int
    undefined: int
    note: str
    timestamp: float
    age_seconds: int = 0
    tanks: int = 0
    heals: int = 0
    dps: int = 0


class SessionRequest(StrictModel):
    host: str = Field(min_length=1, max_length=24)
    steam_id: str = Field(default='', pattern=r'^[0-9]{0,20}$')

    @field_validator('host', mode='before')
    @classmethod
    def text(cls, value):
        return clean_text(value)


class PrivateChatRequest(StrictModel):
    recipient_id: str = Field(pattern=r'^[0-9a-f]{32}$')
    message: str = Field(min_length=1, max_length=240)

    @field_validator('message', mode='before')
    @classmethod
    def text(cls, value):
        return clean_text(value, multiline=True)


class PrivacyRequest(StrictModel):
    share_steam_public: bool


class LfgStore:
    def __init__(self):
        self._lock = asyncio.Lock()
        self.listings = {}
        self.next_purge = 0

    async def purge_expired(self, now=None, force=False):
        now = time.time() if now is None else now
        if not force and now < self.next_purge:
            return 0
        self.next_purge = now + 60
        async with self._lock:
            old = len(self.listings)
            self.listings = {k: v for k, v in self.listings.items() if now - v['timestamp'] < LISTING_TTL_SECONDS}
            removed = old - len(self.listings)
            if removed:
                events.notify('listings')
            return removed

    async def put_listing(self, post, session_id='', ip='restored'):
        await self.purge_expired(force=True)
        key = session_id or 'restored_' + secrets.token_hex(16)
        async with self._lock:
            if moderation.blocked(post.steam_id):
                raise HTTPException(403, 'This Steam code is blocked.')
            if key not in self.listings:
                if len(self.listings) >= setting('MAX_LISTINGS', 200):
                    budgets.counters['listing_capacity'] += 1
                    raise HTTPException(503, 'The board is full. Try again shortly.', headers={'Retry-After': '60'})
                if ip != 'restored' and sum(r.get('_ip') == ip for r in self.listings.values()) >= setting('LISTINGS_PER_IP', 10):
                    budgets.counters['listings_ip_limited'] += 1
                    raise HTTPException(429, 'Too many listings on this network.', headers={'Retry-After': '60'})
            entry = post.model_dump(exclude={'tanks', 'heals', 'dps'})
            entry.update(id=key + '_' + secrets.token_hex(12), relay_session=session_id,
                         timestamp=time.time(), tanks=post.warriors, heals=post.priests,
                         dps=post.mages + post.rogues + post.undefined, _ip=ip)
            self.listings[key] = entry
            return entry

    async def get_active_listings(self):
        await self.purge_expired()
        async with self._lock:
            rows = [dict(r, age_seconds=max(0, int(time.time()-r['timestamp']))) for r in self.listings.values() if time.time()-r['timestamp'] < LISTING_TTL_SECONDS]
        return sorted(rows, key=lambda r: r['timestamp'], reverse=True)


store = LfgStore()
responders = []


@asynccontextmanager
async def lifespan(app):
    global responders
    restore = Path(os.getenv('LFG_RESTORE_FILE', str(Path(__file__).parent / 'data' / 'restore-listings.json')))
    if restore.is_file():
        try:
            rows = json.loads(restore.read_text(encoding='utf-8'))
            if isinstance(rows, list):
                for row in rows[:setting('MAX_LISTINGS', 200)]:
                    try:
                        if row.get('is_test'):
                            continue
                        post = LfgPostRequest.model_validate({k: v for k, v in row.items() if k in LfgPostRequest.model_fields})
                        stamp = float(row['timestamp'])
                        if not math.isfinite(stamp) or not time.time()-900 < stamp <= time.time():
                            continue
                        entry = await store.put_listing(post)
                        entry['timestamp'] = stamp
                        entry['id'] = str(row.get('id', entry['id']))[:128]
                    except (ValueError, TypeError, KeyError, HTTPException):
                        continue
        except (OSError, ValueError):
            budgets.counters['restore_failed'] += 1
        finally:
            restore.unlink(missing_ok=True)
    async def cleanup():
        while True:
            await asyncio.sleep(60)
            await store.purge_expired(force=True)
            messaging.purge(force=True)
            with budgets.lock:
                budgets.purge()
    responders = [TestResponder(store, messaging, events, moderation, LfgPostRequest,
                                send_private_message, kind=kind) for kind in ('LFG', 'LFM')]
    for responder in responders:
        await responder.start()
    task = asyncio.create_task(cleanup())
    try:
        yield
    finally:
        for responder in responders:
            await responder.stop()
        task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass


app = FastAPI(title='SimpleLFG relay', version='1.4.0', lifespan=lifespan)
# CORS wraps guard errors too. Neither mechanism authenticates native clients.
app.add_middleware(RequestGuard)
app.add_middleware(CORSMiddleware, allow_origins=['https://webgameuniverse.com'],
                   allow_credentials=False, allow_methods=['GET', 'POST'],
                   allow_headers=['Authorization', 'Content-Type'], expose_headers=['Retry-After'])


@app.exception_handler(RequestValidationError)
async def invalid_request(request, exc):
    budgets.counters['invalid_payload'] += 1
    # Do not echo private message content in validation diagnostics.
    return JSONResponse({'detail': 'Invalid request payload.'}, status_code=422)


async def private_session(request: Request):
    return messaging.authenticate(request.headers.get('Authorization'), moderation.blocked)


@app.post('/api/lfg/session')
async def create_session(request: Request, data: SessionRequest):
    ip = client_ip(request)
    budgets.hit('sessions_minute_ip', ip, 5)
    budgets.hit('sessions_hour_ip', ip, 30, 3600)
    if moderation.blocked(data.steam_id):
        raise HTTPException(403, 'This Steam code is blocked.')
    return JSONResponse(messaging.create(data.host, data.steam_id, ip), headers={'Cache-Control': 'no-store'})


@app.post('/api/lfg/post', status_code=201)
async def post_listing(request: Request, post: LfgPostRequest, session=Depends(private_session)):
    budgets.hit('posts_ip', client_ip(request), 30)
    budgets.hit('posts_session', session['id'], 5)
    if post.host != session['host'] or post.steam_id != session['steam_id']:
        raise HTTPException(403, 'Listing identity must match the session.')
    entry = await store.put_listing(post, session['id'], session['ip'])
    events.notify('listings')
    return {'status': 'success', 'message': 'Listing published successfully',
            'listing': {k: v for k, v in entry.items() if not k.startswith('_')}}


@app.get('/api/lfg/listings', response_model=list[LfgListing])
async def get_listings(request: Request):
    budgets.hit('listings_reads_ip', client_ip(request), 60)
    public = []
    for row in await store.get_active_listings():
        item = {k: v for k, v in row.items() if not k.startswith('_')}
        if not item.get('share_steam_public', False):
            code = item.get('steam_id', '')
            item['steam_id'] = ''
            if code:
                for field in ('note', 'activity', 'host'):
                    item[field] = item[field].replace(code, '[private]')
        address = item.get('relay_session', '')
        item['relay_session'] = address if messaging.address(address) else ''
        public.append(item)
    return public


@app.post('/api/lfg/privacy')
async def update_privacy(request: Request, data: PrivacyRequest, session=Depends(private_session)):
    budgets.hit('privacy_ip', client_ip(request), 30)
    budgets.hit('privacy_session', session['id'], 10)
    async with store._lock:
        for row in store.listings.values():
            if row.get('relay_session') == session['id']:
                row['share_steam_public'] = data.share_steam_public
    events.notify('listings')
    return {'status': 'success'}


def send_private_message(session, recipient_id, message, ip):
    budgets.hit('messages_ip', ip, 120)
    budgets.hit('messages_session', session['id'], 30)
    entry = messaging.send(session, recipient_id, message, moderation.blocked)
    events.notify('chat', recipient_id)
    return entry


@app.post('/api/lfg/chat', status_code=201)
async def relay_chat(request: Request, chat: PrivateChatRequest, session=Depends(private_session)):
    entry = send_private_message(session, chat.recipient_id, chat.message, client_ip(request))
    return JSONResponse({'status': 'success', 'chat': entry}, status_code=201, headers={'Cache-Control': 'no-store'})


@app.get('/api/lfg/chat')
async def poll_chat(request: Request, after: int = Query(0, ge=0, le=2147483647), session=Depends(private_session)):
    budgets.hit('inbox_ip', client_ip(request), 300)
    budgets.hit('inbox_session', session['id'], 60)
    return JSONResponse(messaging.inbox(session['id'], after), headers={'Cache-Control': 'no-store'})


@app.get('/api/lfg/events')
async def stream_events(request: Request, session=Depends(private_session)):
    budgets.hit('streams_ip', client_ip(request), 30)
    queue = events.subscribe(session['id'], client_ip(request))
    authorization = request.headers.get('Authorization')
    async def stream():
        try:
            yield 'event: sync\ndata: {}\n\n'
            while True:
                try:
                    kind = await asyncio.wait_for(queue.get(), timeout=15)
                except TimeoutError:
                    kind = None
                try:
                    messaging.authenticate(authorization, moderation.blocked)
                except HTTPException:
                    yield 'event: expired\ndata: {}\n\n'
                    return
                yield ('event: ' + kind + '\ndata: {}\n\n') if kind else ': heartbeat\n\n'
        finally:
            events.unsubscribe(session['id'], queue)
    return EventResponse(stream(), events, session['id'], queue)


@app.get('/health')
async def health():
    return {'status': 'healthy', 'service': 'farever-lfg-relay', 'version': '1.4.0', 'timestamp': time.time()}


@app.get('/lfg-board')
async def legacy_board():
    return RedirectResponse('/lfg.html', status_code=308)


class AdminRequest(StrictModel):
    action: str = Field(pattern=r"^(state|delete|block|unblock)$")
    actor: str = Field(min_length=1, max_length=40)
    listing_id: str = Field(default="", max_length=128)
    steam_id: str = Field(default="", max_length=20)
    reason: str = Field(default="", max_length=160)
    q: str = Field(default="", max_length=80)


async def verify_admin(request: Request):
    secret = os.environ.get("LFG_ADMIN_KEY", "")
    if not secret:
        raise HTTPException(status_code=503, detail="Relay administration is not configured.")
    supplied = request.headers.get("X-LFG-Admin-Key", "")
    if not re.fullmatch(r"[0-9a-f]{64}", secret) or not hmac.compare_digest(secret.encode(), supplied.encode()):
        raise HTTPException(status_code=403, detail="Administrator credentials required.")


@app.post("/internal/lfg/admin", dependencies=[Depends(verify_admin)], include_in_schema=False)
async def admin_control(data: AdminRequest):
    await store.purge_expired()
    if data.action == "state":
        listings = await store.get_active_listings()
        total = len(listings)
        query = data.q.strip().casefold()
        if query:
            listings = [x for x in listings if query in " ".join(str(x.get(k,'')) for k in ("host", "steam_id", "activity", "note", "player_class")).casefold()]
        return {"ok": True, "listings": listings[:200], "total": total,
                "status": {"online": True, "version": "1.4.0", "uptime_seconds": int(time.monotonic()-STARTED_AT),
                           "listing_ttl_seconds": LISTING_TTL_SECONDS, "generated_at": time.time(), "messaging_sessions": len(messaging.sessions), "security_counters": dict(budgets.counters), "test_entry_expires_at": min((r.expires_at for r in responders if r.active), default=None)},
                **moderation.overview()}
    reason = " ".join(data.reason.split())
    if not reason:
        raise HTTPException(status_code=422, detail="A moderation reason is required.")
    async with store._lock:
        if data.action == "delete":
            target = next((key for key, row in store.listings.items() if row["id"] == data.listing_id), None)
            if target is None:
                raise HTTPException(status_code=404, detail="The listing expired or changed. Refresh the panel.")
            moderation.removed(data.listing_id, reason, data.actor)
            del store.listings[target]
        else:
            if not re.fullmatch(r"[0-9]{1,20}", data.steam_id):
                raise HTTPException(status_code=422, detail="Use a numeric Steam ID or Friend Code.")
            if data.action == "block":
                moderation.block(data.steam_id, reason, data.actor)
                messaging.revoke(data.steam_id)
                store.listings = {key: row for key, row in store.listings.items() if row["steam_id"] != data.steam_id}
            elif not moderation.unblock(data.steam_id, reason, data.actor):
                raise HTTPException(status_code=404, detail="That Steam code is not blocked.")
    events.notify('listings')
    return {"ok": True, "action": data.action}


