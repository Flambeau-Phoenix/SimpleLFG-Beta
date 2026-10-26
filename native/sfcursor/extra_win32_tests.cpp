// Compile the production wrapper with fake window/input/capture calls. No desktop input.
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
static bool capture = false, exportMissing = false, installFails = false;
static short physical[256] = {};
static ULONGLONG fakeClock = 1000;
static int forwards = 0, removes = 0, installs = 0;
static void *mockContext() { return reinterpret_cast<void*>(1); }
static void *mockIo() { return reinterpret_cast<void*>(2); }
static bool mockCapture(void*) { return capture; }
static HWND mockForeground() { return fakeWindow; }
static DWORD mockWindowThread(HWND, DWORD *pid) { if (pid) *pid = fakePid; return fakeThread; }
static DWORD mockCurrent() { return 42; }
static BOOL mockIconic(HWND) { return FALSE; }
static short mockAsync(int key) { return key > 0 && key < 256 ? physical[key] : 0; }
static HMODULE mockModule(LPCWSTR) { return reinterpret_cast<HMODULE>(1); }
static FARPROC mockExport(HMODULE, LPCSTR name) {
    if (exportMissing) return nullptr;
    if (!std::strcmp(name,"sfimgui_igGetCurrentContext")) return reinterpret_cast<FARPROC>(mockContext);
    if (!std::strcmp(name,"sfimgui_igGetIO_Nil")) return reinterpret_cast<FARPROC>(mockIo);
    if (!std::strcmp(name,"sfimgui_ImGuiIO_get_WantCaptureKeyboard")) return reinterpret_cast<FARPROC>(mockCapture);
    return nullptr;
}
static BOOL mockPin(DWORD, LPCWSTR, HMODULE *module) { *module = reinterpret_cast<HMODULE>(1); return TRUE; }
static BOOL mockInstall(HWND, SUBCLASSPROC, UINT_PTR, DWORD_PTR) { ++installs; return !installFails; }
static BOOL mockRemove(HWND, SUBCLASSPROC, UINT_PTR) { ++removes; return TRUE; }
static LRESULT mockForward(HWND,UINT,WPARAM,LPARAM) { ++forwards; return 37; }
static ULONGLONG mockClock() { return fakeClock; }
static UINT mockMap(UINT scan, UINT) { return scan; }
#define GetForegroundWindow mockForeground
#define GetWindowThreadProcessId mockWindowThread
#define GetCurrentProcessId mockCurrent
#define GetCurrentThreadId mockCurrent
#define IsIconic mockIconic
#define GetAsyncKeyState mockAsync
#define GetModuleHandleW mockModule
#define GetProcAddress mockExport
#define GetModuleHandleExW mockPin
#define SetWindowSubclass mockInstall
#define RemoveWindowSubclass mockRemove
#define DefSubclassProc mockForward
#define GetTickCount64 mockClock
#define MapVirtualKeyW mockMap
#include "extra_input.cpp"
#include "shortcut_input.cpp"
static int checks = 0;
static void check(bool value, const char *label) { ++checks; if (!value) { std::fprintf(stderr,"FAIL: %s\n",label); std::exit(1); } }
static LRESULT key(int vk, bool pressed, bool repeat=false, bool system=false) {
    physical[vk] = pressed ? static_cast<short>(0x8000) : 0;
    LPARAM bits = static_cast<LPARAM>(vk) << 16;
    if (repeat) bits |= static_cast<LPARAM>(1ULL << 30);
    return barsProc(fakeWindow, system ? (pressed ? WM_SYSKEYDOWN : WM_SYSKEYUP) : (pressed ? WM_KEYDOWN : WM_KEYUP),vk,bits,0,0);
}
static LRESULT guardKey(int vk,bool pressed,bool repeat=false) {
 physical[vk]=pressed ? static_cast<short>(0x8000) : 0;
 LPARAM bits=static_cast<LPARAM>(vk)<<16; if(repeat) bits|=static_cast<LPARAM>(1ULL<<30);
 return guardProc(fakeWindow,pressed ? WM_KEYDOWN : WM_KEYUP,vk,bits,0,0);
}
static void guardTests() {
 capture=false; exportMissing=true;
 check(sfcursor_shortcut_configure(true,true)==-1,"Guard missing capture API reported");
 exportMissing=false; fakeThread=99;
 check(sfcursor_shortcut_configure(true,true)==-2,"Guard wrong-thread install refused");
 fakeThread=42; installFails=true;
 check(sfcursor_shortcut_configure(true,true)==-3,"Guard install failure reported");
 installFails=false;
 check(sfcursor_shortcut_configure(false,true)==0 && !guardWindow,"Guard disabled by default");
 check(sfcursor_shortcut_configure(true,true)==1,"Guard independent install succeeds");
 check(guardKey('F',true)==37 && guardKey('F',false)==37,"Guard naked F unchanged");
 physical[VK_SHIFT]=static_cast<short>(0x8000);
 check(guardKey('F',true)==37 && guardKey('F',false)==37,"Guard Shift F unchanged");
 physical[VK_CONTROL]=static_cast<short>(0x8000);
 check(guardKey('F',true)==37 && guardKey('F',false)==37,"Guard Ctrl Shift F unchanged");
 physical[VK_SHIFT]=0;
 check(guardKey('F',true)==0 && guardKey('F',true,true)==0,"Guard exact Ctrl F and repeats consumed");
 check(guardProc(fakeWindow,WM_CHAR,6,static_cast<LPARAM>('F')<<16,0,0)==0,"Guard suppresses paired character");
 check(guardKey(VK_CONTROL,false)==37 && guardKey('F',false)==0,"Guard modifier release native, F release paired");
 physical[VK_CONTROL]=static_cast<short>(0x8000); capture=true;
 check(guardKey('F',true)==37 && guardKey('F',false)==37,"Guard editor-owned Ctrl F reaches UI");
 capture=false; physical[VK_MENU]=static_cast<short>(0x8000);
 check(guardKey('F',true)==37 && guardKey('F',false)==37,"Guard Ctrl Alt F unchanged");
 physical[VK_MENU]=0; physical[VK_LWIN]=static_cast<short>(0x8000);
 check(guardKey('F',true)==37 && guardKey('F',false)==37,"Guard Windows chord unchanged"); physical[VK_LWIN]=0;
 guardKey('F',true); capture=true;
 check(guardKey('F',false)==0,"Guard retains release when UI capture starts mid-chord"); capture=false;
 guardKey('F',true); check(sfcursor_shortcut_configure(false,true)==0 && guardWindow,"Guard disable defers until paired release");
 check(guardKey('F',false)==0 && !guardWindow,"Guard deferred detach pairs release");
 sfcursor_shortcut_configure(true,true); fakeClock+=501;
 check(guardKey('F',true)==37 && guardKey('F',false)==37,"Guard expired lease forwards new input");
 sfcursor_shortcut_configure(true,true); guardKey('F',true);
 guardProc(fakeWindow,WM_KILLFOCUS,0,0,0,0); check(!guardOwnedF,"Guard focus loss clears key ownership");
 physical['F']=0; physical[VK_CONTROL]=0;
 check(guardKey('F',true)==37 && guardKey('F',true,true)==37,"Guard cannot take over a naked held F after Ctrl arrives");
 physical[VK_CONTROL]=static_cast<short>(0x8000); check(guardKey('F',true,true)==37,"Guard does not consume an already-native repeat"); guardKey('F',false);
 physical[VK_CONTROL]=0;
 sfcursor_extra_configure(88,49,1,true,101); key(88,true);
 check(sfcursor_shortcut_configure(true,true)==1 && key(49,true)==0 && sfcursor_extra_take(101)==1,"Guard coexists with ExtraBars without changing routing");
 key(49,false); key(88,false); sfcursor_extra_shutdown();
 sfcursor_shortcut_configure(false,false); check(!guardWindow,"Guard clean shutdown detaches");
}
int main() {
    fakeThread = 99;
    check(sfcursor_extra_configure(88,49,1,true,1) == -2 && installs == 0,"Wrong-thread install fails closed");
    fakeThread = 42; exportMissing = true;
    check(sfcursor_extra_configure(88,49,1,true,1) == -1 && installs == 0,"Missing capture API fails closed");
    exportMissing = false; installFails = true;
    check(sfcursor_extra_configure(88,49,1,true,1) == -3,"Subclass installation failure reported");
    installFails = false;
    check(sfcursor_extra_configure(88,49,1,true,1) == 0,"Own foreground window installs with native page");
    check(key(49,true) == 37 && key(49,false) == 37,"Naked down/up forwarded immediately");
    check(key(88,true) == 37 && key(49,true) == 0,"Hold prefix forwarded, exact key consumed");
    check(barsProc(fakeWindow,WM_CHAR,'1',static_cast<LPARAM>(49) << 16,0,0) == 0,"Owned character is also consumed");
    check(key(49,true,true) == 0 && sfcursor_extra_take(1) == 1 && sfcursor_extra_take(1) == 0,"Repeat suppressed and one request polled");
    check(key(88,false) == 37 && key(49,false) == 0,"Prefix release and paired bar release route correctly");
    check(key(49,true) == 37 && key(49,false) == 37,"Native restored for next naked press");
    capture = true;
    key(88,true); key(49,true);
    check(sfcursor_extra_take(1) == 0,"UI capture creates no request");
    check(key(49,false) == 37 && key(88,false) == 37,"UI-owned events stay in SFImGui chain");
    capture = false;
    sfcursor_extra_configure(88,49,2,true,2);
    key(88,true); key(88,false);
    check(sfcursor_extra_status() & 1,"Native Toggle state entered");
    check(key(49,true) == 0,"Toggle key filtered before native chain");
    capture = true;
    check(key(49,false) == 0 && sfcursor_extra_take(2) == 0,"Capture mid-press cancels queue and pairs release");
    capture = false;
    sfcursor_extra_configure(88,49,2,true,2);
    key(88,true); key(88,false);
    physical[VK_MENU] = static_cast<short>(0x8000);
    check(key(49,true,false,true) == 37 && key(49,false,false,true) == 37,"Alt system messages remain native");
    physical[VK_MENU] = 0;
    fakeClock += 501;
    check(key(49,true) == 37 && sfcursor_extra_take(2) == 0,"Expired gameplay lease cancels suppression");
    key(49,false);
    sfcursor_extra_configure(88,49,2,true,2);
    key(88,true); key(88,false); key(49,true);
    check(!sfcursor_extra_shutdown(),"Shutdown defers detach until owned release");
    check(key(49,false) == 0 && removes == 1 && !barsWindow,"Deferred shutdown pairs release then removes subclass");
    sfcursor_extra_configure(88,49,2,true,3);
    key(88,true); key(88,false); key(49,true);
    barsProc(fakeWindow,WM_KILLFOCUS,0,0,0,0);
    check(!bars.hasBlocked() && !sfcursor_extra_take(3),"Focus loss clears pending key ownership");
    physical[49] = 0;
    check(sfcursor_extra_shutdown() && removes == 2,"Clean shutdown detaches immediately");
    sfcursor_extra_configure(88,49,2,true,4);
    barsProc(fakeWindow,WM_NCDESTROY,0,0,0,0);
    check(!barsWindow && removes == 3,"Destroy removes callback before window disappears");
    check(sfcursor_extra_configure_many(88,2,true,20,nullptr,1024)==-4, "Null routing ABI buffer rejected");
    int table[256] = {}; table[49]=7; table[50]=19;
    auto bytes = reinterpret_cast<vbyte*>(table);
    check(sfcursor_extra_configure_many(88,2,true,20,bytes,1023)==-4, "Wrong routing ABI length rejected");
    check(sfcursor_extra_configure_many(88,2,true,20,bytes,1024)==0, "Multi-cell ABI accepts bounded aligned copy");
    check(key(50,true)==37 && key(50,false)==37, "Multi-cell naked events remain immediate native");
    key(88,true); key(88,false);
    check(key(49,true)==0 && key(50,true)==0, "Two exact active keys consumed");
    check(sfcursor_extra_take(20)==7 && sfcursor_extra_take(20)==19 && sfcursor_extra_take(20)==0, "Native wrapper returns actual slot tokens once in order");
    check(key(49,false)==0 && key(50,false)==0, "Multi-cell up ownership paired");
    key(88,true); key(88,false);
    check(key(49,true)==37 && key(49,false)==37 && key(50,true)==37 && key(50,false)==37, "Toggle off restores all naked keys");
    key(88,true); key(88,false); key(49,true);
    check(sfcursor_extra_configure_many(88,2,true,20,bytes,0)==-4 && sfcursor_extra_take(20)==0, "Malformed table cancels queued use");
    check(key(49,false)==0, "Malformed configuration preserves owned release");
    check(sfcursor_extra_shutdown(), "Multi-cell wrapper cleanly detaches");
    check(sfcursor_extra_configure_many(0,3,true,30,bytes,1024)==1,"Always Active native ABI arms without modifier");
    check(key(49,true)==0 && key(49,true,true)==0,"Always consumes mapped press and repeats");
    check(sfcursor_extra_take(30)==7 && sfcursor_extra_take(30)==0,"Always emits exactly one slot token");
    capture=true;
    check(key(49,false)==0,"Always capture transition pairs owned release");
    check(key(50,true)==37 && key(50,false)==37,"Always forwards UI-owned input");
    capture=false; sfcursor_extra_configure_many(0,3,true,30,bytes,1024);
    physical[VK_CONTROL]=static_cast<short>(0x8000);
    check(key(49,true)==37 && key(49,false)==37,"Always Ctrl shortcut native");
    physical[VK_CONTROL]=0;
    check(key(49,true)==0,"Always resumes plain mapping");
    sfcursor_extra_configure_many(0,3,true,31,bytes,1024);
    check(sfcursor_extra_take(30)==0 && !(sfcursor_extra_status() & 1),"Generation switch while held requires release");
    check(key(49,false)==0,"Old generation still owns paired release");
    check(sfcursor_extra_configure_many(0,3,true,31,bytes,1024)==1,"New generation rearms after release");
    fakeClock+=501;
    check(key(49,true)==37 && sfcursor_extra_take(31)==0,"Always expired heartbeat forwards key and clears queue"); key(49,false);
    sfcursor_extra_configure_many(0,3,true,31,bytes,1024);
    check(sfcursor_extra_shutdown(),"Always clean shutdown");
    guardTests();
    std::printf("ExtraBars Win32 wrapper: %d checks PASS (mocked calls only)\n",checks);
}
