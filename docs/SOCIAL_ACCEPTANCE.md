# v1.0b social candidate acceptance

The relay 1.5.0 and the contact-column update are deployed. Local checks prove
model behavior, static native API matches and mocked input routing. They do not
prove native friend requests, invitations or visual behavior in Farever.

Close Farever before replacing the mod and shared SFCursor DLL. Restart with the
existing supported HLX and SFimgui installations. Keep a copy of the prior DLL
and mod for rollback. Existing settings and saved geometry are preserved.

1. Open Browse, Post, Messages, People, Settings and Boss Loot at 1440×900 and
   520×360, then test enlarged text, each theme and High Contrast. Check long
   names, long words, Unicode, paragraphs and literal `%` characters. Narrow
   navigation becomes a picker. Messages use a single active conversation.
2. Right-click listing rows, message cards, friends/realm players, loot icons,
   templates, phrases, paragraphs and inputs. Confirm the intended row owns the
   menu. Test Copy, Paste (replace all), Clear, search, confirmation cancellation,
   tab changes, repeated open/close and expired selections.
3. Compare the auto-read Farever code with the native friend-code screen. Opening
   SimpleLFG must never generate or rotate it. Try a manual override, Use game
   code and account switching. Steam and Farever consent remain independent;
   both start private. Review the public Post preview before enabling sharing.
4. With another player, add by native Farever code and native roster ID. Test
   self, malformed code, existing friend, full friend list and repeated clicks.
   Confirm normal acceptance in the game. Submitted requests are not proof of
   acceptance. Friends and Same Realm list only known game-provided records.
5. As party leader, invite a local player and an online cross-realm friend.
   Confirm the normal recipient prompt. Test non-leader, full party, unavailable
   target and loading/account changes while requests are pending. No automatic
   request acceptance, party joining or Add-and-Invite chain is installed.
6. With two updated clients, send and delete a private message. Confirm the
   two-step deletion and synchronized Message deleted marker. Repeat after
   delivery acknowledgement, with the other panel closed and after reopening.
   Deletion has a 30-minute session window; read text cannot be recalled. An
   older recipient must upgrade before a delivered message can be retracted.
7. Withdraw your public relay listing. Another session with the same display
   name must not be able to withdraw it or delete your messages. Native game
   chat can only be hidden locally. Test expiry and a changed/reposted listing.
8. Test SFCursor with SimpleLFG alone and with SolarFlare: text input, right and
   middle clicks, scrolling, F5 closure, camera transitions, Alt+Tab, minimize,
   resize and reopening. Verify no click-through, stuck key, unexpected cursor
   shape/visibility change or loss of world input. Close tools before toggling
   the game camera when the keyboard is owned by an open tool.

Report the first failed step and any visible native error. Keep this candidate
separate from the prior public v1.0b package until the in-game run is accepted.
