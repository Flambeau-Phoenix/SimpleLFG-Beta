"""Isolated security regressions. No production requests or credentials."""
import asyncio
import time
from concurrent.futures import ThreadPoolExecutor

import httpx
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from starlette.requests import Request
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware

import main
from moderation import ModerationStore
from security import Budgets, client_ip


@pytest.fixture(autouse=True)
def isolated(tmp_path, monkeypatch):
    monkeypatch.setattr(main, 'store', main.LfgStore())
    monkeypatch.setattr(main, 'messaging', main.MessagingStore())
    monkeypatch.setattr(main, 'moderation', ModerationStore(tmp_path / 'moderation.sqlite'))
    monkeypatch.setenv('LFG_TEST_ENTRY_FILE', str(tmp_path / 'no-test-entry.json'))
    monkeypatch.setenv('LFG_RESTORE_FILE', str(tmp_path / 'restore.json'))
    monkeypatch.setenv('LFG_ADMIN_KEY', 'a' * 64)
    monkeypatch.delenv('LFG_HMAC_SECRET', raising=False)
    main.budgets.reset()


@pytest.fixture
def client():
    with TestClient(main.app) as value:
        yield value


def session(client, name='Aria', steam='123456'):
    response = client.post('/api/lfg/session', json={'host': name, 'steam_id': steam})
    assert response.status_code == 200, response.text
    data = response.json()
    assert response.headers['cache-control'] == 'no-store'
    assert data['expires_in'] == 1800 and data['token'].startswith(data['session_id'] + '.')
    return data


def auth(data):
    return {'Authorization': 'Bearer ' + data['token']}


def post(client, data, **fields):
    payload = {'host': 'Aria', 'steam_id': '123456', 'activity': "Crabgantua's Gorge", 'undefined': 3, 'note': '100% + bonus (2) & friends; "hello"'}
    payload.update(fields)
    return client.post('/api/lfg/post', json=payload, headers=auth(data))


def test_automatic_sessions_and_privacy(client):
    a = session(client)
    posted = post(client, a)
    assert posted.status_code == 201 and posted.json()['listing']['activity'] == "Crabgantua's Gorge"
    assert post(client, a, note='Updated').status_code == 201
    assert len(main.store.listings) == 1
    public = client.get('/api/lfg/listings').json()[0]
    assert public['steam_id'] == '' and '_ip' not in public and 'token' not in public
    assert public['relay_session'] == a['session_id']
    assert client.post('/api/lfg/privacy', json={'share_steam_public': True}, headers=auth(a)).status_code == 200
    assert client.get('/api/lfg/listings').json()[0]['steam_id'] == '123456'


def test_blank_steam_contacts_remain_private_and_session_owned(client):
    a=client.post('/api/lfg/session',json={'host':'Aria'}).json()
    b=session(client,'Aria','')
    assert a['session_id']!=b['session_id']
    assert post(client,a,steam_id='',kind='LFG',undefined=0).status_code==201
    assert post(client,b,steam_id='',kind='LFM',undefined=1).status_code==201
    assert len(main.store.listings)==2
    assert all(row['steam_id']=='' for row in client.get('/api/lfg/listings').json())
    response=client.post('/api/lfg/chat',headers=auth(a),json={'recipient_id':b['session_id'],'message':'Whisper without Steam details'})
    assert response.status_code==201
    assert client.get('/api/lfg/chat',headers=auth(b)).json()['messages'][0]['sender_id']==a['session_id']
    assert not client.get('/api/lfg/chat',headers=auth(a)).json()['messages']
    assert client.post('/api/lfg/privacy',headers=auth(a),json={'share_steam_public':False}).status_code==200
    for bad in [None,123,'steam://bad','9'*21]:
        assert client.post('/api/lfg/session',json={'host':'Bad','steam_id':bad}).status_code==422


