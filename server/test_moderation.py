"""Isolated moderation regressions; never contact production."""
import asyncio
import hashlib
import hmac
import json
import time

import pytest
from fastapi.testclient import TestClient
import main
from moderation import ModerationStore


@pytest.fixture(autouse=True)
def isolated(tmp_path, monkeypatch):
    key = tmp_path / 'admin.key'
    key.write_text('a' * 64)
    monkeypatch.setenv('LFG_ADMIN_KEY', 'a' * 64)
    monkeypatch.setenv('LFG_TEST_ENTRY_FILE', str(tmp_path / 'no-test-entry.json'))
    monkeypatch.setenv('LFG_RESTORE_FILE', str(tmp_path / 'restore.json'))
    monkeypatch.setattr(main, 'moderation', ModerationStore(tmp_path / 'moderation.sqlite'))
    monkeypatch.setattr(main, 'store', main.LfgStore())
    monkeypatch.setattr(main, 'messaging', main.MessagingStore())
    main.budgets.reset()


def admin(client, action='state', **fields):
    return client.post('/internal/lfg/admin', json={'action': action, 'actor': 'WguAdmin', **fields},
                       headers={'X-LFG-Admin-Key': 'a' * 64})


def post(client, host='Aria', steam_id='123456'):
    sessions = getattr(client, '_fixture_sessions', {})
    client._fixture_sessions = sessions
    if host not in sessions:
        result = client.post('/api/lfg/session', json={'host': host, 'steam_id': steam_id})
        if result.status_code != 200:
            return result
        sessions[host] = result.json()['token']
    return client.post('/api/lfg/post', json={'host': host, 'steam_id': steam_id, 'activity': 'Boss farm', 'undefined': 2, 'note': 'Join us'},
                       headers={'Authorization': 'Bearer ' + sessions[host]})


def test_private_admin_credentials_and_schema(monkeypatch):
    with TestClient(main.app) as client:
        assert client.post('/internal/lfg/admin', json={'action': 'state', 'actor': 'x'}).status_code == 403
        assert client.post('/internal/lfg/admin', json={'action': 'state', 'actor': 'x'}, headers={'X-LFG-Admin-Key': 'b' * 64}).status_code == 403
        assert '/internal/lfg/admin' not in client.get('/openapi.json').json()['paths']
        monkeypatch.delenv('LFG_ADMIN_KEY')
        assert admin(client).status_code == 503


def test_search_expiry_and_status():
    with TestClient(main.app) as client:
        assert post(client).status_code == 201
        assert post(client, 'Other', '654321').status_code == 201
        result = admin(client, q='ARIA').json()
        assert len(result['listings']) == 1 and result['total'] == 2
        assert result['status']['online'] and result['status']['listing_ttl_seconds'] == 900
        assert len(admin(client, q='654321').json()['listings']) == 1
        assert not admin(client, q='no match').json()['listings']
        next(r for r in main.store.listings.values() if r['host'] == 'Aria')['timestamp'] = time.time() - 901
        assert admin(client).json()['total'] == 1


def test_delete_requires_reason_and_exact_version():
    with TestClient(main.app) as client:
        old = post(client).json()['listing']['id']
        new = post(client).json()['listing']['id']
        assert old != new
        assert admin(client, 'delete', listing_id=new).status_code == 422
        assert admin(client, 'delete', listing_id=old, reason='Stale').status_code == 404
        assert admin(client, 'delete', listing_id=new, reason='Spam').status_code == 200
        data = admin(client).json()
        assert data['total'] == 0
        assert data['audit'][0]['actor'] == 'WguAdmin'
        assert data['audit'][0]['reason'] == 'Spam'
        assert data['audit'][0]['target'] == new
        assert post(client).status_code == 201  # removal alone does not ban


def test_blocks_persist_remove_all_and_unblock():
    with TestClient(main.app) as client:
        post(client)
        post(client, 'Alt')
        assert admin(client, 'block', steam_id='abc', reason='Bad').status_code == 422
        assert admin(client, 'block', steam_id='123456', reason='Repeated spam').status_code == 200
        assert admin(client).json()['total'] == 0
        path = main.moderation.path
        main.moderation = ModerationStore(path)
        assert post(client).status_code == 401
        data = admin(client).json()
        assert data['blocked_count'] == 1 and data['blocks'][0]['reason'] == 'Repeated spam'
        assert admin(client, 'unblock', steam_id='123456', reason='Appeal accepted').status_code == 200
        client._fixture_sessions.clear()
        assert post(client).status_code == 201
        assert admin(client, 'unblock', steam_id='123456', reason='Again').status_code == 404
        assert admin(client).json()['audit'][0]['action'] == 'steam.unblock'


def test_restore_keeps_id_age_and_drops_expired(monkeypatch, tmp_path):
    with TestClient(main.app) as client:
        row = post(client).json()['listing']
    row['timestamp'] = time.time() - 300
    expired = dict(row, host='Expired', timestamp=time.time() - 901)
    blocked = dict(row, host='Blocked', steam_id='42')
    main.moderation.block('42', 'Spam', 'Admin')
    restore = tmp_path / 'restore.json'
    restore.write_text(json.dumps([row, expired, blocked, {'bad': 'data'}]))
    main.store = main.LfgStore()
    with TestClient(main.app) as client:
        rows = client.get('/api/lfg/listings').json()
        assert len(rows) == 1 and rows[0]['id'] == row['id']
        assert rows[0]['timestamp'] == row['timestamp'] and rows[0]['age_seconds'] >= 300
    assert not restore.exists()
    restore.write_text('invalid-json')
    with TestClient(main.app) as client:
        assert client.get('/health').status_code == 200
