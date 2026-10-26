#define HL_NAME(n) sfcursor_##n
#include <hl.h>
#undef _GUID
#include <windows.h>

static bool owned = false;
static RECT ownedRect = {};

static bool sameRect(const RECT &a, const RECT &b) {
    return a.left == b.left && a.top == b.top && a.right == b.right && a.bottom == b.bottom;
}

// Relinquish only a rectangle we set and which nobody has subsequently changed.
static int releaseOwned() {
    if (!owned) return 0;
    RECT current;
    if (!GetClipCursor(&current)) return -1;
    if (!sameRect(current, ownedRect)) { owned = false; return 0; }
    if (!ClipCursor(nullptr)) return -1;
    owned = false;
    return 2;
}

HL_PRIM int HL_NAME(sync_confinement)(bool confined) {
    HWND window = GetForegroundWindow();
    DWORD pid = 0;
    if (window) GetWindowThreadProcessId(window, &pid);
    // Never capture the desktop or another application on Alt+Tab/minimize.
    if (!window || pid != GetCurrentProcessId() || IsIconic(window)) {
        int result = releaseOwned();
        return result == 0 ? 3 : result;
    }
    if (!confined) return releaseOwned();
    RECT desired, current;
    if (!GetClientRect(window, &desired) || desired.right <= desired.left || desired.bottom <= desired.top)
        return -1;
    SetLastError(0);
    if (!MapWindowPoints(window, nullptr, reinterpret_cast<POINT *>(&desired), 2) && GetLastError())
        return -1;
    if (!GetClipCursor(&current)) return -1;
    // The game can establish the same confinement before our frame callback.
    // Adopt that policy rectangle so Alt+Tab/free-cursor can relinquish it too.
    if (sameRect(current, desired)) { ownedRect = desired; owned = true; return 0; }
    if (!ClipCursor(&desired)) return -1;
    ownedRect = desired;
    owned = true;
    return 1;
}
DEFINE_PRIM(_I32, sync_confinement, _BOOL);