def test_optional_player_class_roundtrip_and_validation(client):
    a=session(client)
    for player_class in ['Warrior','Mage','Priest','Rogue']:
        response=post(client,a,player_class=player_class)
        assert response.status_code==201
        assert response.json()['listing']['player_class']==player_class
        assert client.get('/api/lfg/listings').json()[0]['player_class']==player_class
    # Use separate client IP/session budget for legacy omission and invalid fields.
    assert post(client,a).json()['listing']['player_class']==''
    for bad in ['Paladin','mage',None,123,'<script>']:
        assert post(client,a,player_class=bad).status_code==422
    restored=main.LfgPostRequest.model_validate({'host':'Old','activity':'Legacy'})
    assert restored.player_class==''


def test_inbox_and_listing_ownership(client):
    a, b = session(client), session(client, 'Other', '42')
    assert post(client, a).status_code == 201
    assert post(client, b).status_code == 403
    assert post(client, b, host='Other', steam_id='42').status_code == 201
    sent = client.post('/api/lfg/chat', headers=auth(a), json={'recipient_id': b['session_id'], 'message': '<script>alert("hi")</script> 100% + (hello)'})
    assert sent.status_code == 201
    assert sent.json()['chat']['sender_id'] == a['session_id']
    assert not client.get('/api/lfg/chat', headers=auth(a)).json()['messages']
    inbox = client.get('/api/lfg/chat', headers=auth(b)).json()
    assert len(inbox['messages']) == 1 and '<script>' in inbox['messages'][0]['message']
    assert not client.get('/api/lfg/chat?after=' + str(inbox['cursor']), headers=auth(b)).json()['messages']
    assert not main.messaging.messages
    for url in ['/api/lfg/chat', '/api/lfg/chat?recipient=Other']:
        assert client.get(url).status_code == 401
    for path, payload in [('/api/lfg/post', {'host':'Aria','steam_id':'123456','activity':'X'}), ('/api/lfg/chat', {'recipient_id': b['session_id'], 'message':'Hi'}), ('/api/lfg/privacy', {'share_steam_public':True})]:
        assert client.post(path, json=payload).status_code == 401
    forged = dict(a, token=a['session_id']+'.'+'0'*64)
    assert client.get('/api/lfg/chat', headers=auth(forged)).status_code == 401


def test_self_reported_identity_never_grants_ownership(client):
    a, b = session(client), session(client)
    assert post(client, a).status_code == 201
    assert client.post('/api/lfg/privacy', json={'share_steam_public':True}, headers=auth(b)).status_code == 200
    assert client.get('/api/lfg/listings').json()[0]['steam_id'] == ''
    assert not client.get('/api/lfg/chat', headers=auth(b)).json()['messages']


@pytest.mark.parametrize('field,value', [('undefined',True),('warriors','2'),('note','bad\x00text'),('steam_id','123\n'),('steam_id',123),('extra','x'),('share_steam_public','true'),('note','x'*65),('host',' '),('activity',' '),('note','bad\x7ftext')])
def test_strict_validation(client, field, value):
    assert post(client, session(client), **{field:value}).status_code == 422


def test_party_size_and_control_characters(client):
    a=session(client)
    assert post(client,a,warriors=2,undefined=3).status_code == 422
    assert client.post('/api/lfg/chat',headers=auth(a),json={'recipient_id':'a'*32,'message':'\x00'}).status_code == 422
    assert client.post('/api/lfg/session',json={'host':'\x00','steam_id':'1'}).status_code == 422


def test_streamed_and_declared_body_caps(client):
    assert client.post('/api/lfg/session', content=b'x'*8193).status_code == 413
    def stream():
        yield b'x'*4096
        yield b'x'*4097
    assert client.post('/api/lfg/session', content=stream()).status_code == 413
    assert client.post('/api/lfg/session', content=b'{}', headers={'Content-Length':'9000'}).status_code == 413
    assert client.post('/api/lfg/session', content=b'{').status_code == 422


