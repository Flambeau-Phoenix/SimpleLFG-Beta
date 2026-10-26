#define HL_NAME(n) sfcursor_##n
#include <hl.h>
#undef _GUID
#define NOMINMAX
#include <windows.h>
#include <commctrl.h>
#include "mouse_policy.h"
#include <cstring>

// Keeps clicks and wheel turns that land on a SolarFlare window away from the game's own UI underneath.
// Our subclass sits outside SFImGui's, so a message we swallow never reaches SFImGui: we hand the swallowed
// press, release or wheel turn to ImGui ourselves, then drop it. Only this process's foreground window is
// eligible, only while the mod keeps refreshing the heartbeat, and anything missing fails open (messages pass).
static MouseGuardPolicy mousePolicy;
static SRWLOCK mouseLock = SRWLOCK_INIT;
static HWND mouseWindow = nullptr;
static bool mouseEnabled = false;
static ULONGLONG mouseHeartbeat = 0;
static constexpr UINT_PTR MOUSE_SUBCLASS = 0x5346454D;
struct MouseClient { char name[64] = {}; bool enabled=false; ULONGLONG stamp=0; };
static MouseClient mouseClients[16];
static bool mouseAnyClient(ULONGLONG now) {
    bool active=false;
    for(auto &client:mouseClients) {
        if(client.enabled && now-client.stamp>500) client.enabled=false;
        active=active||client.enabled;
    }
    return active;
}
using MousePtrGetter = void*(*)();
using MouseBoolGetter = bool(*)(void*);
using MouseButtonFeed = void(*)(void*, int, bool);
using MouseWheelFeed = void(*)(void*, float, float);
static MousePtrGetter mouseGetContext = nullptr, mouseGetIo = nullptr;
static MouseBoolGetter mouseWantsCapture = nullptr;
static MouseButtonFeed mouseFeedButton = nullptr;
static MouseWheelFeed mouseFeedWheel = nullptr;

static bool mouseResolve() {
    HMODULE module = GetModuleHandleW(L"sfimgui.hdll");
    if (!module) return false;
    mouseGetContext = reinterpret_cast<MousePtrGetter>(GetProcAddress(module, "sfimgui_igGetCurrentContext"));
    mouseGetIo = reinterpret_cast<MousePtrGetter>(GetProcAddress(module, "sfimgui_igGetIO_Nil"));
    mouseWantsCapture = reinterpret_cast<MouseBoolGetter>(GetProcAddress(module, "sfimgui_ImGuiIO_get_WantCaptureMouse"));
    mouseFeedButton = reinterpret_cast<MouseButtonFeed>(GetProcAddress(module, "sfimgui_ImGuiIO_AddMouseButtonEvent"));
    mouseFeedWheel = reinterpret_cast<MouseWheelFeed>(GetProcAddress(module, "sfimgui_ImGuiIO_AddMouseWheelEvent"));
    return mouseGetContext && mouseGetIo && mouseWantsCapture && mouseFeedButton && mouseFeedWheel;
}
static void* mouseIo() {
    if (!mouseGetContext || !mouseGetContext() || !mouseGetIo) return nullptr;
    return mouseGetIo();
}
// Fails open: with no ImGui context the UI is never considered to want the mouse.
static bool mouseUiWants() {
    void* io = mouseIo();
    return io && mouseWantsCapture && mouseWantsCapture(io);
}
static void mouseReleaseOwned() {
    int mask = mousePolicy.reset();
    void* io = mask ? mouseIo() : nullptr;
    if (io && mouseFeedButton) for (int i = 0; i < MouseGuardPolicy::BUTTONS; ++i) if (mask & (1 << i)) mouseFeedButton(io, i, false);
}

