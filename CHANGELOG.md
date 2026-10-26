# v1.1 interface candidate - 2026-10-26

- Rebuilt the window as a menu-bar shell (File / View / Party / Help) with a navigation row and an always-visible party strip. The shared look now comes from a copy of the host UI kit under `src/simplelfg/ui` (package renamed; host-only couplings cut), so cards, buttons, headers and themes match the SolarFlare editors without a runtime dependency.
- Browse is a sortable, resizable, clipped table (context, target, type, player, party, source, age, message) beside a docked inspector. The auto-growing sidebar and overlay drawer are gone. Keyboard: Up/Down, Enter whisper, Delete hide, Ctrl+F search, Ctrl+1..5 pages.
- People shows friends and same-realm players in a table with level and zone, your friend code with Copy, add-by-code with live validation, the party roster, Invite per row, and two-step Remove friend.
- Party: read-only roster from the installed game group; two-step Leave in the strip, menu and People page; optional Leave chip beside the LFG button (off by default). All verbs use the game's own checks and callbacks; nothing is accepted on anyone's behalf.
- Panel key is rebindable (capture or pick from a list, optional Ctrl/Shift/Alt). Default stays F5. Letters and digits require a modifier. A one-time lookup warns when Farever or a companion overlay already uses the key.
- Post templates are a table with Load and two-step Delete; Messages lists conversations in a table; Settings gained Privacy and contacts as its own page; theme sliders became typed fields.
- Results appear as toasts instead of inline status lines.
- Default window is 1180x768 and the minimum is 1024x768 (smaller saved sizes are raised); the tabs line up against the wordmark.
- The panel key now works while the game owns the pointer (camera mode): it opens and closes the window, which stays visible but non-interactive until the cursor is freed. The window no longer closes when the pointer locks; logout, loading and cutscenes still close it. The key is also read from the engine key state, so it works during plain play.
- The on-screen button is now a cel-shaded window of its own: drag it anywhere, and right-click for Lock Window, Transparent Window, Reset Position and Hide Button (the same menu shape as the overlay windows). Placement is stored as a fraction of the screen. The leave chip and unread badge follow it.
- Fixed "Relay offline" while the relay was up: a malformed saved Steam ID (for example a pasted paragraph) silently blocked the private-message session. The session now connects without the Steam ID, a corrupt saved value is cleared on load, the menu bar distinguishes "listings only, no messaging session", and relay status changes are traced once to hlx.log.
- Quicker party access: the Party menu opens with a status line and Leave party, then "Invite to party" lists nearby friends, friends elsewhere (with their zone) and other nearby players. The strip now has an Invite button when solo as well, which opens the same list at the pointer instead of changing page.
- Fixed the party strip overlapping the page tabs at narrow widths. It now shares the tab row only when it fits, otherwise it takes its own right-aligned row, and it sits inside a bordered frame so it reads as one anchored block.
- Added the transparent SimpleLFG wordmark: it sits at the left of the tab row (click for About, hidden on small windows, View > Show logo to turn it off) and in the About popup. The image is embedded as a resource (assets/simpleLFGbig.png).
- New offline suite ShellTest; layout, migration and social suites updated. In-game visual and input acceptance is pending.

# 0.1.12-test - 2026-10-25

- Integrate the post-security-review multi-word search across listing fields
  and activity aliases; normalize fields separately so long notes/alias lists
  cannot truncate class, host or later alias matches.
- Preserve existing automatic private sessions, visibility-gated relay work,
  released-boss policy, optional class and Steam privacy defaults.
- Repair the hardened local wire fixture's argument positions; validate its
  allowlisted runner and confined file before starting the loopback server.
- Add search/fixture regressions to verification and remove duplicate suite runs.
- Prior archives remain unchanged. Build, package and in-game status are tracked
  in INTEGRATION_REVIEW.md; no live acceptance is implied by source checks.

# 0.1.11-test - 2026-10-25

- Add optional Class dropdown: Not specified, Warrior, Mage, Priest, Rogue.
  Preserve draft/template selection and carry it through previews, relay
  listings, restoration, moderation and the public board as separate metadata.
- Restore the website admin shell/router/module wiring. Keep administrator and
  CSRF checks; a missing module no longer breaks the rest of the admin panel.
- Serve the board at /lfg and redirect /lfg-board there; update navigation links.
- User confirms 0.1.10 functionality passes. New class UI still needs in-game
  visual acceptance. No game installation or control is automated.

# 0.1.10-test - 2026-10-25

- Replace Members/Capacity number inputs with side-by-side dropdowns. Members
  is capped at 3 and below capacity; Capacity ranges from 1 to 4, defaulting to 4.
  Lowering capacity clamps members and refreshes the preview.
- Clamp saved drafts and templates to the same limits; legacy unspecified
  capacity defaults to 4.

# 0.1.9-test - 2026-10-25

- Add the 67 requested run, difficulty, play-style and boss-name words to
  Run / boss context. Merge once into saved settings, deduplicate case/apostrophe
  variants, preserve custom phrases and subsequent edits.
- Messages adds an explicit Steam contact button and context menu. It checks
  the selected person's messages for our Steam tag first, then supported ID
  formats only if no tag succeeds. Review/copy or open a generated official
  profile link; incoming text stays plain and no watcher scans messages.
- Steam contact details are optional for private sessions, messages and posting.
  New settings start blank with public sharing off; upgrading resets prior public
  consent once. Public sharing requires a warning/confirmation reminding players
  that whispers and private messages do not require a public Steam code.