def test_shared_ceiling_counts_invalid_requests(client, monkeypatch):
    monkeypatch.setenv('LFG_REQUESTS_IP','3')
    for _ in range(3):
        assert client.post('/api/lfg/session',content=b'{').status_code == 422
    r=client.get('/health')
    assert r.status_code == 429 and int(r.headers['retry-after']) > 0


def test_session_churn_cannot_reset_ip_budget(client):
    for i in range(5): session(client,str(i),str(i))
    r=client.post('/api/lfg/session',json={'host':'Another','steam_id':'99'},headers={'X-Forwarded-For':'203.0.113.88','CF-Connecting-IP':'192.0.2.10','Forwarded':'for=1.2.3.4','X-Real-IP':'5.6.7.8'})
    assert r.status_code == 429 and 'retry-after' in r.headers


def test_quotas_and_no_message_eviction(client, monkeypatch):
    a,b=session(client),session(client,'Other','42')
    monkeypatch.setenv('LFG_QUEUED_PER_SENDER','2')
    for _ in range(2):
        assert client.post('/api/lfg/chat',headers=auth(a),json={'recipient_id':b['session_id'],'message':'Hello'}).status_code == 201
    before=list(main.messaging.messages)
    r=client.post('/api/lfg/chat',headers=auth(a),json={'recipient_id':b['session_id'],'message':'Flood'})
    assert r.status_code == 429 and main.messaging.messages == before
    monkeypatch.setenv('LFG_MAX_MESSAGES','2')
    assert client.post('/api/lfg/chat',headers=auth(a),json={'recipient_id':b['session_id'],'message':'Flood'}).status_code == 503


def test_capacity_and_expiry(client,monkeypatch):
    monkeypatch.setenv('LFG_SESSIONS_PER_IP','2')
    a,b=session(client),session(client,'Other','42')
    assert client.post('/api/lfg/session',json={'host':'Third','steam_id':'3'}).status_code == 429
    main.messaging.sessions[a['session_id']]['expires']=time.time()-1
    assert client.get('/api/lfg/chat',headers=auth(a)).status_code == 401
    session(client,'Third','3')
    monkeypatch.setenv('LFG_MAX_SESSIONS','2')
    assert client.post('/api/lfg/session',json={'host':'Fourth','steam_id':'4'}).status_code == 503
    monkeypatch.setenv('LFG_MAX_LISTINGS','1')
    assert post(client,b,host='Other',steam_id='42').status_code == 201
    main.store.listings[next(iter(main.store.listings))]['timestamp']=time.time()-901
    assert client.get('/api/lfg/listings').json()==[]


def test_recipient_budget_across_senders(client,monkeypatch):
    a,b,c=session(client),session(client,'B','2'),session(client,'C','3')
    monkeypatch.setenv('LFG_DELIVERIES_RECIPIENT','1')
    assert client.post('/api/lfg/chat',headers=auth(a),json={'recipient_id':c['session_id'],'message':'One'}).status_code==201
    assert client.post('/api/lfg/chat',headers=auth(b),json={'recipient_id':c['session_id'],'message':'Two'}).status_code==429


def test_bounded_limiter_and_atomic_capacity(monkeypatch):
    now=[0.0]; limiter=Budgets(capacity=2,clock=lambda:now[0])
    limiter.hit('test','one',2);limiter.hit('test','two',2)
    with pytest.raises(HTTPException) as exc:limiter.hit('test','three',2)
    assert exc.value.status_code==503
    now[0]=61;limiter.hit('test','three',2)
    assert len(limiter.rows)==len(limiter.expiry)==1
    monkeypatch.setenv('LFG_MAX_SESSIONS','4')
    def create(i):
        try:return main.messaging.create(str(i),str(i),str(i))
        except HTTPException:return None
    with ThreadPoolExecutor(max_workers=10) as pool: results=list(pool.map(create,range(30)))
    assert sum(r is not None for r in results)==4 and len(main.messaging.sessions)==4


