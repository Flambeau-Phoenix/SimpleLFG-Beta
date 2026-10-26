// Compile the production mouse guard with fake window/capture calls. No desktop input.
#define HL_NAME(n) sfcursor_##n
#include <hl.h>
#undef _GUID
#include <windows.h>
#include <commctrl.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
static HWND fakeWindow = reinterpret_cast<HWND>(1);
static DWORD fakeThread = 42, fakePid = 42;
static bool wantsMouse = false, exportMissing = false, installFails = false, foreground = true, minimized=false;
static int sounds=0;
static ULONGLONG fakeClock = 1000;
static int forwards = 0, removes = 0, installs = 0;
static int fedButtons[64], fedStates[64], fedCount = 0;
static float lastWheelX = 0, lastWheelY = 0;
static int wheelFeeds = 0;
static void *mockContext() { return reinterpret_cast<void*>(1); }
static void *mockIo() { return reinterpret_cast<void*>(2); }
static bool mockWants(void*) { return wantsMouse; }
static void mockButton(void*, int button, bool down) { if (fedCount < 64) { fedButtons[fedCount] = button; fedStates[fedCount] = down ? 1 : 0; ++fedCount; } }
static void mockWheel(void*, float x, float y) { lastWheelX = x; lastWheelY = y; ++wheelFeeds; }
static HWND mockForeground() { return foreground ? fakeWindow : reinterpret_cast<HWND>(7); }
static DWORD mockWindowThread(HWND window, DWORD *pid) { if (pid) *pid = window==fakeWindow?fakePid:999; return fakeThread; }
static DWORD mockCurrent() { return 42; }
static BOOL mockIconic(HWND) { return minimized; }
static BOOL mockBeep(UINT) {sounds++;return TRUE;}
static HMODULE mockModule(LPCWSTR) { return reinterpret_cast<HMODULE>(1); }
static FARPROC mockExport(HMODULE, LPCSTR name) {
    if (exportMissing) return nullptr;
    if (!std::strcmp(name,"sfimgui_igGetCurrentContext")) return reinterpret_cast<FARPROC>(mockContext);
    if (!std::strcmp(name,"sfimgui_igGetIO_Nil")) return reinterpret_cast<FARPROC>(mockIo);
    if (!std::strcmp(name,"sfimgui_ImGuiIO_get_WantCaptureMouse")) return reinterpret_cast<FARPROC>(mockWants);
    if (!std::strcmp(name,"sfimgui_ImGuiIO_AddMouseButtonEvent")) return reinterpret_cast<FARPROC>(mockButton);
    if (!std::strcmp(name,"sfimgui_ImGuiIO_AddMouseWheelEvent")) return reinterpret_cast<FARPROC>(mockWheel);
    return nullptr;
}
static BOOL mockPin(DWORD, LPCWSTR, HMODULE *module) { *module = reinterpret_cast<HMODULE>(1); return TRUE; }
static BOOL mockInstall(HWND, SUBCLASSPROC, UINT_PTR, DWORD_PTR) { ++installs; return !installFails; }
static BOOL mockRemove(HWND, SUBCLASSPROC, UINT_PTR) { ++removes; return TRUE; }
static LRESULT mockForward(HWND,UINT,WPARAM,LPARAM) { ++forwards; return 37; }
static ULONGLONG mockClock() { return fakeClock; }
#define GetForegroundWindow mockForeground
#define GetWindowThreadProcessId mockWindowThread
#define GetCurrentProcessId mockCurrent
#define GetCurrentThreadId mockCurrent
#define IsIconic mockIconic
#define GetModuleHandleW mockModule
#define GetProcAddress mockExport
#define GetModuleHandleExW mockPin
#define SetWindowSubclass mockInstall
#define RemoveWindowSubclass mockRemove
#define DefSubclassProc mockForward
#define GetTickCount64 mockClock
#define MessageBeep mockBeep
#include "mouse_input.cpp"
static int checks = 0;
static void check(bool value, const char *label) { ++checks; if (!value) { std::fprintf(stderr,"FAIL: %s\n",label); std::exit(1); } }
static LRESULT send(UINT message, WPARAM wParam = 0, LPARAM lParam = 0) { return mouseProc(fakeWindow, message, wParam, lParam, 0, 0); }
static LRESULT wheelMsg(short delta, bool horizontal = false) {
    return send(horizontal ? WM_MOUSEHWHEEL : WM_MOUSEWHEEL, static_cast<WPARAM>(static_cast<unsigned short>(delta)) << 16);
}
static void resetWorld() {
    wantsMouse = false; exportMissing = false; installFails = false; foreground = true; fakeThread = 42;
    forwards = 0; removes = 0; fedCount = 0; wheelFeeds = 0; mousePolicy = MouseGuardPolicy();
}

