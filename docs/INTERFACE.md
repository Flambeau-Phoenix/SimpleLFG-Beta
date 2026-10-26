# How the game, the relay and the website connect

```
Farever + SimpleLFG ---- HTTPS (JSON, and an event stream) ----+
                                                                v
Browser on the website's board ---- GET /api/lfg/listings ---> Cloudflare -> Caddy -> relay (server/main.py, 127.0.0.1:8000)
                                                                ^
Website admin panel (on the web server) -- loopback POST + secret
```

## Game to relay

- One fixed address, `https://webgameuniverse.com/api/lfg/...`, over TLS. Nothing is sent while the SimpleLFG window is closed.
- Start: `GET /api/lfg/capabilities`, then `POST /api/lfg/session` with the character name, an optional numeric Steam code and the
  feature list. The reply is a public session address, a private bearer token (`<32 hex>.<64 hex>`) and the idle timeout.
- Afterwards every request carries `Authorization: Bearer <token>`. Listings refresh about every 15 seconds and the inbox about every
  10 seconds, or immediately on a notice from the event stream.
- The game sends only what you press: a reviewed listing, a private message, a withdrawal, a privacy choice. Chat you receive in the game is
  never uploaded.

| Method and path | Auth | Purpose |
| --- | --- | --- |
| `GET /api/lfg/capabilities` | none | feature list (`social-v1`) |
| `POST /api/lfg/session` | none (rate limited) | create a session |
| `GET /api/lfg/listings` | none | public board data |
| `POST /api/lfg/post` | session | publish your listing |
| `POST /api/lfg/post/delete` | session | withdraw your listing |
| `POST /api/lfg/privacy` | session | choose whether Steam or Farever codes are public |
| `POST /api/lfg/chat` | session | send a private message (240 characters) |
| `GET /api/lfg/chat?after=&deleted_after=` | session | read your inbox |
| `POST /api/lfg/chat/delete` | session | delete a message you sent, for both sides |
| `GET /api/lfg/events` | session | event stream: sync, listings, chat, expired, with a 15 second heartbeat |
| `GET /health` | none | service status |

## Website board to relay

The board page runs in the visitor's browser and calls the public `GET /api/lfg/listings`. It has no session and cannot read messages or
change anything.

## Website admin to relay

The administrator panel is part of the website's server code. After its own login and CSRF checks it makes a server-to-server
`POST http://127.0.0.1:8000/internal/lfg/admin` carrying the relay's admin secret in `X-LFG-Admin-Key` (the secret is an environment value on the
server, not in the web root or in this repository). The relay compares it in constant time and supports four actions: `state`, `delete`,
`block` and `unblock`. The reverse proxy forwards only `/api/lfg/*`, so this path is not reachable from the internet.

## Trust summary

The game and the board talk to the same public API. Only the server-side admin call can delete a listing or block a Steam code, and it works
only over loopback with the secret. See `SECURITY.md`.