def test_ipv6_and_untrusted_proxy_chain():
    def address(ip):
        return client_ip(Request({'type':'http','client':(ip,123),'headers':[(b'x-forwarded-for',b'1.2.3.4')]}))
    assert address('2001:db8::1')==address('2001:db8::99')=='2001:db8::/64'
    assert address('::ffff:192.0.2.5')==address('192.0.2.5')
    seen=[]
    async def endpoint(scope,receive,send):seen.append(scope['client'][0])
    wrapped=ProxyHeadersMiddleware(endpoint,trusted_hosts=['127.0.0.1','::1'])
    async def check(peer):
        await wrapped({'type':'http','client':(peer,1),'scheme':'http','headers':[(b'x-forwarded-for',b'198.51.100.12')]},None,None)
    asyncio.run(check('203.0.113.5'));asyncio.run(check('127.0.0.1'))
    assert seen==['203.0.113.5','198.51.100.12']


def test_admin_isolation_cors_and_redirect(client):
    assert client.post('/internal/lfg/admin',json={'action':'state','actor':'test'}).status_code==403
    r=client.post('/internal/lfg/admin',json={'action':'state','actor':'test'},headers={'X-LFG-Admin-Key':'a'*64})
    assert r.status_code==200 and 'security_counters' in r.json()['status']
    assert '/internal/lfg/admin' not in client.get('/openapi.json').json()['paths']
    assert client.get('/health',headers={'Origin':'https://evil.example'}).headers.get('access-control-allow-origin') is None
    assert client.get('/health',headers={'Origin':'https://webgameuniverse.com'}).headers['access-control-allow-origin']=='https://webgameuniverse.com'
    r=client.get('/lfg-board',follow_redirects=False)
    assert r.status_code==308 and r.headers['location']=='/lfg.html'


def test_event_queues_are_private_and_bounded(monkeypatch):
    from events import EventHub
    hub=EventHub();a=hub.subscribe('a','ip');b=hub.subscribe('b','ip')
    hub.notify('chat','b')
    assert a.empty() and b.get_nowait()=='chat'
    for _ in range(100):hub.notify('listings')
    assert a.qsize()<=8 and b.qsize()<=8
    assert 'sync' in list(a._queue)
    with pytest.raises(HTTPException) as exc:hub.subscribe('a','ip')
    assert exc.value.status_code==429
    monkeypatch.setenv('LFG_MAX_STREAMS','2')
    with pytest.raises(HTTPException) as exc:hub.subscribe('c','other')
    assert exc.value.status_code==503
    hub.unsubscribe('a',a);assert len(hub.clients)==1


def test_event_admission_released_before_generator_starts():
    from events import EventHub, EventResponse
    hub=EventHub();queue=hub.subscribe('a','ip')
    async def iterator():
        yield 'event: sync\ndata: {}\n\n'
    async def receive():
        return {'type':'http.disconnect'}
    async def failed_send(message):
        raise OSError('Disconnected before headers')
    async def exercise():
        response=EventResponse(iterator(),hub,'a',queue)
        try:await response({'type':'http','asgi':{'spec_version':'2.4'}},receive,failed_send)
        except Exception:pass
    asyncio.run(exercise())
    assert not hub.clients


def test_solo_lfg_and_legacy_lfm(client):
    a=session(client)
    assert post(client,a,kind='LFG',undefined=0).status_code==201
    row=client.get('/api/lfg/listings').json()[0]
    assert row['kind']=='LFG' and row['undefined']==0 and row['is_test'] is False
    assert post(client,a,kind='LFG',warriors=1,undefined=0).status_code==422
    assert post(client,a,kind='LFG',tanks=1,undefined=0).status_code==422
    assert post(client,a,kind='BOGUS').status_code==422
    assert post(client,a,is_test=True).status_code==422
    assert post(client,a).json()['listing']['kind']=='LFM'


