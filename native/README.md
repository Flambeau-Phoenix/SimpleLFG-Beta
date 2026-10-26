# Standalone shared SFCursor helper

This source snapshot builds without SolarFlare source, Haxe, or any SolarFlare
runtime service. It preserves the legacy confinement, mouse, ExtraBars, and
shortcut exports for other callers. SimpleLFG uses only confinement repair,
owner-aware mouse protection, and optional foreground notification sound.
It never enables ExtraBars or shortcut interception.

Requirements: Windows, CMake, Visual Studio C++ build tools, and a HashLink SDK
containing `include/hl.h`. From the SimpleLFG project directory:

```powershell
cmake -S native/sfcursor -B build/sfcursor-build -DHASHLINK_DIR="C:/path/to/hashlink-sdk"
cmake --build build/sfcursor-build --config Release
ctest --test-dir build/sfcursor-build -C Release --output-on-failure
```

The output is `build/sfcursor-build/Release/sfcursor.hdll`. All four test suites
mock the desktop functions; they do not move the desktop cursor or send input.
`sfcursor/source-lock.json` fingerprints the exact release source snapshot.

## Additive API

`mouse_guard_client(owner:Bytes, enabled:Bool):Int` accepts a NUL-terminated
UTF-8 owner name (1–63 bytes; ASCII identifiers are recommended). Up to 16 owners may hold independent
500 ms leases. Refresh while active; disable only your own name on close. The
legacy `mouse_guard(Bool)` export has a separate reserved lease. One caller's
disable cannot cancel another active caller. Owned button releases remain
paired after leases expire; focus loss resets all leases and held buttons.
Return values follow legacy mouse_guard: 0 inactive, 1 active, negative failure.

`notify_sound():Void` plays the system notification only while the owning
process has the foreground, non-minimized window. SimpleLFG invokes it only
for an enabled watch sound. It is off by default.

`sync_confinement(Bool):Int` retains its existing API and does not take over
cursor visibility, shape, or position. See `sfcursor/README.md` for legacy APIs.

## Installation and upgrades

Use the separately versioned helper archive. Compare its fingerprint in
`compatibility.json` with any installed helper; never silently replace another
mod's shared dependency. **Close Farever before replacement, then restart it.**
The helper is pinned once loaded and cannot be safely hot replaced. Removing
SimpleLFG does not remove shared SFCursor, SFimgui, or HLX.

With an older or absent helper SimpleLFG's optional imports still load; Settings
→ General → Diagnostics reports missing owner-aware mouse protection. Update
the helper for the full supported installation. No fallback to legacy guard
ownership is attempted.
