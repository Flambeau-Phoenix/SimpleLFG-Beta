"""Operator-activated, expiring messaging fixture. Credentials never leave memory."""
import asyncio
import json
import math
import os
from pathlib import Path
import time
from fastapi import HTTPException
from security import budgets


class TestResponder:
    def __init__(self, store, messaging, events, moderation, post_model, send, *, path=None, clock=time.time, kind='LFG'):
        if kind not in ('LFG', 'LFM'):
            raise ValueError('Invalid test listing kind')
        self.kind = kind
        self.host = 'SimpleLFG Test' if kind == 'LFG' else 'SimpleLFG Test LFM'
        self.store, self.messaging, self.events = store, messaging, events
        self.moderation, self.post_model, self.send = moderation, post_model, send
        self.path = Path(path or os.getenv('LFG_TEST_ENTRY_FILE', '/etc/farever-lfg/test-entry.json'))
        self.clock = clock
        self.expires_at = 0
        self.session_id, self.authorization = '', ''
        self.queue = None
        self.task = None
        self.active = False
        self.after = 0
        self.next_refresh = 0
        self.next_retry = 0

    async def start(self, background=True):
        try:
            if not self.path.is_file():
                return False
            if self.path.stat().st_size > 1024:
                raise ValueError('Invalid test configuration')
            expiry = json.loads(self.path.read_text())['expires_at']
            if type(expiry) not in (float, int) or not math.isfinite(expiry):
                raise ValueError('Invalid test expiry')
            if not self.clock() < expiry <= self.clock() + 7260:
                return False
            self.expires_at = expiry
            if self.moderation.blocked('0'):
                return False
            credentials = self.messaging.create(self.host, '0', 'server-test')
            self.session_id = credentials['session_id']
            self.authorization = 'Bearer ' + credentials['token']
            self.queue = self.events.subscribe(self.session_id, 'server-test')
            self.active = True
            await self.refresh()
            if background:
                self.task = asyncio.create_task(self.run())
            return True
        except (OSError, ValueError, KeyError, TypeError, HTTPException):
            budgets.counters['test_start_failed'] += 1
            await self.withdraw()
            return False

    async def refresh(self):
        post = self.post_model(kind=self.kind, host=self.host, steam_id='0',
                               undefined=1 if self.kind == 'LFM' else 0,
                               activity='Messaging test',
                               note='TEST ONLY: message me for an automatic private reply.')
        entry = await self.store.put_listing(post, self.session_id, 'server-test')
        entry['is_test'] = True
        self.next_refresh = self.clock() + 300
        self.events.notify('listings')

    async def service(self):
        if not self.active:
            return False
        if self.clock() >= self.expires_at or self.session_id not in self.store.listings:
            await self.withdraw()
            return False
        try:
            session = self.messaging.authenticate(self.authorization, self.moderation.blocked)
            if self.clock() >= self.next_refresh:
                await self.refresh()
            if self.clock() < self.next_retry:
                return True
            inbox = self.messaging.inbox(self.session_id, self.after)
            for message in inbox['messages']:
                try:
                    # HashLink counts UTF-16 units; avoid splitting an emoji or exceeding its composer limit.
                    text = message['message'].encode('utf-16-le')[:456].decode('utf-16-le', errors='ignore')
                    self.send(session, message['sender_id'], 'Test reply: ' + text, 'server-test')
                except HTTPException as exc:
                    if exc.status_code in (429, 503):
                        self.next_retry = self.clock() + max(1, int((exc.headers or {}).get('Retry-After', '60')))
                        return True
                    if exc.status_code not in (403, 404):
                        raise
                self.after = message['id']
            self.messaging.inbox(self.session_id, self.after)
            self.next_retry = 0
            return True
        except HTTPException as exc:
            if exc.status_code in (401, 403):
                await self.withdraw()
                return False
            self.next_retry = self.clock() + 60
            return True

    async def run(self):
        try:
            while self.active:
                deadlines = [self.expires_at, max(self.next_refresh, self.next_retry)]
                if self.next_retry:
                    deadlines.append(self.next_retry)
                delay = max(.05, min(deadlines) - self.clock())
                try:
                    await asyncio.wait_for(self.queue.get(), timeout=delay)
                except TimeoutError:
                    pass
                await self.service()
        finally:
            await self.withdraw()

    async def withdraw(self):
        self.active = False
        if self.queue is not None:
            self.events.unsubscribe(self.session_id, self.queue)
        if self.session_id:
            async with self.store._lock:
                self.store.listings.pop(self.session_id, None)
            self.messaging.sessions.pop(self.session_id, None)
            self.messaging.purge(force=True)
            self.events.notify('listings')
        self.authorization = ''

    async def stop(self):
        if self.task is not None:
            self.task.cancel()
            try:
                await self.task
            except asyncio.CancelledError:
                pass
        await self.withdraw()