def test_responder_echo_is_private_once_and_expires(tmp_path):
    from relay_testing import TestResponder
    now=[time.time()];config=tmp_path/'test-entry.json'
    config.write_text(__import__('json').dumps({'expires_at':now[0]+7200}))
    async def exercise():
        bot=TestResponder(main.store,main.messaging,main.events,main.moderation,main.LfgPostRequest,
                          main.send_private_message,path=config,clock=lambda:now[0])
        assert await bot.start(background=False)
        a=main.messaging.create('Aria','123','192.0.2.1');b=main.messaging.create('Other','456','192.0.2.2')
        sender=main.messaging.authenticate('Bearer '+a['token'],main.moderation.blocked)
        old_bot_id=bot.session_id
        row=main.store.listings[old_bot_id]
        assert row['is_test'] is True and row['kind']=='LFG' and row['share_steam_public'] is False
        main.send_private_message(sender,old_bot_id,'100% + <hello> café','192.0.2.1')
        assert await bot.service()
        rows=main.messaging.inbox(a['session_id'],0)['messages']
        assert len(rows)==1 and rows[0]['message']=='Test reply: 100% + <hello> café'
        assert not main.messaging.inbox(b['session_id'],0)['messages']
        await bot.service()
        assert len(main.messaging.inbox(a['session_id'],0)['messages'])==1
        now[0]+=301;assert await bot.service()
        assert bot.session_id==old_bot_id
        now[0]=bot.expires_at
        assert not await bot.service()
        assert old_bot_id not in main.store.listings and old_bot_id not in main.messaging.sessions
        assert old_bot_id not in main.events.clients and bot.authorization==''
        restarted=TestResponder(main.store,main.messaging,main.events,main.moderation,main.LfgPostRequest,
                                main.send_private_message,path=config,clock=lambda:now[0])
        assert not await restarted.start(background=False)
    asyncio.run(exercise())


def test_both_test_categories_have_private_replies_and_expire(tmp_path, monkeypatch):
    now=[time.time()]
    config=tmp_path/'test-entry.json'
    config.write_text(__import__('json').dumps({'expires_at':now[0]+7200}))
    monkeypatch.setenv('LFG_TEST_ENTRY_FILE',str(config))
    with TestClient(main.app) as client:
        rows=[r for r in client.get('/api/lfg/listings').json() if r['is_test']]
        assert len(rows)==2 and {r['kind'] for r in rows}=={'LFG','LFM'}
        assert len({r['relay_session'] for r in rows})==2
        assert all(r['steam_id']=='' for r in rows)
        assert all(not main.store.listings[r['relay_session']]['share_steam_public'] for r in rows)
        assert next(r for r in rows if r['kind']=='LFG')['undefined']==0
        assert next(r for r in rows if r['kind']=='LFM')['undefined']==1
        a=session(client,'Sender','123');b=session(client,'Other','456')
        async def exercise():
            sender=main.messaging.authenticate('Bearer '+a['token'],main.moderation.blocked)
            for bot in main.responders:
                # Stop its background task for deterministic servicing in this fixture.
                bot.task.cancel()
                try:
                    await bot.task
                except asyncio.CancelledError:
                    pass
                # Cancellation withdrew the contact; recreate it with the same absolute deadline.
                assert await bot.start(background=False)
                bot.clock=lambda:now[0]
                main.send_private_message(sender,bot.session_id,'Hello '+bot.kind,'192.0.2.1')
                assert await bot.service()
                assert await bot.service()
            inbox=main.messaging.inbox(a['session_id'],0)['messages']
            assert {m['message'] for m in inbox}=={'Test reply: Hello LFG','Test reply: Hello LFM'}
            assert len(inbox)==2 and len({m['sender_id'] for m in inbox})==2
            assert not main.messaging.inbox(b['session_id'],0)['messages']
            now[0]+=7200
            for bot in main.responders:
                assert not await bot.service()
                assert bot.session_id not in main.messaging.sessions
                assert bot.session_id not in main.store.listings
        client.portal.call(exercise)
        assert not [r for r in client.get('/api/lfg/listings').json() if r['is_test']]