static LRESULT CALLBACK mouseProc(HWND window, UINT message, WPARAM wParam, LPARAM lParam, UINT_PTR, DWORD_PTR) {
    bool swallow = false, remove = false;
    AcquireSRWLockExclusive(&mouseLock);
    if (message == WM_NCDESTROY || message == WM_KILLFOCUS || (message == WM_ACTIVATEAPP && !wParam)) {
        mouseReleaseOwned();
        for(auto &client:mouseClients)client.enabled=false;
        mouseEnabled=false;
        if (message == WM_NCDESTROY) { remove = true; mouseWindow = nullptr; }
    } else {
        int button = -1; bool down = false; int wheel = 0;
        switch (message) {
            case WM_LBUTTONDOWN: case WM_LBUTTONDBLCLK: button = 0; down = true; break;
            case WM_LBUTTONUP: button = 0; break;
            case WM_RBUTTONDOWN: case WM_RBUTTONDBLCLK: button = 1; down = true; break;
            case WM_RBUTTONUP: button = 1; break;
            case WM_MBUTTONDOWN: case WM_MBUTTONDBLCLK: button = 2; down = true; break;
            case WM_MBUTTONUP: button = 2; break;
            case WM_MOUSEWHEEL: wheel = 1; break;
            case WM_MOUSEHWHEEL: wheel = 2; break;
            default: break;
        }
        if (button >= 0 || wheel) {
            mouseEnabled=mouseAnyClient(GetTickCount64());
            bool active = mouseEnabled && GetForegroundWindow() == window;
            // Releases are routed by ownership even when the guard has gone idle, so a button never sticks.
            bool wants = (active || mousePolicy.anyUiDown()) && mouseUiWants();
            void* io = mouseIo();
            if (button >= 0) {
                auto action = mousePolicy.button(button, down, active, wants);
                if (action != MouseGuardPolicy::Pass && io && mouseFeedButton) {
                    mouseFeedButton(io, button, action == MouseGuardPolicy::SwallowDown);
                    swallow = true;
                } else if (action != MouseGuardPolicy::Pass) {
                    // The UI cannot be fed (should not happen after resolve); let the game have it rather than lose it.
                    mousePolicy.reset();
                }
            } else if (mousePolicy.wheel(active, wants) == MouseGuardPolicy::SwallowWheel && io && mouseFeedWheel) {
                float delta = static_cast<float>(static_cast<short>(HIWORD(wParam))) / 120.0f;
                if (wheel == 1) mouseFeedWheel(io, 0.0f, delta); else mouseFeedWheel(io, delta, 0.0f);
                swallow = true;
            }
        }
        if (!mouseEnabled && !mousePolicy.anyUiDown()) { remove = true; mouseWindow = nullptr; }
    }
    ReleaseSRWLockExclusive(&mouseLock);
    if (remove) RemoveWindowSubclass(window, mouseProc, MOUSE_SUBCLASS);
    return swallow ? 0 : DefSubclassProc(window, message, wParam, lParam);
}

// 1 active, 0 disabled/inactive; -1 SFImGui capture/feed API missing, -2 wrong thread, -3 install failed.
static int configureMouseClient(const char *owner,bool enabled) {
    if(!owner||!owner[0]||strnlen_s(owner,64)>=64)return -4;
    HWND window = GetForegroundWindow(); DWORD pid = 0;
    DWORD thread = window ? GetWindowThreadProcessId(window, &pid) : 0;
    bool own = window && pid == GetCurrentProcessId() && !IsIconic(window);
    bool activate = enabled && own;
    if (activate && !mouseWindow) {
        if (thread != GetCurrentThreadId()) return -2;
        if (!mouseResolve()) return -1;
        HMODULE pinned = nullptr;
        if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN,
            reinterpret_cast<LPCWSTR>(&mouseProc), &pinned) || !SetWindowSubclass(window, mouseProc, MOUSE_SUBCLASS, 0)) return -3;
        mouseWindow = window;
    }
    AcquireSRWLockExclusive(&mouseLock);
    mouseAnyClient(GetTickCount64());
    MouseClient *slot=nullptr;
    for(auto &client:mouseClients)if(std::strcmp(client.name,owner)==0){slot=&client;break;}
    if(!slot && activate)for(auto &client:mouseClients)if(!client.enabled){slot=&client;strcpy_s(client.name,owner);break;}
    if(!slot && activate){ReleaseSRWLockExclusive(&mouseLock);return -4;}
    if(slot){slot->enabled=activate && window==mouseWindow;slot->stamp=GetTickCount64();}
    mouseEnabled = mouseAnyClient(GetTickCount64());
    mouseHeartbeat = GetTickCount64();
    HWND detach = nullptr;
    if (mouseWindow && !mouseEnabled && !mousePolicy.anyUiDown() && GetWindowThreadProcessId(mouseWindow, nullptr) == GetCurrentThreadId()) { detach = mouseWindow; mouseWindow = nullptr; }
    int result = activate && mouseEnabled ? 1 : 0;
    ReleaseSRWLockExclusive(&mouseLock);
    if (detach) RemoveWindowSubclass(detach, mouseProc, MOUSE_SUBCLASS);
    return result;
}
HL_PRIM int HL_NAME(mouse_guard)(bool enabled) {return configureMouseClient("__legacy",enabled);}
DEFINE_PRIM(_I32, mouse_guard, _BOOL);
HL_PRIM int HL_NAME(mouse_guard_client)(vbyte *owner,bool enabled) {return configureMouseClient(reinterpret_cast<const char*>(owner),enabled);}
DEFINE_PRIM(_I32, mouse_guard_client, _BYTES _BOOL);
HL_PRIM void HL_NAME(notify_sound)() {
    HWND window=GetForegroundWindow();DWORD pid=0;
    if(window)GetWindowThreadProcessId(window,&pid);
    if(window&&pid==GetCurrentProcessId()&&!IsIconic(window))MessageBeep(MB_ICONINFORMATION);
}
DEFINE_PRIM(_VOID, notify_sound, _NO_ARG);
