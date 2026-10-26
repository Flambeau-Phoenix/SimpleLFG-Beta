"""Ephemeral, authenticated inboxes. Addresses are public; bearer tokens are not."""
import hashlib
import hmac
import re
import secrets
import time
import threading
from fastapi import HTTPException
from security import budgets, setting

SESSION_TTL = 1800
MESSAGE_TTL = 900
MAX_SESSIONS = 2000


class MessagingStore:
    def __init__(self):
        self.sessions = {}
        self.messages = []
        self.sequence = 0
        self.lock = threading.RLock()
        self.next_purge = 0

    def purge(self, force=False):
        now = time.time()
        if not force and now < self.next_purge:
            return
        self.next_purge = now + 60
        self.sessions = {key: value for key, value in self.sessions.items() if value['expires'] > now}
        self.messages = [m for m in self.messages if now-m['timestamp'] < MESSAGE_TTL
                         and m['recipient_id'] in self.sessions and m['sender_id'] in self.sessions]

    def create(self, host, steam_id, ip='unknown'):
        with self.lock:
            return self._create(host, steam_id, ip)

    def _create(self, host, steam_id, ip):
        self.purge(force=True)
        if len(self.sessions) >= setting('MAX_SESSIONS', MAX_SESSIONS):
            budgets.counters['session_capacity'] += 1
            raise HTTPException(503, 'Messaging is busy. Try again shortly.', headers={'Retry-After': '60'})
        if sum(s['ip'] == ip for s in self.sessions.values()) >= setting('SESSIONS_PER_IP', 20):
            budgets.counters['sessions_ip_limited'] += 1
            raise HTTPException(429, 'Too many connected sessions on this network.', headers={'Retry-After': '60'})
        address = secrets.token_hex(16)
        credential = secrets.token_hex(32)
        self.sessions[address] = {'id': address, 'host': host, 'steam_id': steam_id, 'ip': ip,
                                  'digest': hashlib.sha256(credential.encode()).digest(), 'expires': time.time()+SESSION_TTL}
        return {'session_id': address, 'token': address+'.'+credential, 'expires_in': SESSION_TTL}

    def authenticate(self, authorization, blocked):
        self.purge()
        match = re.fullmatch(r'Bearer ([0-9a-f]{32})\.([0-9a-f]{64})', authorization or '')
        if not match:
            raise HTTPException(401, 'A private messaging session is required.')
        session = self.sessions.get(match[1])
        if session is None or session['expires'] <= time.time() or not hmac.compare_digest(session['digest'], hashlib.sha256(match[2].encode()).digest()):
            raise HTTPException(401, 'Messaging session expired. Reconnect to continue.')
        if blocked(session['steam_id']):
            raise HTTPException(403, 'This Steam code is blocked.')
        session['expires'] = time.time()+SESSION_TTL
        return session

    def address(self, session_id):
        session = self.sessions.get(session_id)
        return session if session and session['expires'] > time.time() else None

    def send(self, sender, recipient_id, message, blocked):
        with self.lock:
            return self._send(sender, recipient_id, message, blocked)

    def _send(self, sender, recipient_id, message, blocked):
        self.purge(force=True)
        recipient = self.address(recipient_id)
        if recipient is None:
            raise HTTPException(404, 'That player is no longer connected. Refresh listings.')
        if sender['id'] == recipient_id:
            raise HTTPException(422, 'Choose another player.')
        if blocked(recipient['steam_id']):
            raise HTTPException(403, 'That Steam code is blocked.')
        if len(self.messages) >= setting('MAX_MESSAGES', 500):
            budgets.counters['message_capacity'] += 1
            raise HTTPException(503, 'Messaging is busy. Try again shortly.', headers={'Retry-After': '60'})
        if (sum(m['sender_id'] == sender['id'] for m in self.messages) >= setting('QUEUED_PER_SENDER', 20)
                or sum(m['recipient_id'] == recipient_id for m in self.messages) >= setting('QUEUED_PER_RECIPIENT', 50)):
            budgets.counters['queue_limited'] += 1
            raise HTTPException(429, 'Message queue is full. Try again shortly.', headers={'Retry-After': '60'})
        budgets.hit('deliveries_recipient', recipient_id, 30)
        self.sequence += 1
        entry = {'id': self.sequence, 'sender_id': sender['id'], 'sender': sender['host'],
                 'recipient_id': recipient_id, 'message': message, 'timestamp': time.time()}
        self.messages.append(entry)
        return dict(entry)

    def inbox(self, session_id, after):
        self.purge()
        # A subsequent cursor acknowledges only this inbox's previously read rows.
        self.messages = [m for m in self.messages if not (m['recipient_id'] == session_id and m['id'] <= after)]
        rows = [dict(m) for m in self.messages if m['recipient_id'] == session_id and m['id'] > after][:50]
        return {'messages': rows, 'cursor': rows[-1]['id'] if rows else after, 'session_id': session_id}

    def revoke(self, steam_id):
        self.sessions = {key: value for key, value in self.sessions.items() if value['steam_id'] != steam_id}
        self.purge()