def test_responder_restart_deadline_and_moderation(tmp_path):
    from relay_testing import TestResponder
    now=[time.time()];config=tmp_path/'test-entry.json';expiry=now[0]+7200
    config.write_text(__import__('json').dumps({'expires_at':expiry}))
    async def make():
        bot=TestResponder(main.store,main.messaging,main.events,main.moderation,main.LfgPostRequest,
                          main.send_private_message,path=config,clock=lambda:now[0])
        assert await bot.start(background=False)
        return bot
    async def exercise():
        bot=await make();old=bot.session_id;await bot.stop();now[0]+=600
        bot=await make();assert bot.session_id!=old and bot.expires_at==expiry
        main.store.listings.pop(bot.session_id)
        assert not await bot.service() and not bot.active
        main.moderation.block('0','Disable test','Fixture')
        blocked=TestResponder(main.store,main.messaging,main.events,main.moderation,main.LfgPostRequest,
                              main.send_private_message,path=config,clock=lambda:now[0])
        assert not await blocked.start(background=False)
    asyncio.run(exercise())


def test_responder_busy_queue_retries_without_duplicate(tmp_path,monkeypatch):
    from relay_testing import TestResponder
    now=[time.time()];config=tmp_path/'test-entry.json'
    config.write_text(__import__('json').dumps({'expires_at':now[0]+7200}))
    monkeypatch.setenv('LFG_QUEUED_PER_SENDER','1')
    async def exercise():
        bot=TestResponder(main.store,main.messaging,main.events,main.moderation,main.LfgPostRequest,
                          main.send_private_message,path=config,clock=lambda:now[0])
        assert await bot.start(background=False)
        a=main.messaging.create('A','1','192.0.2.1');b=main.messaging.create('B','2','192.0.2.2')
        for user in [a,b]:
            sender=main.messaging.authenticate('Bearer '+user['token'],main.moderation.blocked)
            main.send_private_message(sender,bot.session_id,'Hello','192.0.2.1')
        await bot.service()
        first=main.messaging.inbox(a['session_id'],0)['messages'];assert len(first)==1
        assert not main.messaging.inbox(b['session_id'],0)['messages']
        main.messaging.inbox(a['session_id'],first[0]['id'])
        now[0]+=61;await bot.service()
        assert len(main.messaging.inbox(b['session_id'],0)['messages'])==1
        assert not main.messaging.inbox(a['session_id'],0)['messages']
        await bot.stop()
    asyncio.run(exercise())


def test_responder_unicode_echo_fits_native_limit(tmp_path):
    from relay_testing import TestResponder
    config=tmp_path/'test-entry.json'
    config.write_text(__import__('json').dumps({'expires_at':time.time()+7200}))
    async def exercise():
        bot=TestResponder(main.store,main.messaging,main.events,main.moderation,main.LfgPostRequest,
                          main.send_private_message,path=config)
        assert await bot.start(background=False)
        user=main.messaging.create('A','1','192.0.2.1')
        sender=main.messaging.authenticate('Bearer '+user['token'],main.moderation.blocked)
        main.send_private_message(sender,bot.session_id,'\U0001f600'*120,'192.0.2.1')
        await bot.service()
        reply=main.messaging.inbox(user['session_id'],0)['messages'][0]['message']
        assert reply=='Test reply: '+'\U0001f600'*114 and len(reply.encode('utf-16-le'))==480
        await bot.stop()
    asyncio.run(exercise())


if __name__=='__main__':
    raise SystemExit(pytest.main([__file__,'-q']))
