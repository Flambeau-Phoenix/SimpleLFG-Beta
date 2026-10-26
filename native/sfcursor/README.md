# SolarFlare cursor and ExtraBars input helper

`sfcursor.hdll` retains the existing `sync_confinement(Bool):Int` primitive.
It checks the foreground process, minimized state, client rectangle in screen
coordinates, and Windows' actual clipping rectangle. It calls `ClipCursor` only
for a mismatch. Cursor position, shape, and visibility are never changed.

Matching game confinement is adopted so it can be released when the cursor is
free or the game loses focus. Release only clears a rectangle matching the last
one owned by this policy; a different rectangle established by another layer is
left intact. Calls allocate no HashLink objects and retain no window handles.

Results: `0` unchanged, `1` applied, `2` released, `3` inactive, `-1` failed.
The existing sfimgui plugin remains installed. This is a separate dependency:
place it in `hlx/plugins/sfcursor/sfcursor.hdll` alongside the updated mod.

Validated local build commands, from the repository root:

```powershell
cmake -S native/sfcursor -B bin/sfcursor-build -DHASHLINK_DIR=E:/haxe/haxe/hashlink-1.16.0-win
cmake --build bin/sfcursor-build --config Release
ctest --test-dir bin/sfcursor-build -C Release --output-on-failure
```

Tests include the production implementation with mocked Win32 functions. They
never move, clip, or release the user's actual cursor. They cover 10,000 steady
frames, interference recovery, resize, Alt+Tab, minimize, free cursor, adoption
of matching engine confinement, a changed third-party rectangle, and failures.
Live Farever validation remains necessary; these tests do not measure game FPS.

ExtraBars extends this same helper with six primitives:

| Primitive | Contract |
| --- | --- |
| `extra_configure(prefix, key, mode, eligible, generation):Int` | Win32 VK codes, mode 1 Hold / 2 Toggle / 3 Always Active (prefix 0). Return 0 native / 1 bars; -1 missing SFImGui capture API, -2 window-thread mismatch, -3 installation failure. |
| `extra_configure_many(prefix, mode, eligible, generation, bytes, length):Int` | Copied 256-entry int32 VK→slot-token table (1024 bytes). Zero is unassigned/native; positive tokens identify cells. Same return codes as configure, plus -4 for null/wrong-sized buffer. |
| `extra_take(generation):Int` | Pop one valid queued slot token; 0 none, positive token identifies the cell (legacy configure uses token 1). Queue is bounded at 32. |
| `extra_status():Int` | Bits: 1 active, 2 release recovery, 4 toggled, 8 prefix down. |
| `extra_reset():Void` | Cancel activation and queue; retain owned releases until paired key-up. |
| `extra_shutdown():Bool` | Remove subclass on its owning thread, or defer while an owned key remains held; true means detached. |

The window subclass targets only the own-process foreground HWND and installs on
its window thread. It forwards unowned messages with `DefSubclassProc`. Only the
exact assigned keys while Hold/Toggle/Always Active is active are consumed, including its repeats,
character messages and paired release. Prefix events and naked keys stay native.
Ctrl, Alt, Shift and Windows-key chords stay native; system down/up messages are
handled. Legacy Long-press is inactive in Haxe.

The subclass reads the installed SFImGui public exports `sfimgui_igGetCurrentContext`,
`sfimgui_igGetIO_Nil`, and `sfimgui_ImGuiIO_get_WantCaptureKeyboard`. Missing exports
fail closed. UI-owned input bypasses new activation/suppression and reaches the
SFImGui chain; an already consumed down retains its paired up to avoid orphaned
events. This is logical capture priority, not an invocation of the SFImGui handler
before our callback. The existing SFImGui DLL is neither rebuilt nor replaced.

Haxe publishes gameplay eligibility/configuration and polls requests on the game
tick. A 500 ms expired observation lease, UI capture, focus loss, or generation
change clears pending activation. Item resolution, permission checks and native
requestUse run only in Haxe observation. No callbacks into managed code, global
hooks, engine detours, synthetic keys or desktop input are used.

The helper is pinned before registering its callback. Explicit shutdown removes
the subclass immediately when safe, otherwise on an owned release/focus reset;
window destruction also removes it. This prevents a dangling pointer if a caller
attempts native unloading. The pinned library cannot be hot replaced: **close
Farever and restart after deploying bytecode plus this helper together**. Do not
unload the SFImGui dependency while this helper is registered.

Native tests now include 120 pure production routing checks and 33 production
wrapper checks with mocked Win32/capture calls. They prove routing/cleanup policy,
not exclusive routing in Farever. Runtime acceptance is user-run; if Farever
receives keys through another input path, report double-fire rather than claiming
the window filter is sufficient. See `docs/action_bar_mod_plan.md`.

## Mouse guard (click-through)

`mouse_guard(enabled:Bool):Int` keeps clicks and wheel turns that land on an open SolarFlare
window from also reaching the game's own UI. `0` off, `1` active, `-1` missing SFImGui
export (`WantCaptureMouse`, `AddMouseButtonEvent`, `AddMouseWheelEvent`), `-2` wrong thread,
`-3` install failure. Haxe (`ui/MouseGuard.hx`) turns it on only while a SolarFlare tool is open
and the cursor is free, and the Utilities tab has a switch (`Block click-through`, default on).

* A separate window subclass (`mouse_input.cpp`, policy in `mouse_policy.h`). It sits *outside*
  SFImGui's subclass, so a swallowed message never reaches SFImGui. The guard therefore hands the
  swallowed press, release or wheel turn to ImGui itself (`sfimgui_ImGuiIO_AddMouseButtonEvent` /
  `AddMouseWheelEvent`) and returns 0. Unswallowed messages go down the normal chain, so SFImGui
  feeds ImGui exactly as before.
* Left, right and middle buttons (including double-click presses) and both wheels. Mouse moves, side
  buttons (ExtraBars' Mouse-Back/Forward prefixes), keys and raw input are never touched.
* A press the UI wants (`WantCaptureMouse`) is kept from the game; its release is kept too, even if the
  cursor has since left the window. A press that began in the game is never taken over, so dragging from
  a game control across a window cannot strand a button.
* Only the own-process foreground window, only while Haxe refreshes the 500 ms heartbeat. Focus loss,
  alt-tab and window destruction reset ownership (ImGui is told the button is up). Missing APIs fail open.
* Tests: `mouse_win32_tests.cpp` includes the production file with mocked Win32/SFImGui calls
  (`ctest` target `mouse-guard-win32`). Live Farever validation is still required.

Deploy `sfcursor.hdll` together with the mod bytecode and restart Farever (the library is pinned).

## Shared owner-aware clients

`mouse_guard_client(owner:Bytes, enabled:Bool):Int` adds independent, bounded
500 ms leases for up to 16 named clients. Legacy `mouse_guard(Bool)` keeps a
separate reserved lease; one caller's disable cannot cancel another caller.
Paired mouse releases remain protected after the last lease ends. Focus loss
clears every lease and releases owned ImGui buttons. `notify_sound():Void` is
additive and checks the own-process foreground/minimized state before playing
the system notification. Existing confinement/ExtraBars/shortcut exports remain
available. SimpleLFG does not enable the ExtraBars or shortcut APIs.
