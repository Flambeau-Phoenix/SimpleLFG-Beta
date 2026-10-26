// Exercise the production function with fake Win32 state. Never clips the desktop.
#define HL_NAME(n) sfcursor_##n
#include <hl.h>
#undef _GUID
#include <windows.h>
#include <cstdio>
#include <cstdlib>

static RECT fakeClip = {-5000, -5000, 5000, 5000};
static RECT fakeClient = {0, 0, 800, 600};
static HWND fakeWindow = reinterpret_cast<HWND>(1);
static DWORD fakePid = 42;
static bool minimized = false, queryFails = false, applyFails = false;
static int updates = 0, releases = 0;
static HWND mockForeground() { return fakeWindow; }
static DWORD mockWindowPid(HWND, DWORD *pid) { *pid = fakePid; return 1; }
static DWORD mockCurrentPid() { return 42; }
static BOOL mockIconic(HWND) { return minimized; }
static BOOL mockClient(HWND, RECT *rect) { *rect = fakeClient; return TRUE; }
static int mockMap(HWND, HWND, POINT *points, UINT count) {
    for (UINT i = 0; i < count; ++i) { points[i].x += 100; points[i].y += 50; }
    return 1;
}
static BOOL mockGetClip(RECT *rect) { if (queryFails) return FALSE; *rect = fakeClip; return TRUE; }
static BOOL mockClip(const RECT *rect) {
    if (applyFails) return FALSE;
    if (rect) { ++updates; fakeClip = *rect; }
    else { ++releases; fakeClip = {-5000, -5000, 5000, 5000}; }
    return TRUE;
}
#define GetForegroundWindow mockForeground
#define GetWindowThreadProcessId mockWindowPid
#define GetCurrentProcessId mockCurrentPid
#define IsIconic mockIconic
#define GetClientRect mockClient
#define MapWindowPoints mockMap
#define GetClipCursor mockGetClip
#define ClipCursor mockClip
#include "cursor.cpp"

static void require(bool condition, const char *message) {
    if (!condition) { std::fprintf(stderr, "FAIL: %s\n", message); std::exit(1); }
}
int main() {
    require(sfcursor_sync_confinement(true) == 1 && updates == 1, "initial confinement applied once");
    for (int i = 0; i < 10000; ++i)
        require(sfcursor_sync_confinement(true) == 0, "steady frame unchanged");
    require(updates == 1, "10000 steady frames perform no repeated ClipCursor");
    fakeClip = {-5000, -5000, 5000, 5000}; // Another layer releases confinement.
    require(sfcursor_sync_confinement(true) == 1 && updates == 2, "released confinement repaired once");
    fakeClient.right = 1000;
    require(sfcursor_sync_confinement(true) == 1 && fakeClip.right == 1100, "resize updates screen bounds");
    fakePid = 99;
    require(sfcursor_sync_confinement(true) == 2 && releases == 1, "Alt+Tab releases owned rectangle");
    require(sfcursor_sync_confinement(true) == 3 && updates == 3, "background never confines other process");
    fakePid = 42;
    require(sfcursor_sync_confinement(true) == 1, "foreground return restores confinement");
    require(sfcursor_sync_confinement(false) == 2, "free cursor releases confinement");
    require(sfcursor_sync_confinement(false) == 0, "free cursor steady state does no release");
    fakeClip = {100, 50, 1100, 650};
    require(sfcursor_sync_confinement(true) == 0, "adopts matching engine confinement without reapplying");
    minimized = true;
    require(sfcursor_sync_confinement(true) == 2, "minimize releases adopted rectangle");
    minimized = false;
    require(sfcursor_sync_confinement(true) == 1, "restored window confined");
    fakeClip = {1, 2, 3, 4};
    int previousReleases = releases;
    require(sfcursor_sync_confinement(false) == 0 && releases == previousReleases, "leaves another layer's changed rectangle intact");
    fakeWindow = nullptr;
    require(sfcursor_sync_confinement(true) == 3, "no foreground stays inactive");
    fakeWindow = reinterpret_cast<HWND>(1);
    fakeClient.right = 0;
    require(sfcursor_sync_confinement(true) == -1, "empty client never captures");
    fakeClient.right = 800;
    queryFails = true;
    require(sfcursor_sync_confinement(true) == -1, "query failure does not blindly reclip");
    queryFails = false; applyFails = true;
    require(sfcursor_sync_confinement(true) == -1, "native apply failure is reported");
    std::puts("sfcursor tests PASS (10000 steady frames, repair, resize, focus, free cursor, ownership, failures)");
}