- Backend test contacts now cover both LFG and LFM, with separate private
  sessions and the same persisted two-hour expiry.

# 0.1.8-test — 2026-10-25

- Shared availability policy removes Phrixes_NightGod, Ulserous and Queenslayer
  from activity recognition and the loot selector, including saved aliases/watches.
- Fixed F5 toggle works in either cursor mode and closes all mod windows/popups;
  pointer mode remains game-owned. Logout/session loss still closes the mod.
- One-time relay enablement on upgrade; explicit opt-out remains persistent.
- Solo LFG and recruiting LFM posts supported throughout relay, browsing and board.
- Remove Steam ID actions clear attached composer tags while retaining saved code.
- Temporary marked SimpleLFG Test responder provides private bounded echoes;
  absolute expiry survives restarts. Server-owned marker cannot be forged by clients.
- Existing native chat implementation preserved; user confirms in-game chat works.

# 0.1.7-test — 2026-10-25

- Automatic private sessions replace shared client secrets and environment setup.
- Trusted Caddy/Uvicorn proxy boundary, bounded IP/session/recipient quotas,
  request-body limits, strict validation, and protected queues.
- Authenticated SSE invalidations update listings and inboxes while the window
  is open. Separate cancellable worker; no idle polling on a healthy stream.
  Reconnect fallback: listings 15 seconds, inbox 10 seconds. Closing the window
  retains the in-memory session; logout/identity changes discard it.
- Plain-text punctuation is preserved; the public board uses text-safe DOM nodes
  and numeric-only Steam links. Codes remain private unless explicitly shared.
- Scoped relay/proxy deployment, dependency audit, secret scan and isolated
  proxy/native/browser verification. Earlier release archives are preserved.

# 0.1.5-test

- Reviewed and polished the contributed relay client: bounded worker/result queues,
  main-thread application, generation fences, validated remote snapshots and correct expiry.
- Added explicit public cross-server posting with display names, exact wire preview,
  bounded payloads and real acknowledgement/error feedback; local posts stay local.
- Preserved Steam contact copy/attachments and fixed target parsing/control layout.
- Disabled unauthenticated public relay messaging at the user's request.
- Added 67 interpreter/native integration checks and loopback signed-UTF-8 / public
  read-only HTTPS probes using the installed game's SSL/formatting libraries.
- Test binary only; backend deployment and actual in-game/production posting are not claimed.

# 0.1.4

- Replaced NUL-separated dropdowns with individual selectable options following the current UI helper pattern.
- Standardized the fixed 44px Chat button; General exposes only enable/disable. Removed launcher configuration and all hover tooltips.
- Added 1440x900 defaults and one-time enlargement, a board-only initial view, selection-driven right sidebar with automatic expansion and compact overlay fallback, and independent boss-loot viewer.
- Reordered Settings to General / Alerts / Filters / Theme and removed the redundant recently-observed description row.
- Added all-channel capture by default, 17-boss recognition with words/initials/aliases, optional context requirement, green/red inline context tags and ambiguous-target retention.
- Added bounded in-memory sender history (50/sender, 30 minutes, 2,000 overall); no chat persistence or import of earlier game history.
- Preserved boss-only loot sources and all 101 portraits, explicit manual chat actions, standalone dependencies and existing native input helper.
- Added interpreter/native history, channel, migration, recognition and geometry regression checks. In-game visual/input acceptance remains pending.

# 0.1.3

- Enlarged default window to 1200x800 and added one-time 25% saved-size migration with viewport clamping.
- Removed recruitment roles and Diagnostics UI; preserved notes, Bonus Runs, templates, ignores and manual chat behavior.
- Added current-build artwork for exactly the 101 covered boss-loot items, selected-item inspection, rich tooltips, copy-name context action and name/rarity/type sorting.
- Added editable run/boss context and target aliases, broader recruiting defaults, canonical boss/dungeon nickname matching and collision rejection. Untouched defaults migrate; custom removals remain authoritative.
- Borrowed layered headers, underlined navigation, compact context actions and sortable Browse columns from local UI patterns. Fixed collapsed-width tooltips.
- Shared SFimgui/SFCursor dependencies remain unchanged. In-game acceptance remains pending.

# 0.1.2

- Rebuilt Browse, Post, Boss loot and Settings as framed responsive workspaces using local playbook helpers.
- Added the 960x640 default while preserving saved geometry and compact 520x360 support; desktop panes use 60/40 and a 12 px gutter with font-scaled minimum widths.
- Improved listing hierarchy/context targeting, saved-template identities, searchable catalogues, contained theme/artwork previews and confirmation for deletion/reset actions.
- Kept the reviewed post preview and submission outside the scrolling form. Chat, alerts, loot source data and shared native helpers retain their existing behavior.
- Refreshed/pinned the linter and added layout, migration, confirmation, identity and spatial-report checks. Shared dependency archives remain the unchanged 0.1.1 packages.

# 0.1.1

- Added scoped theme presets/custom colors and compact Browse/Post controls.
- Added four-design, movable/resizable launcher, saved geometry, editable LFG/LFM/excluded phrases, and opt-in watched-activity alerts.
- Restricted Difficulty to Normal/Veteran/Heroic and preserved Bonus Runs through drafts, templates, preview, save, and exact reviewed posting.
- Added boss-specific loot browsing: 14 bosses, 26 reachable tables, 101 items; ordinary creature loot excluded.
- Added optional owner-aware SFCursor integration, foreground-only optional sound, standalone helper source/build, and separate dependency packages.
- Expanded offline regression, asset, native-helper and capability checks. In-game acceptance remains pending and user-operated.
