# SimpleLFG v1.0b social candidate

All changes are local to SimpleLFG and its shared SFCursor dependency. There are
no new game hooks, automatic friend acceptance or game-object references in UI
state. Existing geometry, themes, filters, templates and loot remain available.

The Farever MCP planner was consulted first. Its social tag has no dedicated
entry and its corpus targets 5F288029, while the installed game is 9F48618B.
Symbols were cross-checked against the installed build's generated wrappers and
fresh bytecode evidence in build/social-api. No remote function index is baked
into this candidate.

Native reads use GameApp.me.accountProgress.social.inviteCode. Retrieval never
calls refreshInviteCode, which clears/rotates the code. Add by code follows
FriendCode.unformatCode and FriendList.inviteFriend; native roster actions use
FriendList.checkAddFriend/addFriend and Whispers.sendInviteGroup. The latter
routes local targets through Group.invitePlayer and remote targets through the
standard native invitation message. Leader/capacity checks remain authoritative.
Snapshots contain primitives only. People polling is bounded to one Hz while
needed; hidden code refreshes avoid roster scans. Session generations reject
late callbacks. Manual codes and public-sharing consent are account-scoped.

Portable UI work adapts the reference behaviors into ContextMenuSystem,
EnhancedText, UiText and UiActionQueue while reusing Scope, Chrome, Palette,
Workspace and TextBuffer. Inputs, paragraphs and item cards support right-click
menus. Private messages preserve line breaks. Incoming text is always rendered
unformatted. Variable-height wrapped content does not use a fixed-row clipper.

Relay social-v1 capability negotiation is additive. Legacy servers retain
listing/messaging support. New authenticated POST routes /api/lfg/post/delete
and /api/lfg/chat/delete enforce private-session ownership. A separate deletion
cursor synchronizes markers to both participants, including missed event wakes.
The relay retains only ownership/deletion metadata for 30 minutes, capped at
5000 records, and removes message bodies after acknowledgement/deletion.
Regular inbox checks recover missed events. Delivered-message deletion against
an older recipient returns an explicit upgrade requirement.

SFCursor input_policy_client is optional for loadability but required for the
complete new input fix. It aggregates named interactive leases, preserves other
IO flags and Farever's hardware cursor, clears held input on camera transitions,
and uses the existing SFimgui keyboard gate. The native bridge checks primitive
signatures before calling them. Legacy SFCursor exports remain available.

Release verification is recorded in evidence/social-native-imports.json and the
candidate manifest. Runtime acceptance remains separate; see SOCIAL_ACCEPTANCE.
