# SimpleLFG relay data

Public listings contain the host's self-reported character name, activity, note,
party slots, timestamp and public session address. The Steam code is hidden unless
the host explicitly shares it. Do not put information in a public note that you do
not want published. Private messages require the recipient session credential.
A public session address does not grant inbox access.

Private bearer credentials remain in client memory; server memory holds verifier
digests. Private message bodies and sessions are not stored in the moderation
SQLite database. Listings and messages expire after 15 minutes; sessions expire
after 30 minutes of inactivity. Authenticated open SSE heartbeats keep an active
session alive. Closing the window stops networking but preserves its credential
in memory until logout, character change, expiry or process exit.

IP addresses (IPv6 grouped by /64) are used for abuse budgets and resource caps.
These counters, session associations and event queues are in memory. Private
operator deployment backups may contain unexpired listing metadata; backups are
kept outside the web root with restricted permissions. Moderation metadata includes
self-reported Steam codes, reasons, actor names and audit timestamps and persists
in SQLite for administrators. No credential or message body belongs in logs.

Anonymous sessions do not verify a character's identity or Steam ownership.
