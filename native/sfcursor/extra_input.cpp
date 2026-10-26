#define HL_NAME(n) sfcursor_##n
#include <hl.h>
#undef _GUID
#define NOMINMAX
#include <windows.h>
#include <commctrl.h>
#include "extra_policy.h"

static ExtraBarsPolicy bars;
static SRWLOCK barsLock = SRWLOCK_INIT;
static HWND barsWindow = nullptr;
static bool detachPending = false;
static ULONGLONG heartbeat = 0;
static constexpr UINT_PTR BARS_SUBCLASS = 0x53464542;
using PtrGetter = void*(*)();
using BoolGetter = bool(*)(void*);
static PtrGetter getContext = nullptr, getIo = nullptr;
static BoolGetter wantsKeyboard = nullptr;

static bool nativeModifiers() {
    return (GetAsyncKeyState(VK_CONTROL) & 0x8000) || (GetAsyncKeyState(VK_SHIFT) & 0x8000)
        || (GetAsyncKeyState(VK_MENU) & 0x8000) || (GetAsyncKeyState(VK_LWIN) & 0x8000) || (GetAsyncKeyState(VK_RWIN) & 0x8000);
}
static bool resolveCapture() {
    HMODULE module = GetModuleHandleW(L"sfimgui.hdll");
    if (!module) return false;
    getContext = reinterpret_cast<PtrGetter>(GetProcAddress(module, "sfimgui_igGetCurrentContext"));
    getIo = reinterpret_cast<PtrGetter>(GetProcAddress(module, "sfimgui_igGetIO_Nil"));
    wantsKeyboard = reinterpret_cast<BoolGetter>(GetProcAddress(module, "sfimgui_ImGuiIO_get_WantCaptureKeyboard"));
    return getContext && getIo && wantsKeyboard;
}
static bool uiOwnsKeyboard() { return !getContext || !getContext() || !getIo || !wantsKeyboard || wantsKeyboard(getIo()); }
static LRESULT CALLBACK barsProc(HWND window, UINT message, WPARAM wParam, LPARAM lParam, UINT_PTR, DWORD_PTR) {
    bool swallow = false, remove = false;
    AcquireSRWLockExclusive(&barsLock);
    if (message == WM_NCDESTROY || message == WM_KILLFOCUS || (message == WM_ACTIVATEAPP && !wParam)) {
        bars.focusLost();
        if (message == WM_NCDESTROY || detachPending) { remove = true; barsWindow = nullptr; detachPending = false; }
    } else {
        // Capture wins. Pass UI-owned messages to SFImGui; never call managed game code here.
        if (GetForegroundWindow() != window || GetTickCount64() - heartbeat > 500 || uiOwnsKeyboard()) bars.cancel();
        int vk = 0; bool pressed = false, repeat = false;
        if (message == WM_KEYDOWN || message == WM_SYSKEYDOWN || message == WM_KEYUP || message == WM_SYSKEYUP) {
            vk = static_cast<int>(wParam);
            pressed = message == WM_KEYDOWN || message == WM_SYSKEYDOWN;
            repeat = pressed && (static_cast<ULONG_PTR>(lParam) & (1ULL << 30));
        } else if (message == WM_XBUTTONDOWN || message == WM_XBUTTONUP) {
            vk = HIWORD(wParam) == XBUTTON1 ? VK_XBUTTON1 : VK_XBUTTON2;
            pressed = message == WM_XBUTTONDOWN;
        }
        if (vk) swallow = bars.event(vk, pressed, repeat, nativeModifiers());
        if (message == WM_CHAR || message == WM_SYSCHAR || message == WM_DEADCHAR || message == WM_SYSDEADCHAR || message == WM_UNICHAR) {
            UINT scan = (static_cast<ULONG_PTR>(lParam) >> 16) & 0xFF;
            if (static_cast<ULONG_PTR>(lParam) & (1ULL << 24)) scan |= 0xE000;
            UINT charKey = MapVirtualKeyW(scan, MAPVK_VSC_TO_VK_EX);
            if (charKey < 256 && bars.blocked[charKey]) swallow = true;
        }
        if (detachPending && !bars.hasBlocked()) { remove = true; barsWindow = nullptr; detachPending = false; }
    }
    ReleaseSRWLockExclusive(&barsLock);
    if (remove) RemoveWindowSubclass(window, barsProc, BARS_SUBCLASS);
    if (swallow) return 0;
    return DefSubclassProc(window, message, wParam, lParam);
}

