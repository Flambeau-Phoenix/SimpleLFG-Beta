# SimpleLFG v1.1 interface (supersedes the 0.1.4 layout below)

Shell: one window with a menu bar, a navigation row (Browse, Post, People, Messages, Settings, Boss loot) and a party strip. Cards, buttons, headers, tables and toasts come from the copied host kit in `src/simplelfg/ui`; `ThemePalette.applyHost` feeds it the addon's own theme so Midnight, Slate, Warm, Custom and High Contrast keep working.

Browse and People are 60/40 workspaces: a `DataTable` (sortable, resizable, clipped, right-click menu, arrow-key selection) on the left and a docked inspector on the right. Below 900 px they become a list with a Back button, never an overlay. Tooltips stay removed; information lives in visible labels.

Panel key: `panelKey` plus `panelMods` in config, validated by `KeyBinding`, polled by `KeyCapture`, checked against the game's bindings once per change by `NativeKeys`.

Party and friend verbs go through `Engine.enqueue` and `NativeSocial` using the installed gamelib wrappers (`Group.requestLeave`, `FriendList.removeFriend`, existing add and invite). Kick and incoming-request handling are intentionally not exposed.

---

# SimpleLFG 0.1.4 UI design

The standalone panel follows current SolarFlare UI source and the architecture
report's observation -> primitive cache -> presentation boundary. Local Chrome /
Scope helpers own styling and scopes, without a SolarFlare runtime dependency.
Future integration can substitute host window/theme helpers.

## Canvas and lifetime

First opening and Reset Window use 1440x900, clamped to the viewport. Config v4 /
geometryVersion 2 floors older saved dimensions to those defaults once, without
compounding the earlier 25% migration. Later manual resizing is preserved.

Browse initially contains only the full-width board. Selection opens a
380px * textScale right sidebar with a 12px gutter. The shell grows toward the
viewport limit and repositions to remain on screen. BrowseLayout uses a right
overlay drawer when the remaining board would be under 440px * scale. Details
never stack below the board. Selection made during board submission renders its
sidebar on the next layout frame, avoiding a zero-width initial pane.

SidebarGeometry keeps board-only width separate from automatic expansion.
Closing restores automatic width; explicit resizing replaces the saved width
and is not undone on collapse. Post and Settings retain responsive two-pane
workspaces. Navigation is Browse / Post / Settings, with Boss loot at the far
right. There is no descriptive status row above it.

Boss loot opens its own movable/resizable 820x620 window, with searchable boss
chooser and difficulty above a 42/58 item-list / inspector split and 12px gutter.
Closing the main window leaves this viewer independently open. Camera entry,
unavailable integration and session change close both; neither reopens
automatically. Both participate in the existing owner-aware input protection.

## Controls

Scope.choice follows SolarFlare UiLayout.stringCombo: beginCombo plus separate
selectables, stable integer option IDs, default focus and exception-safe cleanup.
No NUL-separated ImGui.combo remains. The binding's cstr/toUtf8 conversion stops
at the first NUL; individual options avoid this without changing pinned bindings.
Searchable catalogues retain Scope.combo with explicit control widths.

The sole HUD button uses logo3 (Chat), a 44px hit target and the established fixed
right/bottom offsets (448/16). Only logo3 is embedded/decoded. General contains
Enable LFG button; the configured F-key remains usable when disabled. Artwork,
size, drag and offset settings and launcher menus are removed.

Settings order is General -> Alerts -> Filters -> Theme. Theme/style scopes
restore before other mods draw. Utility buttons are restrained outlines. Received
text renders unformatted. Hover tooltip code is removed. Post and Send whisper
remain explicit actions with reviewed text, cooldowns and separate feedback.

## Context and history

All is the initial combined feed. Groups and Players retain their recruiting
meaning. Row metadata reads name | elapsed time | context tag, with smaller
green/red tag text; there is no separate context column or role metadata. Details
repeat the tag. The board header explains green as recruiting/run language and
red as target mention only. Green does not prove group availability; red matches
never produce group alerts.

Require recruiting context defaults off. Enabling also immediately hides retained
red matches and clears a red selection; disabling restores active red entries.
Other phrase/alias edits affect future recognition. Exclusions still win. Equal
specificity collisions retain candidate IDs, which activity filtering recognizes;
more specific aliases take precedence.

Recognition is baked independently of loot from all 17 Boss-flagged units in the
current local CDB. It uses prior authored activity links, names, words, apostrophe
variants, compact forms, initials and curated nicknames. The unknown localized
name ??? uses its stable unit ID. There are 22 targets and 128 aliases. Untouched
prior defaults expand; customized lists/removals remain authoritative.

All six existing channels are enabled by default, including whispers and group
chat. General can disable channels individually. Capture requires a sender
identity; senderless notices do not become player entries. The existing
localReceiveMessage postfix handles all routes; no additional hook is installed.

Board owns a separate SessionHistory of received primitive envelopes. It captures
ordinary and matching messages on enabled channels while the UI is closed, except
ignored senders. The selected sender's cached projection shows newest-first text,
channel and elapsed time. Retention is 50/sender, 30 minutes and 2,000 overall,
oldest first. Session clearing removes history and pending input. Nothing reads
the game's static history, and Store never serializes received messages.

## Loot and validation

The chooser includes 17 bosses, but only the 14 with explicit bossLootTable /
heroicLootTable links have items. The unchanged 26 reachable tables and 101 items
and portraits remain authoritative. Unlinked bosses show no table available.
Ordinary creature/global loot and guessed dungeon links are excluded. Difficulty
gates and source restrictions remain visible; weights are not per-kill chances.
Item selection shows 96px inspection art and details instead of hover previews.

Offline tests cover recognition, migration, channels, context/alerts, bounded
history/session cleanup, and sidebar expansion/manual resizing/scaled geometry.
Spatial fixtures validate the visible drawer separately because overlap is
intentional. Compilation and both source linters pass. Actual fonts, popup
rendering and live input remain pending in ACCEPTANCE.md.
