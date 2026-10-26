#define HL_NAME(n) sfcursor_##n
#include <hl.h>
#undef _GUID
#define NOMINMAX
#include <windows.h>
#include <commctrl.h>

// Independent of ExtraBars activation. Only this process's foreground window is eligible.
static SRWLOCK guardLock=SRWLOCK_INIT;
static HWND guardWindow=nullptr;
static bool guardEnabled=false, guardOwnedF=false;
static ULONGLONG guardHeartbeat=0;
static constexpr UINT_PTR GUARD_SUBCLASS=0x53464746;
using GuardPtrGetter=void*(*)();
using GuardBoolGetter=bool(*)(void*);
static GuardPtrGetter guardContext=nullptr,guardIo=nullptr;
static GuardBoolGetter guardCapture=nullptr;
static bool guardUiOwned() { return !guardContext || !guardContext() || !guardIo || !guardCapture || guardCapture(guardIo()); }
static bool guardDown(int vk) { return (GetAsyncKeyState(vk)&0x8000)!=0; }
static LRESULT CALLBACK guardProc(HWND window,UINT message,WPARAM wParam,LPARAM lParam,UINT_PTR,DWORD_PTR) {
 bool swallow=false,remove=false;
 AcquireSRWLockExclusive(&guardLock);
 if(message==WM_NCDESTROY || message==WM_KILLFOCUS || (message==WM_ACTIVATEAPP && !wParam)) {
  guardOwnedF=false;
  if(message==WM_NCDESTROY || !guardEnabled) { remove=true; guardWindow=nullptr; }
 } else {
  bool keyDown=message==WM_KEYDOWN || message==WM_SYSKEYDOWN;
  bool keyUp=message==WM_KEYUP || message==WM_SYSKEYUP;
  if((keyDown || keyUp) && wParam=='F') {
   bool repeat=(static_cast<ULONG_PTR>(lParam)&(1ULL<<30))!=0;
   if(guardOwnedF) { swallow=true; if(keyUp) guardOwnedF=false; }
   else if(keyDown && !repeat && guardEnabled && GetForegroundWindow()==window
    && GetTickCount64()-guardHeartbeat<=500 && !guardUiOwned()
    && guardDown(VK_CONTROL) && !guardDown(VK_SHIFT) && !guardDown(VK_MENU)
    && !guardDown(VK_LWIN) && !guardDown(VK_RWIN)) { guardOwnedF=true; swallow=true; }
  }
  if(guardOwnedF && (message==WM_CHAR || message==WM_SYSCHAR || message==WM_DEADCHAR || message==WM_SYSDEADCHAR || message==WM_UNICHAR)) {
   UINT scan=(static_cast<ULONG_PTR>(lParam)>>16)&0xFF;
   if(static_cast<ULONG_PTR>(lParam)&(1ULL<<24)) scan|=0xE000;
   if(MapVirtualKeyW(scan,MAPVK_VSC_TO_VK_EX)=='F') swallow=true;
  }
  if(!guardEnabled && !guardOwnedF) { remove=true; guardWindow=nullptr; }
 }
 ReleaseSRWLockExclusive(&guardLock);
 if(remove) RemoveWindowSubclass(window,guardProc,GUARD_SUBCLASS);
 return swallow ? 0 : DefSubclassProc(window,message,wParam,lParam);
}

// 1 active, 0 disabled/inactive; -1 missing capture API, -2 wrong thread, -3 install failed.
HL_PRIM int HL_NAME(shortcut_configure)(bool enabled,bool eligible) {
 HWND window=GetForegroundWindow(); DWORD pid=0;
 DWORD thread=window ? GetWindowThreadProcessId(window,&pid) : 0;
 bool own=window && pid==GetCurrentProcessId() && !IsIconic(window);
 bool activate=enabled && eligible && own;
 if(activate && !guardWindow) {
  if(thread!=GetCurrentThreadId()) return -2;
  auto module=GetModuleHandleW(L"sfimgui.hdll");
  guardContext=module ? reinterpret_cast<GuardPtrGetter>(GetProcAddress(module,"sfimgui_igGetCurrentContext")) : nullptr;
  guardIo=module ? reinterpret_cast<GuardPtrGetter>(GetProcAddress(module,"sfimgui_igGetIO_Nil")) : nullptr;
  guardCapture=module ? reinterpret_cast<GuardBoolGetter>(GetProcAddress(module,"sfimgui_ImGuiIO_get_WantCaptureKeyboard")) : nullptr;
  if(!guardContext || !guardIo || !guardCapture) return -1;
  HMODULE pinned=nullptr;
  if(!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS|GET_MODULE_HANDLE_EX_FLAG_PIN,
   reinterpret_cast<LPCWSTR>(&guardProc),&pinned) || !SetWindowSubclass(window,guardProc,GUARD_SUBCLASS,0)) return -3;
  guardWindow=window;
 }
 AcquireSRWLockExclusive(&guardLock);
 guardEnabled=activate && window==guardWindow; guardHeartbeat=GetTickCount64();
 HWND detach=nullptr;
 if(guardWindow && !guardEnabled && !guardOwnedF && GetWindowThreadProcessId(guardWindow,nullptr)==GetCurrentThreadId()) { detach=guardWindow; guardWindow=nullptr; }
 int result=guardEnabled ? 1 : 0;
 ReleaseSRWLockExclusive(&guardLock);
 if(detach) RemoveWindowSubclass(detach,guardProc,GUARD_SUBCLASS);
 return result;
}
DEFINE_PRIM(_I32,shortcut_configure,_BOOL _BOOL);
