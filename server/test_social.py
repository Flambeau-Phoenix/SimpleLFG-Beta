"""Social protocol regressions; temporary local stores, no production requests."""
import time
import pytest
from fastapi import HTTPException
import main
from test_server import client, isolated, session, auth, post


def modern(client, name):
    response = client.post('/api/lfg/session', json={'host': name, 'features': ['social-v1']})
    assert response.status_code == 200
    assert response.json()['features'] == ['social-v1']
    return response.json()


def send(client, sender, recipient):
    response = client.post('/api/lfg/chat', json={'recipient_id': recipient['session_id'], 'message': '100% ready\nSecond line'}, headers=auth(sender))
    assert response.status_code == 201, response.text
    return response.json()['chat']


def test_capability_and_independent_contact_consent(client):
    assert client.get('/api/lfg/capabilities').json() == {'features': ['social-v1']}
    a = modern(client, 'Aria')
    code = 'ABCD-EFGH-JKLM'
    payload = {'host': 'Aria', 'activity': 'Boss', 'farever_code': code, 'note': code, 'steam_id': ''}
    assert client.post('/api/lfg/post', json=payload, headers=auth(a)).status_code == 201
    row = client.get('/api/lfg/listings').json()[0]
    assert row['farever_code'] == '' and code not in row['note']
    payload['share_farever_public'] = True
    assert client.post('/api/lfg/post', json=payload, headers=auth(a)).status_code == 201
    row = client.get('/api/lfg/listings').json()[0]
    assert row['farever_code'] == code and row['steam_id'] == ''
    assert client.post('/api/lfg/privacy', json={'share_steam_public': False, 'share_farever_public': False}, headers=auth(a)).status_code == 200
    assert client.get('/api/lfg/listings').json()[0]['farever_code'] == ''
    payload['farever_code'] = '123'
    assert client.post('/api/lfg/post', json=payload, headers=auth(a)).status_code == 422


def test_withdraw_requires_private_owner_and_current_version(client):
    a = session(client)
    b = session(client)
    row = post(client, a).json()['listing']
    route = '/api/lfg/post/delete'
    assert client.post(route, json={'listing_id': row['id']}).status_code == 401
    assert client.post(route, json={'listing_id': row['id']}, headers=auth(b)).status_code == 404
    replacement = post(client, a).json()['listing']
    assert client.post(route, json={'listing_id': row['id']}, headers=auth(a)).status_code == 404
    assert client.post(route, json={'listing_id': replacement['id']}, headers=auth(a)).status_code == 200
    assert client.get('/api/lfg/listings').json() == []


def test_delete_after_delivery_and_ack_survives_missed_event(client):
    a, b = modern(client, 'Alice'), modern(client, 'Bob')
    row = send(client, a, b)
    inbox = client.get('/api/lfg/chat', headers=auth(b)).json()
    assert inbox['messages'][0]['message'] == '100% ready\nSecond line'
    client.get('/api/lfg/chat', params={'after': row['id']}, headers=auth(b))
    assert not main.messaging.messages
    assert 'message' not in main.messaging.ledger[row['id']]
    route = '/api/lfg/chat/delete'
    assert client.post(route, json={'message_id': row['id']}, headers=auth(b)).status_code == 404
    assert client.post(route, json={'message_id': row['id']}, headers=auth(a)).status_code == 200
    again = client.post(route, json={'message_id': row['id']}, headers=auth(a))
    assert again.status_code == 200 and again.json()['deleted']['deletion'] == 1
    for participant in (a, b):
        sync = client.get('/api/lfg/chat', params={'after': row['id']}, headers=auth(participant)).json()
        assert sync['deleted'][0]['id'] == row['id'] and sync['deletion_cursor'] == 1
        assert 'message' not in sync['deleted'][0]
        assert client.get('/api/lfg/chat', params={'deleted_after': 1}, headers=auth(participant)).json()['deleted'] == []


def test_legacy_recipient_retraction_is_honest(client):
    a, b = modern(client, 'Alice'), session(client, 'Bob')
    row = send(client, a, b)
    client.get('/api/lfg/chat', headers=auth(b))
    result = client.post('/api/lfg/chat/delete', json={'message_id': row['id']}, headers=auth(a))
    assert result.status_code == 409
    assert main.messaging.messages[0]['message']
    queued = send(client, a, b)
    assert client.post('/api/lfg/chat/delete', json={'message_id': queued['id']}, headers=auth(a)).status_code == 200
    assert all(m['id'] != queued['id'] for m in main.messaging.messages)


def test_deletion_pagination_expiry_and_bounded_metadata(client):
    a, b = modern(client, 'Alice'), modern(client, 'Bob')
    sender = main.messaging.address(a['session_id'])
    for i in range(55):
        main.budgets.reset()
        row = main.messaging.send(sender, b['session_id'], 'Temporary body', lambda _: False)
        main.messaging.inbox(b['session_id'], row['id'])
        main.messaging.delete(sender, row['id'])
    first = main.messaging.inbox(b['session_id'], 55)
    assert len(first['deleted']) == 50 and first['deletion_cursor'] == 50
    rest = main.messaging.inbox(b['session_id'], 55, first['deletion_cursor'])
    assert len(rest['deleted']) == 5 and rest['deletion_cursor'] == 55
    for entry in main.messaging.ledger.values():
        entry['timestamp'] = time.time()-1801
    with pytest.raises(HTTPException) as expired:
        main.messaging.delete(sender, 1)
    assert expired.value.status_code == 404 and not main.messaging.ledger
    template = {'sender_id': a['session_id'], 'recipient_id': b['session_id'], 'timestamp': time.time()}
    main.messaging.ledger = {i: dict(template) for i in range(5000)}
    with pytest.raises(HTTPException) as full:
        main.messaging.send(sender, b['session_id'], 'No silent eviction', lambda _: False)
    assert full.value.status_code == 503 and len(main.messaging.ledger) == 5000