// -1 capture API missing; -2 wrong window thread; -3 subclass install failed.
static int configureKeys(int prefix, const int* keys, int mode, bool eligible, int generation) {
    HWND window = GetForegroundWindow(); DWORD pid = 0;
    DWORD thread = window ? GetWindowThreadProcessId(window, &pid) : 0;
    if (!window || pid != GetCurrentProcessId() || IsIconic(window)) eligible = false;
    if (eligible && !barsWindow) {
        if (thread != GetCurrentThreadId()) return -2;
        if (!resolveCapture()) return -1;
        // Pin this already-loaded helper while it owns a callback. Native replacement requires restart.
        HMODULE pinned = nullptr;
        if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN,
            reinterpret_cast<LPCWSTR>(&barsProc), &pinned) || !SetWindowSubclass(window, barsProc, BARS_SUBCLASS, 0)) return -3;
        barsWindow = window;
    }
    AcquireSRWLockExclusive(&barsLock);
    heartbeat = GetTickCount64();
    bool owned = barsWindow && window == barsWindow && thread == GetCurrentThreadId();
    bool mods = nativeModifiers();
    bool held = (prefix > 0 && (GetAsyncKeyState(prefix) & 0x8000)) || bars.hasBlocked();
    for (int i=1; i<256; ++i) if (keys[i] > 0 && (GetAsyncKeyState(i) & 0x8000)) held = true;
    bars.configureMany(prefix, keys, mode, eligible && owned && !uiOwnsKeyboard(), generation, held, mods);
    if (eligible) detachPending = false;
    int result = eligible && !owned ? -2 : owned ? (bars.active() ? 1 : 0) : 0;
    ReleaseSRWLockExclusive(&barsLock);
    return result;
}
HL_PRIM int HL_NAME(extra_configure)(int prefix, int key, int mode, bool eligible, int generation) {
    int keys[256] = {}; if (key > 0 && key < 256) keys[key] = 1;
    return configureKeys(prefix, keys, mode, eligible, generation);
}
DEFINE_PRIM(_I32, extra_configure, _I32 _I32 _I32 _BOOL _I32);

HL_PRIM int HL_NAME(extra_configure_many)(int prefix, int mode, bool eligible, int generation, vbyte* bytes, int length) {
    if (!bytes || length != 1024) { AcquireSRWLockExclusive(&barsLock); bars.cancel(); ReleaseSRWLockExclusive(&barsLock); return -4; }
    static_assert(sizeof(int) == 4, "32-bit token ABI required");
    int keys[256]; std::memcpy(keys, bytes, sizeof(keys));
    return configureKeys(prefix, keys, mode, eligible, generation);
}
DEFINE_PRIM(_I32, extra_configure_many, _I32 _I32 _BOOL _I32 _BYTES _I32);

HL_PRIM int HL_NAME(extra_take)(int generation) {
    AcquireSRWLockExclusive(&barsLock);
    if (GetForegroundWindow() != barsWindow || GetTickCount64() - heartbeat > 500 || uiOwnsKeyboard()) bars.cancel();
    int result = bars.takeToken(generation);
    ReleaseSRWLockExclusive(&barsLock);
    return result;
}
DEFINE_PRIM(_I32, extra_take, _I32);

HL_PRIM int HL_NAME(extra_status)() {
    AcquireSRWLockShared(&barsLock);
    int result = (bars.active() ? 1 : 0) | (bars.recovering ? 2 : 0) | (bars.toggled ? 4 : 0)
        | (bars.prefix > 0 && bars.prefix < 256 && bars.down[bars.prefix] ? 8 : 0);
    ReleaseSRWLockShared(&barsLock);
    return result;
}
DEFINE_PRIM(_I32, extra_status, _NO_ARG);

HL_PRIM void HL_NAME(extra_reset)() {
    AcquireSRWLockExclusive(&barsLock); bars.cancel(); ReleaseSRWLockExclusive(&barsLock);
}
DEFINE_PRIM(_VOID, extra_reset, _NO_ARG);

HL_PRIM bool HL_NAME(extra_shutdown)() {
    AcquireSRWLockExclusive(&barsLock);
    bars.cancel(); detachPending = true;
    HWND window = barsWindow;
    bool canRemove = !window || (!bars.hasBlocked() && GetWindowThreadProcessId(window, nullptr) == GetCurrentThreadId());
    if (canRemove) { barsWindow = nullptr; detachPending = false; }
    ReleaseSRWLockExclusive(&barsLock);
    if (window && canRemove) return RemoveWindowSubclass(window, barsProc, BARS_SUBCLASS) != FALSE;
    return !window;
}
DEFINE_PRIM(_BOOL, extra_shutdown, _NO_ARG);
