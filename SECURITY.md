# Security and privacy

SimpleLFG has two parts you can read in this repository: the **mod** (`src/`) and the **relay** that carries cross-server listings and
private messages (`server/`). The website that shows the public board and hosts the administrator panel is not published; `docs/INTERFACE.md`
describes exactly how it and the game talk to the relay. This file says what protects each part and what does not.

## Reporting a problem

Open a private security advisory or an issue on this repository. Please do not post exploits publicly before the maintainer can respond.

## The mod

- No account, API key, environment variable or password is needed. The only credential is a random session token kept in memory.
- Posting, whispering, friend requests, party invitations and leaving a party happen only when you press the button. Nothing is
  accepted or joined for you; the other player always accepts through the game's own prompts.
- Public contact sharing (Steam code, Farever code) is off by default and needs a confirmation. Private messages are session-only.
- The mod checks the game build fingerprint before it registers any hook or window.
- Incoming chat is shown as plain text and never executed; links are never opened automatically.

## The relay (`server/`)

- **Sessions.** The relay issues a public random address and a private 256-bit bearer secret. It keeps only a digest of the secret and
  compares in constant time. Listing writes, privacy changes, message sends and inbox reads all need the session; ownership is never
  inferred from a character name or Steam code.
- **Lifetimes.** Listings and messages expire after 15 minutes; sessions after 30 minutes idle. Message bodies are not written to the
  moderation database.
- **Request limits.** Every request is counted before it is parsed. Bodies are capped at 8 KiB (including chunked uploads) with a
  10 second read timeout. Per-IP, per-session, per-recipient and global limits reject excess work without evicting other players' messages.
  Limiter tables are bounded.
- **Proxy trust.** Only the reverse proxy reaches the application. The client address is taken from Cloudflare's header only when the
  connection comes from Cloudflare's published ranges (`server/cloudflare-networks.txt`); all other forwarding headers are removed and the
  application never parses them. IPv6 clients are grouped by /64.
- **Input.** Request models reject unknown fields and type coercion, enforce length limits, digits-only Steam codes and no control
  characters. Database queries are parameterised.
- **Output.** Private responses are sent with `Cache-Control: no-store`. Cross-origin access is limited to the production site and never
  credentialed. Logs exclude message bodies and tokens.
- **Events.** The live-update stream is authenticated, carries only invalidation notices (never message text), and is capped per session and
  per address.
- **Moderation.** Admin actions require a server-side secret (64 hex characters, constant-time check) that lives outside the web root. Blocks
  are by Steam code and every action is audited.
- **Data.** IP addresses are used for in-memory abuse counters only. Backups are kept outside the web root. See `server/PRIVACY.MD`.

## The website

The public board only reads `GET /api/lfg/listings`, shows listing text as plain text (never as HTML) and builds Steam links from numeric
codes only. The administrator panel runs on the web server and reaches the relay only over loopback, authenticating with a server-side
secret header; the proxy does not forward that path. Neither the board nor the panel is published here.

## Reviews and limits

- A static review of release 0.1.12 (Snyk code and dependency scans, 2026-10-26) found 0 high and 0 medium issues, and 12 low findings in
  local development tooling that is not shipped; the 13 Python dependencies had no known vulnerable paths. Haxe is not covered by that
  scanner. This review has not been repeated for v1.2b; the v1.2b client changes are interface work, local friend and party calls, and one relay
  session fix.
- Names and Steam codes are self-reported; an anonymous session does not prove who you are. Distributed abuse can be slowed, not prevented.
  A clean scan does not prove the absence of vulnerabilities, and in-game acceptance of v1.2b is still pending.

## Check it yourself

Run `pytest server` (needs `server/requirements.txt`), `python tools/test_relay_wire_fixture.py`, and read `server/security.py` and `server/main.py`. The tests exercise limits, forged tokens, expiry, moderation and the proxy fixture.
