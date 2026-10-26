"""Bounded single-worker admission controls. Never interpret proxy headers here."""
import asyncio
from collections import Counter
import heapq
import ipaddress
import os
import threading
import time
from fastapi import HTTPException
from starlette.responses import JSONResponse


def setting(name, default):
    value = int(os.getenv('LFG_' + name, default))
    if value < 1:
        raise ValueError('LFG_' + name + ' must be positive')
    return value


def client_ip(request):
    # Uvicorn alone resolves trusted forwarding chains; direct requests use their peer.
    raw = request.client.host if request.client else 'unknown'
    try:
        address = ipaddress.ip_address(raw)
        if isinstance(address, ipaddress.IPv6Address):
            if address.ipv4_mapped:
                return str(address.ipv4_mapped)
            return str(ipaddress.ip_network(str(address) + '/64', strict=False))
        return str(address)
    except ValueError:
        return 'unknown'


class Budgets:
    """Fixed-window counters with bounded keys and an expiring heap, under one lock."""
    def __init__(self, capacity=20000, clock=time.monotonic):
        self.capacity, self.clock = capacity, clock
        self.rows, self.expiry = {}, []
        self.counters = Counter()
        self.lock = threading.RLock()

    def purge(self):
        now = self.clock()
        while self.expiry and self.expiry[0][0] <= now:
            deadline, key = heapq.heappop(self.expiry)
            if key in self.rows and self.rows[key][0] == deadline:
                del self.rows[key]

    def hit(self, bucket, identity, default, seconds=60):
        with self.lock:
            self.purge()
            limit = setting(bucket.upper(), default)
            key = (bucket, identity)
            row = self.rows.get(key)
            if row is None:
                if len(self.rows) >= self.capacity:
                    self.counters['limiter_capacity'] += 1
                    raise HTTPException(503, 'Service is busy. Try again shortly.', headers={'Retry-After': '60'})
                row = [self.clock() + seconds, 0]
                self.rows[key] = row
                heapq.heappush(self.expiry, (row[0], key))
            if row[1] >= limit:
                self.counters[bucket + '_limited'] += 1
                raise HTTPException(429, 'Please wait before trying again.',
                                    headers={'Retry-After': str(max(1, int(row[0] - self.clock()) + 1))})
            row[1] += 1

    def reset(self):
        with self.lock:
            self.rows.clear()
            self.expiry.clear()
            self.counters.clear()


budgets = Budgets()


class RequestGuard:
    """Count every request before validation; buffer at most 8 KiB before parsing."""
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope['type'] != 'http':
            return await self.app(scope, receive, send)
        from starlette.requests import Request
        request = Request(scope)
        original_send = send
        async def private_send(message):
            if message['type'] == 'http.response.start' and (scope['path'].startswith('/api/lfg/') or scope['path'].startswith('/internal/')):
                message['headers'] = [(k, v) for k, v in message.get('headers', []) if k.lower() != b'cache-control'] + [(b'cache-control', b'no-store')]
            await original_send(message)
        send = private_send
        try:
            budgets.hit('requests_ip', client_ip(request), 300)
            headers = request.headers
            declared = headers.get('content-length')
            if declared is not None:
                if not declared.isascii() or not declared.isdigit():
                    raise HTTPException(400, 'Invalid content length.')
                if len(declared) > 8 or int(declared) > 8192:
                    raise HTTPException(413, 'Request exceeds 8 KiB.')
            body = bytearray()
            async with asyncio.timeout(10):
                while True:
                    part = await receive()
                    if part['type'] == 'http.disconnect':
                        return
                    chunk = part.get('body', b'')
                    if len(body) + len(chunk) > 8192:
                        raise HTTPException(413, 'Request exceeds 8 KiB.')
                    body.extend(chunk)
                    if not part.get('more_body', False):
                        break
            delivered = False
            async def buffered():
                nonlocal delivered
                if delivered:
                    return await receive()
                delivered = True
                return {'type': 'http.request', 'body': bytes(body), 'more_body': False}
            await self.app(scope, buffered, send)
        except TimeoutError:
            budgets.counters['body_timeout'] += 1
            await JSONResponse({'detail': 'Request body timed out.'}, status_code=408)(scope, receive, send)
        except HTTPException as exc:
            if exc.status_code != 429:
                budgets.counters['guard_' + str(exc.status_code)] += 1
            await JSONResponse({'detail': exc.detail}, status_code=exc.status_code,
                               headers=exc.headers)(scope, receive, send)
