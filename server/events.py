"""Bounded SSE invalidations; never broadcast private message data."""
import asyncio
from fastapi import HTTPException
from fastapi.responses import StreamingResponse
from security import budgets, setting


class EventHub:
    def __init__(self):
        self.clients = {}

    def subscribe(self, session_id, ip):
        if session_id in self.clients:
            raise HTTPException(429, 'This session already has an event stream.', headers={'Retry-After': '15'})
        if len(self.clients) >= setting('MAX_STREAMS', 64):
            budgets.counters['stream_capacity'] += 1
            raise HTTPException(503, 'Live updates are busy.', headers={'Retry-After': '30'})
        if sum(c[0] == ip for c in self.clients.values()) >= setting('STREAMS_PER_IP', 20):
            raise HTTPException(429, 'Too many live updates on this network.', headers={'Retry-After': '30'})
        queue = asyncio.Queue(maxsize=8)
        self.clients[session_id] = (ip, queue)
        return queue

    def unsubscribe(self, session_id, queue):
        if self.clients.get(session_id, (None, None))[1] is queue:
            del self.clients[session_id]

    def notify(self, kind, recipient=None):
        for sid, (_, queue) in tuple(self.clients.items()):
            if recipient is not None and sid != recipient:
                continue
            if queue.full():
                while not queue.empty():
                    queue.get_nowait()
                queue.put_nowait('sync')
            else:
                queue.put_nowait(kind)


class EventResponse(StreamingResponse):
    """Release admission even if disconnect cancels before generator iteration."""
    def __init__(self, iterator, hub, session_id, queue):
        super().__init__(iterator, media_type='text/event-stream',
                         headers={'Cache-Control': 'no-store', 'X-Accel-Buffering': 'no'})
        self.hub, self.session_id, self.queue = hub, session_id, queue

    async def __call__(self, scope, receive, send):
        try:
            await super().__call__(scope, receive, send)
        finally:
            self.hub.unsubscribe(self.session_id, self.queue)