int main() {
    // ---- Pure policy ----
    MouseGuardPolicy p;
    check(p.button(0, true, true, false) == MouseGuardPolicy::Pass, "Policy: a press the UI does not want goes to the game");
    check(p.button(0, false, true, true) == MouseGuardPolicy::Pass, "Policy: its release goes to the game even over a window");
    check(p.button(0, true, true, true) == MouseGuardPolicy::SwallowDown && p.anyUiDown(), "Policy: a press the UI wants is kept from the game");
    check(p.button(0, false, true, false) == MouseGuardPolicy::SwallowUp && !p.anyUiDown(), "Policy: its release follows it even after the UI stops wanting the mouse");
    check(p.button(0, true, false, true) == MouseGuardPolicy::Pass, "Policy: an idle guard never takes a press");
    check(p.button(7, true, true, true) == MouseGuardPolicy::Pass && p.button(-1, false, true, true) == MouseGuardPolicy::Pass, "Policy: unknown buttons pass");
    check(p.wheel(true, true) == MouseGuardPolicy::SwallowWheel && p.wheel(true, false) == MouseGuardPolicy::Pass && p.wheel(false, true) == MouseGuardPolicy::Pass, "Policy: the wheel follows the UI only while active");
    p.button(1, true, true, true); p.button(2, true, true, true);
    check(p.reset() == ((1 << 1) | (1 << 2)) && !p.anyUiDown() && p.reset() == 0, "Policy: reset reports and clears owned buttons");

    // ---- Install / configure ----
    resetWorld();
    check(sfcursor_mouse_guard(false) == 0 && installs == 0, "Disabled guard installs nothing");
    exportMissing = true;
    check(sfcursor_mouse_guard(true) == -1 && installs == 0, "Missing SFImGui exports fail open without installing");
    exportMissing = false; fakeThread = 5;
    check(sfcursor_mouse_guard(true) == -2, "Wrong window thread is refused");
    fakeThread = 42; installFails = true;
    check(sfcursor_mouse_guard(true) == -3, "Install failure is reported");
    installFails = false; installs = 0;
    check(sfcursor_mouse_guard(true) == 1 && installs == 1 && mouseWindow == fakeWindow, "Enabled guard installs on the game window");
    check(sfcursor_mouse_guard(true) == 1 && installs == 1, "Enabling again does not install twice");

    // ---- Clicks over the game ----
    check(send(WM_LBUTTONDOWN) == 37 && forwards == 1 && fedCount == 0, "Over the game a press passes through untouched");
    check(send(WM_LBUTTONUP) == 37 && forwards == 2, "Over the game a release passes through");

    // ---- Clicks over a SolarFlare window ----
    wantsMouse = true; forwards = 0;
    check(send(WM_LBUTTONDOWN) == 0 && forwards == 0 && fedCount == 1 && fedButtons[0] == 0 && fedStates[0] == 1, "A press on a window is kept from the game and handed to ImGui");
    wantsMouse = false;
    check(send(WM_LBUTTONUP) == 0 && forwards == 0 && fedCount == 2 && fedStates[1] == 0, "Its release is also kept, even if the cursor left the window");
    check(send(WM_LBUTTONUP) == 37 && forwards == 1 && fedCount == 2, "A stray release passes");
    forwards = 0; fedCount = 0; wantsMouse = true;
    check(send(WM_RBUTTONDOWN) == 0 && send(WM_RBUTTONUP) == 0 && send(WM_MBUTTONDOWN) == 0 && send(WM_MBUTTONUP) == 0 && forwards == 0, "Right and middle buttons are handled the same way");
    check(fedCount == 4 && fedButtons[0] == 1 && fedButtons[2] == 2, "Each button reaches ImGui as its own index");
    fedCount = 0;
    check(send(WM_LBUTTONDBLCLK) == 0 && fedCount == 1 && fedStates[0] == 1, "A double-click press counts as a press");
    send(WM_LBUTTONUP); fedCount = 0; forwards = 0;

    // ---- Drag that started in the game ----
    wantsMouse = false;
    check(send(WM_LBUTTONDOWN) == 37, "A drag begins in the game");
    wantsMouse = true;
    check(send(WM_LBUTTONUP) == 37 && fedCount == 0, "Releasing over a window ends the game's drag instead of stranding it");

    // ---- Wheel, moves, side buttons ----
    forwards = 0;
    check(wheelMsg(120) == 0 && wheelFeeds == 1 && lastWheelY == 1.0f && lastWheelX == 0.0f, "A wheel turn over a window scrolls the window");
    check(wheelMsg(-240) == 0 && lastWheelY == -2.0f, "Wheel direction and size are kept");
    check(wheelMsg(120, true) == 0 && lastWheelX == 1.0f && lastWheelY == 0.0f, "Horizontal wheel turns feed the other axis");
    check(send(WM_MOUSEMOVE) == 37 && send(WM_XBUTTONDOWN) == 37 && send(WM_XBUTTONUP) == 37 && send(WM_KEYDOWN, 'A') == 37, "Moves, side buttons and keys are never touched");
    wantsMouse = false; forwards = 0;
    check(wheelMsg(120) == 37, "A wheel turn over the game passes");

    // ---- Safety ----
    wantsMouse = true; forwards = 0;
    fakeClock += 1000;
    check(send(WM_LBUTTONDOWN) == 37, "A stale heartbeat makes the guard passive");
    send(WM_LBUTTONUP);
    sfcursor_mouse_guard(true); foreground = false;
    check(send(WM_LBUTTONDOWN) == 37, "Another foreground window makes the guard passive");
    foreground = true; sfcursor_mouse_guard(true); fedCount = 0;
    check(send(WM_LBUTTONDOWN) == 0 && fedCount == 1, "Rearmed guard takes the press again");
    send(WM_KILLFOCUS);
    check(fedCount == 2 && fedButtons[1] == 0 && fedStates[1] == 0 && !mousePolicy.anyUiDown(), "Losing focus tells ImGui the button is up and forgets ownership");
    check(send(WM_LBUTTONUP) == 37, "The release after focus loss belongs to the game");

    // ---- Disabling while a button is held ----
    wantsMouse = true; sfcursor_mouse_guard(true);
    send(WM_LBUTTONDOWN); removes = 0;
    check(sfcursor_mouse_guard(false) == 0 && removes == 0, "Disabling mid-press keeps the guard until the release");
    check(send(WM_LBUTTONUP) == 0 && removes == 1 && mouseWindow == nullptr, "Then the release is handled and the guard detaches");
    int installsBeforeRearm=installs;
    check(sfcursor_mouse_guard(true) == 1 && installs == installsBeforeRearm+1, "It can be enabled again");
    send(WM_NCDESTROY);
    check(removes == 2 && mouseWindow == nullptr, "Destroying the window removes the guard");

    // Independent clients must coexist with legacy SolarFlare callers in any order.
    auto first=reinterpret_cast<vbyte*>(const_cast<char*>("simplelfg"));
    auto second=reinterpret_cast<vbyte*>(const_cast<char*>("other-ui"));
    wantsMouse=true;
    check(sfcursor_mouse_guard_client(first,true)==1,"First named client arms the guard");
    check(sfcursor_mouse_guard(false)==0&&mouseEnabled,"Legacy false cannot clear a named client");
    check(send(WM_LBUTTONDOWN)==0&&send(WM_LBUTTONUP)==0,"Named client still protects clicks after legacy false");
    check(sfcursor_mouse_guard(true)==1,"Legacy client coexists with named client");
    check(sfcursor_mouse_guard_client(first,false)==0&&mouseEnabled,"Named false cannot clear legacy client");
    check(sfcursor_mouse_guard_client(second,true)==1,"Second named client arms independently");
    check(sfcursor_mouse_guard(false)==0&&mouseEnabled,"Legacy client can release while second remains");
    fakeClock+=400;sfcursor_mouse_guard_client(first,true);fakeClock+=200;
    check(send(WM_LBUTTONDOWN)==0&&send(WM_LBUTTONUP)==0,"Expired second client does not expire refreshed first");
    fakeClock+=600;
    check(send(WM_LBUTTONDOWN)==37,"All stale named leases become passive");send(WM_LBUTTONUP);
    sfcursor_mouse_guard_client(first,true);sfcursor_mouse_guard_client(second,true);
    check(sfcursor_mouse_guard_client(first,false)==0&&mouseEnabled,"Two named owners survive one releasing");
    send(WM_LBUTTONDOWN);sfcursor_mouse_guard_client(second,false);
    check(send(WM_LBUTTONUP)==0,"Last client releasing mid-press preserves paired release");
    check(sfcursor_mouse_guard_client(nullptr,true)==-4,"Null owner is rejected");
    sfcursor_mouse_guard_client(first,true);send(WM_KILLFOCUS);
    check(!mouseEnabled&&!mousePolicy.anyUiDown(),"Focus loss invalidates all leases and button ownership");
    foreground=false;sfcursor_notify_sound();check(sounds==0,"Notification sound silent outside own foreground process");
    foreground=true;minimized=true;sfcursor_notify_sound();check(sounds==0,"Notification sound silent while minimized");
    minimized=false;sfcursor_notify_sound();check(sounds==1,"Notification sound requests own foreground only (mocked, no audio)");
    std::printf("sfcursor mouse guard: %d checks passed\n", checks);
    return 0;
}
