package imgui;

import imgui.Structs.ImVec2;
import imgui.Structs.ImVec4;
import imgui.ref.BoolRef;
import imgui.ref.DoubleRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;
import imgui.ImGuiFrame;

// Same type names/strings as shader-cache/src/sc/native/Native.hx's Device/Resource - a value a
// consuming mod already obtained from dx12.hdll's own natives (e.g. `@:hlNative("dx12",
// "get_device")`) passes straight into these with no Dynamic boxing/unboxing, because it's a
// genuine native-to-native handoff on both ends (see shader-cache/NATIVE.md's abs_name-by-pointer
// cross-module cast pitfall - that only bites values routed through Dynamic/Reflect).
typedef Device = hl.Abstract<"dx_device">;
typedef Resource = hl.Abstract<"dx_resource">;
typedef Window = hl.Abstract<"dx_window">;

// >>> GENERATED TYPEDEFS by native/codegen/generate.mts below - do not hand-edit, re-run the generator instead. >>>
typedef ImColor = hl.Abstract<"ImColor">;
typedef ImDrawCmd = hl.Abstract<"ImDrawCmd">;
typedef ImDrawData = hl.Abstract<"ImDrawData">;
typedef ImDrawList = hl.Abstract<"ImDrawList">;
typedef ImDrawListSharedData = hl.Abstract<"ImDrawListSharedData">;
typedef ImDrawListSplitter = hl.Abstract<"ImDrawListSplitter">;
typedef ImFont = hl.Abstract<"ImFont">;
typedef ImFontAtlas = hl.Abstract<"ImFontAtlas">;
typedef ImFontAtlasRect = hl.Abstract<"ImFontAtlasRect">;
typedef ImFontBaked = hl.Abstract<"ImFontBaked">;
typedef ImFontConfig = hl.Abstract<"ImFontConfig">;
typedef ImFontGlyph = hl.Abstract<"ImFontGlyph">;
typedef ImFontGlyphRangesBuilder = hl.Abstract<"ImFontGlyphRangesBuilder">;
typedef ImFontLoader = hl.Abstract<"ImFontLoader">;
typedef ImGuiContext = hl.Abstract<"ImGuiContext">;
typedef ImGuiIO = hl.Abstract<"ImGuiIO">;
typedef ImGuiInputTextCallbackData = hl.Abstract<"ImGuiInputTextCallbackData">;
typedef ImGuiListClipper = hl.Abstract<"ImGuiListClipper">;
typedef ImGuiPayload = hl.Abstract<"ImGuiPayload">;
typedef ImGuiPlatformIO = hl.Abstract<"ImGuiPlatformIO">;
typedef ImGuiSelectionBasicStorage = hl.Abstract<"ImGuiSelectionBasicStorage">;
typedef ImGuiSelectionExternalStorage = hl.Abstract<"ImGuiSelectionExternalStorage">;
typedef ImGuiStyle = hl.Abstract<"ImGuiStyle">;
typedef ImGuiTableSortSpecs = hl.Abstract<"ImGuiTableSortSpecs">;
typedef ImGuiTextBuffer = hl.Abstract<"ImGuiTextBuffer">;
typedef ImGuiTextFilter = hl.Abstract<"ImGuiTextFilter">;
typedef ImGuiViewport = hl.Abstract<"ImGuiViewport">;
typedef ImTextureData = hl.Abstract<"ImTextureData">;
typedef ImTextureRef = hl.Abstract<"ImTextureRef">;
// <<< END GENERATED TYPEDEFS <<<

abstract ImGui(Void) {
	// -- lifecycle (imgui_native.cpp) --------------------------------------------------------

	@:hlNative("dx12", "get_device")
	static function dx12GetDevice():Device {
		return null;
	}

	public static inline var DEFAULT_RTV_FORMAT_R8G8B8A8_UNORM = 28;

	// The only one of these that can't just be @:hlNative directly: the real native call takes
	// `device` as its first argument (computed here via dx12GetDevice(), not something a caller
	// supplies), so this function's own signature genuinely doesn't match the native ABI - unlike
	// initWin32/shutdown/newFrame/render/renderDrawData below, which forward every argument as-is
	// and so need no separate raw binding at all.
	@:hlNative("sfimgui", "init")
	static function init_(device:Device, numFramesInFlight:Int, rtvFormat:Int):Void {}

	public static inline function init(numFramesInFlight:Int, rtvFormat:Int = DEFAULT_RTV_FORMAT_R8G8B8A8_UNORM):Void
		init_(dx12GetDevice(), numFramesInFlight, rtvFormat);

	@:hlNative("sfimgui", "init_win32")
	public static function initWin32(hwnd:Window):Void {}

	@:hlNative("sfimgui", "shutdown")
	public static function shutdown():Void {}

	@:hlNative("sfimgui", "new_frame")
	public static function newFrame():Void {}

	@:hlNative("sfimgui", "render")
	public static function render():Void {}

	@:hlNative("sfimgui", "render_draw_data")
	public static function renderDrawData(commandList:Resource):Void {}

	// Native-owned cross-mod panel registry + idempotent per-real-frame NewFrame/Render, backing
	// imgui.ImGuiFrame's @:hlx.prefix(h3d.impl.DX12Driver.present) hook - see that class's own doc
	// comment for why this needs to live in native code rather than any one mod's Haxe statics
	// (every consuming mod compiles its own private copy of ImGuiFrame into its own HL module).
	@:hlNative("sfimgui", "run_frame")
	public static function runFrame(commandList:Resource):Void {}

	// draw is typically a panel instance method reference (e.g. `panel.draw`, a bound Void->Void
	// closure) - kept alive process-wide by the native side (imgui_native.cpp roots it via
	// hl_add_root) until a matching unregister(name) call.
	@:hlNative("sfimgui", "register")
	static function register_(name:hl.Bytes, draw:Void->Void):Void {}

	public static inline function register(name:String, draw:Void->Void):Void {
		ImGuiFrame.ensureRegistered();
		register_(cstr(name), draw);
	}

	@:hlNative("sfimgui", "unregister")
	static function unregister_(name:hl.Bytes):Void {}

	public static inline function unregister(name:String):Void
		unregister_(cstr(name));

	// -- textures (imgui_native.cpp's register_texture/image) -----------------------------------
	//
	// Hand-written, not generated: ImGui::Image()'s real signature takes a by-value ImTextureRef
	// struct, which the generator's type resolver can't marshal (native/codegen/generate.mts's
	// resolveBase, by-value-nonPOD-struct guard).

	// pixels must already be RGBA8, row-major, with row pitch srcRowPitch (may exceed width * 4 -
	// e.g. hxd.Pixels.stride can include row padding). Uploads to the GPU and waits synchronously,
	// so callers should register once per distinct image and cache the returned handle (e.g. keyed
	// by source file) rather than re-registering every frame. Identical pixel content is
	// deduplicated natively (by content hash), even across different mods' own private caches, so
	// redundant registrations of the same asset are cheap rather than each costing a fresh upload.
	@:hlNative("sfimgui", "register_texture")
	public static function registerTexture(pixels:hl.Bytes, width:Int, height:Int, srcRowPitch:Int):hl.I64 {
		return 0;
	}

	@:hlNative("sfimgui", "image")
	private static function image_(texId:hl.I64, w:Single, h:Single, u0:Single, v0:Single, u1:Single, v1:Single):Void {}

	// texId is a handle returned by registerTexture() above. uv0/uv1 default to ImGui::Image()'s
	// own defaults (the whole texture) - pass a sub-rect's own UVs to draw one region out of a
	// shared texture instead (e.g. one icon from a spritesheet).
	public static inline function image(texId:hl.I64, size:Vec2, ?uv0:Vec2, ?uv1:Vec2):Void {
		var a = uv0 == null ? vec2(0, 0) : uv0;
		var b = uv1 == null ? vec2(1, 1) : uv1;
		image_(texId, size.x, size.y, a.x, a.y, b.x, b.y);
	}

	// -- text -----------------------------------------------------------------------------------

	// Deliberate short alias distinct from the auto-generated textUnformatted() (see generate.mts's
	// compileDispatcher) - ImGui's real Text() is variadic (C `...`), which has no safe HL/Haxe
	// marshaling, so this is the closest equivalent and the one most callers reach for by name.
	public static inline function text(text:String):Void
		textUnformatted(text);

	// -- table sorting ------------------------------------------------------------------------
	//
	// Hand-written, not generated: tableGetSortSpecs() (below, in the generated block) returns
	// the real cimgui-bound ImGuiTableSortSpecs* - but its Specs/SpecsCount/SpecsDirty are plain
	// struct fields, not cimgui functions, so the generator (which only binds cimgui's flat
	// function list) has nothing to bind for reading them. imgui_native.cpp's
	// ImGuiTableSortSpecs_* glue fills that gap.

	@:hlNative("sfimgui", "ImGuiTableSortSpecs_GetSpecsCount")
	private static function _tableSortSpecsGetSpecsCount(specs:ImGuiTableSortSpecs):Int {
		return 0;
	}

	public static inline function tableSortSpecsGetSpecsCount(specs:ImGuiTableSortSpecs):Int
		return _tableSortSpecsGetSpecsCount(specs);

	@:hlNative("sfimgui", "ImGuiTableSortSpecs_GetSpecsDirty")
	private static function _tableSortSpecsGetSpecsDirty(specs:ImGuiTableSortSpecs):Bool {
		return false;
	}

	public static inline function tableSortSpecsGetSpecsDirty(specs:ImGuiTableSortSpecs):Bool
		return _tableSortSpecsGetSpecsDirty(specs);

	@:hlNative("sfimgui", "ImGuiTableSortSpecs_SetSpecsDirty")
	private static function _tableSortSpecsSetSpecsDirty(specs:ImGuiTableSortSpecs, dirty:Bool):Void {}

	public static inline function tableSortSpecsSetSpecsDirty(specs:ImGuiTableSortSpecs, dirty:Bool):Void
		_tableSortSpecsSetSpecsDirty(specs, dirty);

	// Column index into the table (matching tableSetupColumn() submission order), as declared by
	// ImGuiTableColumnSortSpecs::ColumnIndex - not the same thing as a user-assigned sort ID.
	@:hlNative("sfimgui", "ImGuiTableSortSpecs_GetColumnIndex")
	private static function _tableSortSpecsGetColumnIndex(specs:ImGuiTableSortSpecs, i:Int):Int {
		return -1;
	}

	public static inline function tableSortSpecsGetColumnIndex(specs:ImGuiTableSortSpecs, i:Int):Int
		return _tableSortSpecsGetColumnIndex(specs, i);

	// ImGuiSortDirection value (None/Ascending/Descending, see imgui.Enums.ImGuiSortDirection).
	@:hlNative("sfimgui", "ImGuiTableSortSpecs_GetSortDirection")
	private static function _tableSortSpecsGetSortDirection(specs:ImGuiTableSortSpecs, i:Int):Int {
		return 0;
	}

	public static inline function tableSortSpecsGetSortDirection(specs:ImGuiTableSortSpecs, i:Int):Int
		return _tableSortSpecsGetSortDirection(specs, i);

	// -- input text completion --------------------------------------------------------------------
	//
	// Hand-written, not generated: the generated igInputText (below) has no way to express a real
	// C callback/user_data pair, so its own binding hardcodes both to NULL - Tab-driven
	// ImGuiInputTextFlags.CallbackCompletion can never fire through it. This variant plugs a real
	// native callback in (imgui_native.cpp's InputTextCompletionTrampoline) that re-enters this
	// closure - flags does not need CallbackCompletion set, the native side already ORs it in.
	//
	// onCompletion is a plain Void->Void closure (not one taking/returning the real
	// ImGuiInputTextCallbackData*) - hand the text to complete to via setCompletionText() from
	// inside it instead; see imgui_native.cpp's own comment for why.

	@:hlNative("sfimgui", "setCompletionText")
	private static function _setCompletionText(text:hl.Bytes):Void {}

	public static inline function setCompletionText(text:String):Void
		_setCompletionText(cstr(text));

	@:hlNative("sfimgui", "inputTextWithCompletion")
	private static function _inputTextWithCompletion(label:hl.Bytes, buf:hl.Bytes, buf_size:hl.I64, flags:Int, onCompletion:Void->Void):Bool {
		return false;
	}

	public static inline function inputTextWithCompletion(label:String, buf:hl.Bytes, bufSize:hl.I64, flags:Int, onCompletion:Void->Void):Bool
		return _inputTextWithCompletion(cstr(label), buf, bufSize, flags, onCompletion);

	// -- list clipper (imgui_native.cpp) ------------------------------------------------------
	//
	// Hand-written, not generated: ImGuiListClipper's constructor/destructor are placement-new
	// (IM_NEW/IM_DELETE) like every other stateful cimgui type, so generate.mts's constructor
	// exclusion skips them same as it does for ImGuiTextFilter/ImDrawListSplitter/etc - only this
	// type actually needs a Haxe-constructible instance, since Begin/End/Step/etc (below, in the
	// generated block) all take one as `self` with nothing anywhere producing one otherwise.
	// DisplayStart/DisplayEnd/ItemsCount are plain struct fields (not cimgui functions), so they
	// need the same kind of hand-written getter as ImGuiTableSortSpecs_GetSpecsCount above.
	//
	// Usage: `var c = ImGui.ImGuiListClipper_ImGuiListClipper(); ImGui.ImGuiListClipper_Begin(c,
	// count); while (ImGui.ImGuiListClipper_Step(c)) for (i in ImGui.ImGuiListClipper_get_DisplayStart(c)
	// ...ImGui.ImGuiListClipper_get_DisplayEnd(c)) {...} ImGui.ImGuiListClipper_destroy(c);` - same
	// free-function-with-explicit-self shape every other ImGuiListClipper_* method (below, in the
	// generated block) already uses. The caller owns the instance and must call destroy() exactly
	// once when done, typically right after the Begin/Step loop.

	@:hlNative("sfimgui", "ImGuiListClipper_ImGuiListClipper")
	public static function ImGuiListClipper_ImGuiListClipper():ImGuiListClipper {
		return null;
	}

	@:hlNative("sfimgui", "ImGuiListClipper_destroy")
	public static function ImGuiListClipper_destroy(self:ImGuiListClipper):Void {}

	@:hlNative("sfimgui", "ImGuiListClipper_get_DisplayStart")
	public static function ImGuiListClipper_get_DisplayStart(self:ImGuiListClipper):Int {
		return 0;
	}

	@:hlNative("sfimgui", "ImGuiListClipper_get_DisplayEnd")
	public static function ImGuiListClipper_get_DisplayEnd(self:ImGuiListClipper):Int {
		return 0;
	}

	@:hlNative("sfimgui", "ImGuiListClipper_get_ItemsCount")
	public static function ImGuiListClipper_get_ItemsCount(self:ImGuiListClipper):Int {
		return 0;
	}

	@:hlNative("sfimgui", "ImGuiIO_get_WantCaptureMouse")
	public static function ImGuiIO_get_WantCaptureMouse(self:ImGuiIO):Bool {
		return false;
	}

	@:hlNative("sfimgui", "ImGuiIO_get_WantCaptureKeyboard")
	public static function ImGuiIO_get_WantCaptureKeyboard(self:ImGuiIO):Bool {
		return false;
	}

	// -- docking -------------------------------------------------------------------------------

	@:hlNative("sfimgui", "dockSpace")
	private static function _dockSpace(id:Int, size:ImVec2, flags:Int):Int {
		return 0;
	}

	public static inline function dockSpace(id:Int, size:ImVec2 = null, flags:Int = 0):Int {
		size = size ?? vec2(0, 0);
		return _dockSpace(id, size, flags);
	}

	@:hlNative("sfimgui", "dockSpaceOverViewport")
	private static function _dockSpaceOverViewport(viewport:ImGuiViewport, flags:Int):Int {
		return 0;
	}

	public static inline function dockSpaceOverViewport(viewport:ImGuiViewport = null, flags:Int = 0):Int {
		return _dockSpaceOverViewport(viewport, flags);
	}

	@:hlNative("sfimgui", "setNextWindowDockID")
	private static function _setNextWindowDockID(dock_id:Int, cond:Int):Void {}

	public static inline function setNextWindowDockID(dockId:Int, cond:Int = 0):Void {
		_setNextWindowDockID(dockId, cond);
	}

	@:hlNative("sfimgui", "getWindowDockID")
	private static function _getWindowDockID():Int {
		return 0;
	}

	public static inline function getWindowDockID():Int {
		return _getWindowDockID();
	}

	@:hlNative("sfimgui", "isWindowDocked")
	private static function _isWindowDocked():Bool {
		return false;
	}

	public static inline function isWindowDocked():Bool {
		return _isWindowDocked();
	}

	// -- drag & drop payload accessors ---------------------------------------------------------

	@:hlNative("sfimgui", "setDragDropPayload")
	private static function _setDragDropPayload(type:hl.Bytes, data:hl.Bytes, sz:Int, cond:Int):Bool {
		return false;
	}

	public static inline function setDragDropPayload(type:String, data:hl.Bytes, sz:Int, cond:Int = 0):Bool {
		return _setDragDropPayload(cstr(type), data, sz, cond);
	}

	@:hlNative("sfimgui", "getPayloadData")
	private static function _getPayloadData(payload:ImGuiPayload):hl.Bytes {
		return null;
	}

	public static inline function getPayloadData(payload:ImGuiPayload):hl.Bytes {
		return _getPayloadData(payload);
	}

	@:hlNative("sfimgui", "getPayloadDataSize")
	private static function _getPayloadDataSize(payload:ImGuiPayload):Int {
		return 0;
	}

	public static inline function getPayloadDataSize(payload:ImGuiPayload):Int {
		return _getPayloadDataSize(payload);
	}

	@:hlNative("sfimgui", "setKeyboardBlock")
	private static function _setKeyboardBlock(block:Bool):Void {}

	/**
	 * Keep keystrokes from reaching the host game's WndProc while a tool owns the keyboard.
	 * An active InputText is already covered by io.WantTextInput; this is for window-level
	 * ownership. Held keys are released to the game correctly when this turns back off.
	 */
	public static inline function setKeyboardBlock(block:Bool):Void {
		_setKeyboardBlock(block);
	}

	@:hlNative("sfimgui", "clearInput")
	private static function _clearInput():Void {}

	/** Release every key/button ImGui thinks is held - call when the game reclaims the cursor. */
	public static inline function clearInput():Void {
		_clearInput();
	}

	// >>> GENERATED by native/codegen/generate.mts below this point - do not hand-edit, re-run the generator instead. >>>
	@:hlNative("sfimgui", "ImColor_SetHSV")
	private static function _ImColor_SetHSV(self:ImColor, h:Single, s:Single, v:Single, a:Single):Void {
	}

	public static inline function ImColor_SetHSV(self:ImColor, h:Single, s:Single, v:Single, a:Single = 1.0):Void
		_ImColor_SetHSV(self, h, s, v, a);

	@:hlNative("sfimgui", "ImDrawCmd_GetTexID")
	private static function _ImDrawCmd_GetTexID(self:ImDrawCmd):hl.I64 {
		return 0;
	}

	public static inline function ImDrawCmd_GetTexID(self:ImDrawCmd):hl.I64
		return _ImDrawCmd_GetTexID(self);

	@:hlNative("sfimgui", "ImDrawData_AddDrawList")
	private static function _ImDrawData_AddDrawList(self:ImDrawData, draw_list:ImDrawList):Void {
	}

	public static inline function ImDrawData_AddDrawList(self:ImDrawData, drawList:ImDrawList):Void
		_ImDrawData_AddDrawList(self, drawList);

	@:hlNative("sfimgui", "ImDrawData_Clear")
	private static function _ImDrawData_Clear(self:ImDrawData):Void {
	}

	public static inline function ImDrawData_Clear(self:ImDrawData):Void
		_ImDrawData_Clear(self);

	@:hlNative("sfimgui", "ImDrawData_DeIndexAllBuffers")
	private static function _ImDrawData_DeIndexAllBuffers(self:ImDrawData):Void {
	}

	public static inline function ImDrawData_DeIndexAllBuffers(self:ImDrawData):Void
		_ImDrawData_DeIndexAllBuffers(self);

	@:hlNative("sfimgui", "ImDrawData_ScaleClipRects")
	private static function _ImDrawData_ScaleClipRects(self:ImDrawData, fb_scale:ImVec2):Void {
	}

	public static inline function ImDrawData_ScaleClipRects(self:ImDrawData, fbScale:ImVec2):Void
		_ImDrawData_ScaleClipRects(self, fbScale);

	@:hlNative("sfimgui", "ImDrawListSplitter_Clear")
	private static function _ImDrawListSplitter_Clear(self:ImDrawListSplitter):Void {
	}

	public static inline function ImDrawListSplitter_Clear(self:ImDrawListSplitter):Void
		_ImDrawListSplitter_Clear(self);

	@:hlNative("sfimgui", "ImDrawListSplitter_ClearFreeMemory")
	private static function _ImDrawListSplitter_ClearFreeMemory(self:ImDrawListSplitter):Void {
	}

	public static inline function ImDrawListSplitter_ClearFreeMemory(self:ImDrawListSplitter):Void
		_ImDrawListSplitter_ClearFreeMemory(self);

	@:hlNative("sfimgui", "ImDrawListSplitter_Merge")
	private static function _ImDrawListSplitter_Merge(self:ImDrawListSplitter, draw_list:ImDrawList):Void {
	}

	public static inline function ImDrawListSplitter_Merge(self:ImDrawListSplitter, drawList:ImDrawList):Void
		_ImDrawListSplitter_Merge(self, drawList);

	@:hlNative("sfimgui", "ImDrawListSplitter_SetCurrentChannel")
	private static function _ImDrawListSplitter_SetCurrentChannel(self:ImDrawListSplitter, draw_list:ImDrawList, channel_idx:Int):Void {
	}

	public static inline function ImDrawListSplitter_SetCurrentChannel(self:ImDrawListSplitter, drawList:ImDrawList, channelIdx:Int):Void
		_ImDrawListSplitter_SetCurrentChannel(self, drawList, channelIdx);

	@:hlNative("sfimgui", "ImDrawListSplitter_Split")
	private static function _ImDrawListSplitter_Split(self:ImDrawListSplitter, draw_list:ImDrawList, count:Int):Void {
	}

	public static inline function ImDrawListSplitter_Split(self:ImDrawListSplitter, drawList:ImDrawList, count:Int):Void
		_ImDrawListSplitter_Split(self, drawList, count);

	@:hlNative("sfimgui", "ImDrawList_AddBezierCubic")
	private static function _ImDrawList_AddBezierCubic(self:ImDrawList, p1:ImVec2, p2:ImVec2, p3:ImVec2, p4:ImVec2, col:Int, thickness:Single, num_segments:Int):Void {
	}

	public static inline function ImDrawList_AddBezierCubic(self:ImDrawList, p1:ImVec2, p2:ImVec2, p3:ImVec2, p4:ImVec2, col:Int, thickness:Single, numSegments:Int = 0):Void
		_ImDrawList_AddBezierCubic(self, p1, p2, p3, p4, col, thickness, numSegments);

	@:hlNative("sfimgui", "ImDrawList_AddBezierQuadratic")
	private static function _ImDrawList_AddBezierQuadratic(self:ImDrawList, p1:ImVec2, p2:ImVec2, p3:ImVec2, col:Int, thickness:Single, num_segments:Int):Void {
	}

	public static inline function ImDrawList_AddBezierQuadratic(self:ImDrawList, p1:ImVec2, p2:ImVec2, p3:ImVec2, col:Int, thickness:Single, numSegments:Int = 0):Void
		_ImDrawList_AddBezierQuadratic(self, p1, p2, p3, col, thickness, numSegments);

	@:hlNative("sfimgui", "ImDrawList_AddCircle")
	private static function _ImDrawList_AddCircle(self:ImDrawList, center:ImVec2, radius:Single, col:Int, num_segments:Int, thickness:Single):Void {
	}

	public static inline function ImDrawList_AddCircle(self:ImDrawList, center:ImVec2, radius:Single, col:Int, numSegments:Int = 0, thickness:Single = 1.0):Void
		_ImDrawList_AddCircle(self, center, radius, col, numSegments, thickness);

	@:hlNative("sfimgui", "ImDrawList_AddCircleFilled")
	private static function _ImDrawList_AddCircleFilled(self:ImDrawList, center:ImVec2, radius:Single, col:Int, num_segments:Int):Void {
	}

	public static inline function ImDrawList_AddCircleFilled(self:ImDrawList, center:ImVec2, radius:Single, col:Int, numSegments:Int = 0):Void
		_ImDrawList_AddCircleFilled(self, center, radius, col, numSegments);

	@:hlNative("sfimgui", "ImDrawList_AddConcavePolyFilled")
	private static function _ImDrawList_AddConcavePolyFilled(self:ImDrawList, points:hl.Bytes, num_points:Int, col:Int):Void {
	}

	public static inline function ImDrawList_AddConcavePolyFilled(self:ImDrawList, points:hl.Bytes, numPoints:Int, col:Int):Void
		_ImDrawList_AddConcavePolyFilled(self, points, numPoints, col);

	@:hlNative("sfimgui", "ImDrawList_AddConvexPolyFilled")
	private static function _ImDrawList_AddConvexPolyFilled(self:ImDrawList, points:hl.Bytes, num_points:Int, col:Int):Void {
	}

	public static inline function ImDrawList_AddConvexPolyFilled(self:ImDrawList, points:hl.Bytes, numPoints:Int, col:Int):Void
		_ImDrawList_AddConvexPolyFilled(self, points, numPoints, col);

	@:hlNative("sfimgui", "ImDrawList_AddDrawCmd")
	private static function _ImDrawList_AddDrawCmd(self:ImDrawList):Void {
	}

	public static inline function ImDrawList_AddDrawCmd(self:ImDrawList):Void
		_ImDrawList_AddDrawCmd(self);

	@:hlNative("sfimgui", "ImDrawList_AddEllipse")
	private static function _ImDrawList_AddEllipse(self:ImDrawList, center:ImVec2, radius:ImVec2, col:Int, rot:Single, num_segments:Int, thickness:Single):Void {
	}

	public static inline function ImDrawList_AddEllipse(self:ImDrawList, center:ImVec2, radius:ImVec2, col:Int, rot:Single = 0.0, numSegments:Int = 0, thickness:Single = 1.0):Void
		_ImDrawList_AddEllipse(self, center, radius, col, rot, numSegments, thickness);

	@:hlNative("sfimgui", "ImDrawList_AddEllipseFilled")
	private static function _ImDrawList_AddEllipseFilled(self:ImDrawList, center:ImVec2, radius:ImVec2, col:Int, rot:Single, num_segments:Int):Void {
	}

	public static inline function ImDrawList_AddEllipseFilled(self:ImDrawList, center:ImVec2, radius:ImVec2, col:Int, rot:Single = 0.0, numSegments:Int = 0):Void
		_ImDrawList_AddEllipseFilled(self, center, radius, col, rot, numSegments);

	@:hlNative("sfimgui", "ImDrawList_AddLine")
	private static function _ImDrawList_AddLine(self:ImDrawList, p1:ImVec2, p2:ImVec2, col:Int, thickness:Single):Void {
	}

	public static inline function ImDrawList_AddLine(self:ImDrawList, p1:ImVec2, p2:ImVec2, col:Int, thickness:Single = 1.0):Void
		_ImDrawList_AddLine(self, p1, p2, col, thickness);

	@:hlNative("sfimgui", "ImDrawList_AddLineH")
	private static function _ImDrawList_AddLineH(self:ImDrawList, min_x:Single, max_x:Single, y:Single, col:Int, thickness:Single):Void {
	}

	public static inline function ImDrawList_AddLineH(self:ImDrawList, minX:Single, maxX:Single, y:Single, col:Int, thickness:Single = 1.0):Void
		_ImDrawList_AddLineH(self, minX, maxX, y, col, thickness);

	@:hlNative("sfimgui", "ImDrawList_AddLineV")
	private static function _ImDrawList_AddLineV(self:ImDrawList, x:Single, min_y:Single, max_y:Single, col:Int, thickness:Single):Void {
	}

	public static inline function ImDrawList_AddLineV(self:ImDrawList, x:Single, minY:Single, maxY:Single, col:Int, thickness:Single = 1.0):Void
		_ImDrawList_AddLineV(self, x, minY, maxY, col, thickness);

	@:hlNative("sfimgui", "ImDrawList_AddNgon")
	private static function _ImDrawList_AddNgon(self:ImDrawList, center:ImVec2, radius:Single, col:Int, num_segments:Int, thickness:Single):Void {
	}

	public static inline function ImDrawList_AddNgon(self:ImDrawList, center:ImVec2, radius:Single, col:Int, numSegments:Int, thickness:Single = 1.0):Void
		_ImDrawList_AddNgon(self, center, radius, col, numSegments, thickness);

	@:hlNative("sfimgui", "ImDrawList_AddNgonFilled")
	private static function _ImDrawList_AddNgonFilled(self:ImDrawList, center:ImVec2, radius:Single, col:Int, num_segments:Int):Void {
	}

	public static inline function ImDrawList_AddNgonFilled(self:ImDrawList, center:ImVec2, radius:Single, col:Int, numSegments:Int):Void
		_ImDrawList_AddNgonFilled(self, center, radius, col, numSegments);

	@:hlNative("sfimgui", "ImDrawList_AddPolyline")
	private static function _ImDrawList_AddPolyline(self:ImDrawList, points:hl.Bytes, num_points:Int, col:Int, thickness:Single, flags:Int):Void {
	}

	public static inline function ImDrawList_AddPolyline(self:ImDrawList, points:hl.Bytes, numPoints:Int, col:Int, thickness:Single, flags:Int = 0):Void
		_ImDrawList_AddPolyline(self, points, numPoints, col, thickness, flags);

	@:hlNative("sfimgui", "ImDrawList_AddQuad")
	private static function _ImDrawList_AddQuad(self:ImDrawList, p1:ImVec2, p2:ImVec2, p3:ImVec2, p4:ImVec2, col:Int, thickness:Single):Void {
	}

	public static inline function ImDrawList_AddQuad(self:ImDrawList, p1:ImVec2, p2:ImVec2, p3:ImVec2, p4:ImVec2, col:Int, thickness:Single = 1.0):Void
		_ImDrawList_AddQuad(self, p1, p2, p3, p4, col, thickness);

	@:hlNative("sfimgui", "ImDrawList_AddQuadFilled")
	private static function _ImDrawList_AddQuadFilled(self:ImDrawList, p1:ImVec2, p2:ImVec2, p3:ImVec2, p4:ImVec2, col:Int):Void {
	}

	public static inline function ImDrawList_AddQuadFilled(self:ImDrawList, p1:ImVec2, p2:ImVec2, p3:ImVec2, p4:ImVec2, col:Int):Void
		_ImDrawList_AddQuadFilled(self, p1, p2, p3, p4, col);

	@:hlNative("sfimgui", "ImDrawList_AddRect")
	private static function _ImDrawList_AddRect(self:ImDrawList, p_min:ImVec2, p_max:ImVec2, col:Int, rounding:Single, thickness:Single, flags:Int):Void {
	}

	public static inline function ImDrawList_AddRect(self:ImDrawList, pMin:ImVec2, pMax:ImVec2, col:Int, rounding:Single = 0.0, thickness:Single = 1.0, flags:Int = 0):Void
		_ImDrawList_AddRect(self, pMin, pMax, col, rounding, thickness, flags);

	@:hlNative("sfimgui", "ImDrawList_AddRectFilled")
	private static function _ImDrawList_AddRectFilled(self:ImDrawList, p_min:ImVec2, p_max:ImVec2, col:Int, rounding:Single, flags:Int):Void {
	}

	public static inline function ImDrawList_AddRectFilled(self:ImDrawList, pMin:ImVec2, pMax:ImVec2, col:Int, rounding:Single = 0.0, flags:Int = 0):Void
		_ImDrawList_AddRectFilled(self, pMin, pMax, col, rounding, flags);

	@:hlNative("sfimgui", "ImDrawList_AddRectFilledMultiColor")
	private static function _ImDrawList_AddRectFilledMultiColor(self:ImDrawList, p_min:ImVec2, p_max:ImVec2, col_upr_left:Int, col_upr_right:Int, col_bot_right:Int, col_bot_left:Int):Void {
	}

	public static inline function ImDrawList_AddRectFilledMultiColor(self:ImDrawList, pMin:ImVec2, pMax:ImVec2, colUprLeft:Int, colUprRight:Int, colBotRight:Int, colBotLeft:Int):Void
		_ImDrawList_AddRectFilledMultiColor(self, pMin, pMax, colUprLeft, colUprRight, colBotRight, colBotLeft);

	@:hlNative("sfimgui", "ImDrawList_AddText_Vec2")
	private static function _ImDrawList_AddText_Vec2(self:ImDrawList, pos:ImVec2, col:Int, text_begin:hl.Bytes, text_end:hl.Bytes):Void {
	}

	public static inline function ImDrawList_AddText_Vec2(self:ImDrawList, pos:ImVec2, col:Int, text:String):Void
		_ImDrawList_AddText_Vec2(self, pos, col, cstr(text), null);

	@:hlNative("sfimgui", "ImDrawList_AddTriangle")
	private static function _ImDrawList_AddTriangle(self:ImDrawList, p1:ImVec2, p2:ImVec2, p3:ImVec2, col:Int, thickness:Single):Void {
	}

	public static inline function ImDrawList_AddTriangle(self:ImDrawList, p1:ImVec2, p2:ImVec2, p3:ImVec2, col:Int, thickness:Single = 1.0):Void
		_ImDrawList_AddTriangle(self, p1, p2, p3, col, thickness);

	@:hlNative("sfimgui", "ImDrawList_AddTriangleFilled")
	private static function _ImDrawList_AddTriangleFilled(self:ImDrawList, p1:ImVec2, p2:ImVec2, p3:ImVec2, col:Int):Void {
	}

	public static inline function ImDrawList_AddTriangleFilled(self:ImDrawList, p1:ImVec2, p2:ImVec2, p3:ImVec2, col:Int):Void
		_ImDrawList_AddTriangleFilled(self, p1, p2, p3, col);

	@:hlNative("sfimgui", "ImDrawList_ChannelsMerge")
	private static function _ImDrawList_ChannelsMerge(self:ImDrawList):Void {
	}

	public static inline function ImDrawList_ChannelsMerge(self:ImDrawList):Void
		_ImDrawList_ChannelsMerge(self);

	@:hlNative("sfimgui", "ImDrawList_ChannelsSetCurrent")
	private static function _ImDrawList_ChannelsSetCurrent(self:ImDrawList, n:Int):Void {
	}

	public static inline function ImDrawList_ChannelsSetCurrent(self:ImDrawList, n:Int):Void
		_ImDrawList_ChannelsSetCurrent(self, n);

	@:hlNative("sfimgui", "ImDrawList_ChannelsSplit")
	private static function _ImDrawList_ChannelsSplit(self:ImDrawList, count:Int):Void {
	}

	public static inline function ImDrawList_ChannelsSplit(self:ImDrawList, count:Int):Void
		_ImDrawList_ChannelsSplit(self, count);

	@:hlNative("sfimgui", "ImDrawList_CloneOutput")
	private static function _ImDrawList_CloneOutput(self:ImDrawList):ImDrawList {
		return null;
	}

	public static inline function ImDrawList_CloneOutput(self:ImDrawList):ImDrawList
		return _ImDrawList_CloneOutput(self);

	@:hlNative("sfimgui", "ImDrawList_GetClipRectMax")
	private static function _ImDrawList_GetClipRectMax(self:ImDrawList, hlxOut:ImVec2):Void {
	}

	public static inline function ImDrawList_GetClipRectMax(self:ImDrawList, hlxOut:ImVec2 = null):ImVec2 {
		hlxOut = hlxOut ?? new ImVec2();
		_ImDrawList_GetClipRectMax(self, hlxOut);
		return hlxOut;
	}

	@:hlNative("sfimgui", "ImDrawList_GetClipRectMin")
	private static function _ImDrawList_GetClipRectMin(self:ImDrawList, hlxOut:ImVec2):Void {
	}

	public static inline function ImDrawList_GetClipRectMin(self:ImDrawList, hlxOut:ImVec2 = null):ImVec2 {
		hlxOut = hlxOut ?? new ImVec2();
		_ImDrawList_GetClipRectMin(self, hlxOut);
		return hlxOut;
	}

	@:hlNative("sfimgui", "ImDrawList_PathArcTo")
	private static function _ImDrawList_PathArcTo(self:ImDrawList, center:ImVec2, radius:Single, a_min:Single, a_max:Single, num_segments:Int):Void {
	}

	public static inline function ImDrawList_PathArcTo(self:ImDrawList, center:ImVec2, radius:Single, aMin:Single, aMax:Single, numSegments:Int = 0):Void
		_ImDrawList_PathArcTo(self, center, radius, aMin, aMax, numSegments);

	@:hlNative("sfimgui", "ImDrawList_PathArcToFast")
	private static function _ImDrawList_PathArcToFast(self:ImDrawList, center:ImVec2, radius:Single, a_min_of_12:Int, a_max_of_12:Int):Void {
	}

	public static inline function ImDrawList_PathArcToFast(self:ImDrawList, center:ImVec2, radius:Single, aMinOf12:Int, aMaxOf12:Int):Void
		_ImDrawList_PathArcToFast(self, center, radius, aMinOf12, aMaxOf12);

	@:hlNative("sfimgui", "ImDrawList_PathBezierCubicCurveTo")
	private static function _ImDrawList_PathBezierCubicCurveTo(self:ImDrawList, p2:ImVec2, p3:ImVec2, p4:ImVec2, num_segments:Int):Void {
	}

	public static inline function ImDrawList_PathBezierCubicCurveTo(self:ImDrawList, p2:ImVec2, p3:ImVec2, p4:ImVec2, numSegments:Int = 0):Void
		_ImDrawList_PathBezierCubicCurveTo(self, p2, p3, p4, numSegments);

	@:hlNative("sfimgui", "ImDrawList_PathBezierQuadraticCurveTo")
	private static function _ImDrawList_PathBezierQuadraticCurveTo(self:ImDrawList, p2:ImVec2, p3:ImVec2, num_segments:Int):Void {
	}

	public static inline function ImDrawList_PathBezierQuadraticCurveTo(self:ImDrawList, p2:ImVec2, p3:ImVec2, numSegments:Int = 0):Void
		_ImDrawList_PathBezierQuadraticCurveTo(self, p2, p3, numSegments);

	@:hlNative("sfimgui", "ImDrawList_PathClear")
	private static function _ImDrawList_PathClear(self:ImDrawList):Void {
	}

	public static inline function ImDrawList_PathClear(self:ImDrawList):Void
		_ImDrawList_PathClear(self);

	@:hlNative("sfimgui", "ImDrawList_PathEllipticalArcTo")
	private static function _ImDrawList_PathEllipticalArcTo(self:ImDrawList, center:ImVec2, radius:ImVec2, rot:Single, a_min:Single, a_max:Single, num_segments:Int):Void {
	}

	public static inline function ImDrawList_PathEllipticalArcTo(self:ImDrawList, center:ImVec2, radius:ImVec2, rot:Single, aMin:Single, aMax:Single, numSegments:Int = 0):Void
		_ImDrawList_PathEllipticalArcTo(self, center, radius, rot, aMin, aMax, numSegments);

	@:hlNative("sfimgui", "ImDrawList_PathFillConcave")
	private static function _ImDrawList_PathFillConcave(self:ImDrawList, col:Int):Void {
	}

	public static inline function ImDrawList_PathFillConcave(self:ImDrawList, col:Int):Void
		_ImDrawList_PathFillConcave(self, col);

	@:hlNative("sfimgui", "ImDrawList_PathFillConvex")
	private static function _ImDrawList_PathFillConvex(self:ImDrawList, col:Int):Void {
	}

	public static inline function ImDrawList_PathFillConvex(self:ImDrawList, col:Int):Void
		_ImDrawList_PathFillConvex(self, col);

	@:hlNative("sfimgui", "ImDrawList_PathLineTo")
	private static function _ImDrawList_PathLineTo(self:ImDrawList, pos:ImVec2):Void {
	}

	public static inline function ImDrawList_PathLineTo(self:ImDrawList, pos:ImVec2):Void
		_ImDrawList_PathLineTo(self, pos);

	@:hlNative("sfimgui", "ImDrawList_PathLineToMergeDuplicate")
	private static function _ImDrawList_PathLineToMergeDuplicate(self:ImDrawList, pos:ImVec2):Void {
	}

	public static inline function ImDrawList_PathLineToMergeDuplicate(self:ImDrawList, pos:ImVec2):Void
		_ImDrawList_PathLineToMergeDuplicate(self, pos);

	@:hlNative("sfimgui", "ImDrawList_PathRect")
	private static function _ImDrawList_PathRect(self:ImDrawList, rect_min:ImVec2, rect_max:ImVec2, rounding:Single, flags:Int):Void {
	}

	public static inline function ImDrawList_PathRect(self:ImDrawList, rectMin:ImVec2, rectMax:ImVec2, rounding:Single = 0.0, flags:Int = 0):Void
		_ImDrawList_PathRect(self, rectMin, rectMax, rounding, flags);

	@:hlNative("sfimgui", "ImDrawList_PathStroke")
	private static function _ImDrawList_PathStroke(self:ImDrawList, col:Int, thickness:Single, flags:Int):Void {
	}

	public static inline function ImDrawList_PathStroke(self:ImDrawList, col:Int, thickness:Single = 1.0, flags:Int = 0):Void
		_ImDrawList_PathStroke(self, col, thickness, flags);

	@:hlNative("sfimgui", "ImDrawList_PopClipRect")
	private static function _ImDrawList_PopClipRect(self:ImDrawList):Void {
	}

	public static inline function ImDrawList_PopClipRect(self:ImDrawList):Void
		_ImDrawList_PopClipRect(self);

	@:hlNative("sfimgui", "ImDrawList_PopTexture")
	private static function _ImDrawList_PopTexture(self:ImDrawList):Void {
	}

	public static inline function ImDrawList_PopTexture(self:ImDrawList):Void
		_ImDrawList_PopTexture(self);

	@:hlNative("sfimgui", "ImDrawList_PrimQuadUV")
	private static function _ImDrawList_PrimQuadUV(self:ImDrawList, a:ImVec2, b:ImVec2, c:ImVec2, d:ImVec2, uv_a:ImVec2, uv_b:ImVec2, uv_c:ImVec2, uv_d:ImVec2, col:Int):Void {
	}

	public static inline function ImDrawList_PrimQuadUV(self:ImDrawList, a:ImVec2, b:ImVec2, c:ImVec2, d:ImVec2, uvA:ImVec2, uvB:ImVec2, uvC:ImVec2, uvD:ImVec2, col:Int):Void
		_ImDrawList_PrimQuadUV(self, a, b, c, d, uvA, uvB, uvC, uvD, col);

	@:hlNative("sfimgui", "ImDrawList_PrimRect")
	private static function _ImDrawList_PrimRect(self:ImDrawList, a:ImVec2, b:ImVec2, col:Int):Void {
	}

	public static inline function ImDrawList_PrimRect(self:ImDrawList, a:ImVec2, b:ImVec2, col:Int):Void
		_ImDrawList_PrimRect(self, a, b, col);

	@:hlNative("sfimgui", "ImDrawList_PrimRectUV")
	private static function _ImDrawList_PrimRectUV(self:ImDrawList, a:ImVec2, b:ImVec2, uv_a:ImVec2, uv_b:ImVec2, col:Int):Void {
	}

	public static inline function ImDrawList_PrimRectUV(self:ImDrawList, a:ImVec2, b:ImVec2, uvA:ImVec2, uvB:ImVec2, col:Int):Void
		_ImDrawList_PrimRectUV(self, a, b, uvA, uvB, col);

	@:hlNative("sfimgui", "ImDrawList_PrimReserve")
	private static function _ImDrawList_PrimReserve(self:ImDrawList, idx_count:Int, vtx_count:Int):Void {
	}

	public static inline function ImDrawList_PrimReserve(self:ImDrawList, idxCount:Int, vtxCount:Int):Void
		_ImDrawList_PrimReserve(self, idxCount, vtxCount);

	@:hlNative("sfimgui", "ImDrawList_PrimUnreserve")
	private static function _ImDrawList_PrimUnreserve(self:ImDrawList, idx_count:Int, vtx_count:Int):Void {
	}

	public static inline function ImDrawList_PrimUnreserve(self:ImDrawList, idxCount:Int, vtxCount:Int):Void
		_ImDrawList_PrimUnreserve(self, idxCount, vtxCount);

	@:hlNative("sfimgui", "ImDrawList_PrimVtx")
	private static function _ImDrawList_PrimVtx(self:ImDrawList, pos:ImVec2, uv:ImVec2, col:Int):Void {
	}

	public static inline function ImDrawList_PrimVtx(self:ImDrawList, pos:ImVec2, uv:ImVec2, col:Int):Void
		_ImDrawList_PrimVtx(self, pos, uv, col);

	@:hlNative("sfimgui", "ImDrawList_PrimWriteIdx")
	private static function _ImDrawList_PrimWriteIdx(self:ImDrawList, idx:Int):Void {
	}

	public static inline function ImDrawList_PrimWriteIdx(self:ImDrawList, idx:Int):Void
		_ImDrawList_PrimWriteIdx(self, idx);

	@:hlNative("sfimgui", "ImDrawList_PrimWriteVtx")
	private static function _ImDrawList_PrimWriteVtx(self:ImDrawList, pos:ImVec2, uv:ImVec2, col:Int):Void {
	}

	public static inline function ImDrawList_PrimWriteVtx(self:ImDrawList, pos:ImVec2, uv:ImVec2, col:Int):Void
		_ImDrawList_PrimWriteVtx(self, pos, uv, col);

	@:hlNative("sfimgui", "ImDrawList_PushClipRect")
	private static function _ImDrawList_PushClipRect(self:ImDrawList, clip_rect_min:ImVec2, clip_rect_max:ImVec2, intersect_with_current_clip_rect:Bool):Void {
	}

	public static inline function ImDrawList_PushClipRect(self:ImDrawList, clipRectMin:ImVec2, clipRectMax:ImVec2, intersectWithCurrentClipRect:Bool = false):Void
		_ImDrawList_PushClipRect(self, clipRectMin, clipRectMax, intersectWithCurrentClipRect);

	@:hlNative("sfimgui", "ImDrawList_PushClipRectFullScreen")
	private static function _ImDrawList_PushClipRectFullScreen(self:ImDrawList):Void {
	}

	public static inline function ImDrawList_PushClipRectFullScreen(self:ImDrawList):Void
		_ImDrawList_PushClipRectFullScreen(self);

	@:hlNative("sfimgui", "ImDrawList__CalcCircleAutoSegmentCount")
	private static function _ImDrawList__CalcCircleAutoSegmentCount(self:ImDrawList, radius:Single):Int {
		return 0;
	}

	public static inline function ImDrawList__CalcCircleAutoSegmentCount(self:ImDrawList, radius:Single):Int
		return _ImDrawList__CalcCircleAutoSegmentCount(self, radius);

	@:hlNative("sfimgui", "ImDrawList__ClearFreeMemory")
	private static function _ImDrawList__ClearFreeMemory(self:ImDrawList):Void {
	}

	public static inline function ImDrawList__ClearFreeMemory(self:ImDrawList):Void
		_ImDrawList__ClearFreeMemory(self);

	@:hlNative("sfimgui", "ImDrawList__OnChangedClipRect")
	private static function _ImDrawList__OnChangedClipRect(self:ImDrawList):Void {
	}

	public static inline function ImDrawList__OnChangedClipRect(self:ImDrawList):Void
		_ImDrawList__OnChangedClipRect(self);

	@:hlNative("sfimgui", "ImDrawList__OnChangedTexture")
	private static function _ImDrawList__OnChangedTexture(self:ImDrawList):Void {
	}

	public static inline function ImDrawList__OnChangedTexture(self:ImDrawList):Void
		_ImDrawList__OnChangedTexture(self);

	@:hlNative("sfimgui", "ImDrawList__OnChangedVtxOffset")
	private static function _ImDrawList__OnChangedVtxOffset(self:ImDrawList):Void {
	}

	public static inline function ImDrawList__OnChangedVtxOffset(self:ImDrawList):Void
		_ImDrawList__OnChangedVtxOffset(self);

	@:hlNative("sfimgui", "ImDrawList__PathArcToFastEx")
	private static function _ImDrawList__PathArcToFastEx(self:ImDrawList, center:ImVec2, radius:Single, a_min_sample:Int, a_max_sample:Int, a_step:Int):Void {
	}

	public static inline function ImDrawList__PathArcToFastEx(self:ImDrawList, center:ImVec2, radius:Single, aMinSample:Int, aMaxSample:Int, aStep:Int):Void
		_ImDrawList__PathArcToFastEx(self, center, radius, aMinSample, aMaxSample, aStep);

	@:hlNative("sfimgui", "ImDrawList__PathArcToN")
	private static function _ImDrawList__PathArcToN(self:ImDrawList, center:ImVec2, radius:Single, a_min:Single, a_max:Single, num_segments:Int):Void {
	}

	public static inline function ImDrawList__PathArcToN(self:ImDrawList, center:ImVec2, radius:Single, aMin:Single, aMax:Single, numSegments:Int):Void
		_ImDrawList__PathArcToN(self, center, radius, aMin, aMax, numSegments);

	@:hlNative("sfimgui", "ImDrawList__PopUnusedDrawCmd")
	private static function _ImDrawList__PopUnusedDrawCmd(self:ImDrawList):Void {
	}

	public static inline function ImDrawList__PopUnusedDrawCmd(self:ImDrawList):Void
		_ImDrawList__PopUnusedDrawCmd(self);

	@:hlNative("sfimgui", "ImDrawList__ResetForNewFrame")
	private static function _ImDrawList__ResetForNewFrame(self:ImDrawList):Void {
	}

	public static inline function ImDrawList__ResetForNewFrame(self:ImDrawList):Void
		_ImDrawList__ResetForNewFrame(self);

	@:hlNative("sfimgui", "ImDrawList__SetDrawListSharedData")
	private static function _ImDrawList__SetDrawListSharedData(self:ImDrawList, data:ImDrawListSharedData):Void {
	}

	public static inline function ImDrawList__SetDrawListSharedData(self:ImDrawList, data:ImDrawListSharedData):Void
		_ImDrawList__SetDrawListSharedData(self, data);

	@:hlNative("sfimgui", "ImDrawList__TryMergeDrawCmds")
	private static function _ImDrawList__TryMergeDrawCmds(self:ImDrawList):Void {
	}

	public static inline function ImDrawList__TryMergeDrawCmds(self:ImDrawList):Void
		_ImDrawList__TryMergeDrawCmds(self);

	@:hlNative("sfimgui", "ImFontAtlas_AddCustomRect")
	private static function _ImFontAtlas_AddCustomRect(self:ImFontAtlas, width:Int, height:Int, out_r:ImFontAtlasRect):Int {
		return 0;
	}

	public static inline function ImFontAtlas_AddCustomRect(self:ImFontAtlas, width:Int, height:Int, outR:ImFontAtlasRect = null):Int
		return _ImFontAtlas_AddCustomRect(self, width, height, outR);

	@:hlNative("sfimgui", "ImFontAtlas_AddFont")
	private static function _ImFontAtlas_AddFont(self:ImFontAtlas, font_cfg:ImFontConfig):ImFont {
		return null;
	}

	public static inline function ImFontAtlas_AddFont(self:ImFontAtlas, fontCfg:ImFontConfig):ImFont
		return _ImFontAtlas_AddFont(self, fontCfg);

	@:hlNative("sfimgui", "ImFontAtlas_AddFontDefault")
	private static function _ImFontAtlas_AddFontDefault(self:ImFontAtlas, font_cfg:ImFontConfig):ImFont {
		return null;
	}

	public static inline function ImFontAtlas_AddFontDefault(self:ImFontAtlas, fontCfg:ImFontConfig = null):ImFont
		return _ImFontAtlas_AddFontDefault(self, fontCfg);

	@:hlNative("sfimgui", "ImFontAtlas_AddFontDefaultBitmap")
	private static function _ImFontAtlas_AddFontDefaultBitmap(self:ImFontAtlas, font_cfg:ImFontConfig):ImFont {
		return null;
	}

	public static inline function ImFontAtlas_AddFontDefaultBitmap(self:ImFontAtlas, fontCfg:ImFontConfig = null):ImFont
		return _ImFontAtlas_AddFontDefaultBitmap(self, fontCfg);

	@:hlNative("sfimgui", "ImFontAtlas_AddFontDefaultVector")
	private static function _ImFontAtlas_AddFontDefaultVector(self:ImFontAtlas, font_cfg:ImFontConfig):ImFont {
		return null;
	}

	public static inline function ImFontAtlas_AddFontDefaultVector(self:ImFontAtlas, fontCfg:ImFontConfig = null):ImFont
		return _ImFontAtlas_AddFontDefaultVector(self, fontCfg);

	@:hlNative("sfimgui", "ImFontAtlas_AddFontFromFileTTF")
	private static function _ImFontAtlas_AddFontFromFileTTF(self:ImFontAtlas, filename:hl.Bytes, size_pixels:Single, font_cfg:ImFontConfig, glyph_ranges:hl.Bytes):ImFont {
		return null;
	}

	public static inline function ImFontAtlas_AddFontFromFileTTF(self:ImFontAtlas, filename:String, sizePixels:Single = 0.0, fontCfg:ImFontConfig = null, glyphRanges:hl.Bytes = null):ImFont
		return _ImFontAtlas_AddFontFromFileTTF(self, cstr(filename), sizePixels, fontCfg, glyphRanges);

	@:hlNative("sfimgui", "ImFontAtlas_AddFontFromMemoryCompressedBase85TTF")
	private static function _ImFontAtlas_AddFontFromMemoryCompressedBase85TTF(self:ImFontAtlas, compressed_font_data_base85:hl.Bytes, size_pixels:Single, font_cfg:ImFontConfig, glyph_ranges:hl.Bytes):ImFont {
		return null;
	}

	public static inline function ImFontAtlas_AddFontFromMemoryCompressedBase85TTF(self:ImFontAtlas, compressedFontDataBase85:String, sizePixels:Single = 0.0, fontCfg:ImFontConfig = null, glyphRanges:hl.Bytes = null):ImFont
		return _ImFontAtlas_AddFontFromMemoryCompressedBase85TTF(self, cstr(compressedFontDataBase85), sizePixels, fontCfg, glyphRanges);

	@:hlNative("sfimgui", "ImFontAtlas_Clear")
	private static function _ImFontAtlas_Clear(self:ImFontAtlas):Void {
	}

	public static inline function ImFontAtlas_Clear(self:ImFontAtlas):Void
		_ImFontAtlas_Clear(self);

	@:hlNative("sfimgui", "ImFontAtlas_ClearFonts")
	private static function _ImFontAtlas_ClearFonts(self:ImFontAtlas):Void {
	}

	public static inline function ImFontAtlas_ClearFonts(self:ImFontAtlas):Void
		_ImFontAtlas_ClearFonts(self);

	@:hlNative("sfimgui", "ImFontAtlas_ClearInputData")
	private static function _ImFontAtlas_ClearInputData(self:ImFontAtlas):Void {
	}

	public static inline function ImFontAtlas_ClearInputData(self:ImFontAtlas):Void
		_ImFontAtlas_ClearInputData(self);

	@:hlNative("sfimgui", "ImFontAtlas_ClearTexData")
	private static function _ImFontAtlas_ClearTexData(self:ImFontAtlas):Void {
	}

	public static inline function ImFontAtlas_ClearTexData(self:ImFontAtlas):Void
		_ImFontAtlas_ClearTexData(self);

	@:hlNative("sfimgui", "ImFontAtlas_CompactCache")
	private static function _ImFontAtlas_CompactCache(self:ImFontAtlas):Void {
	}

	public static inline function ImFontAtlas_CompactCache(self:ImFontAtlas):Void
		_ImFontAtlas_CompactCache(self);

	@:hlNative("sfimgui", "ImFontAtlas_GetCustomRect")
	private static function _ImFontAtlas_GetCustomRect(self:ImFontAtlas, id:Int, out_r:ImFontAtlasRect):Bool {
		return false;
	}

	public static inline function ImFontAtlas_GetCustomRect(self:ImFontAtlas, id:Int, outR:ImFontAtlasRect):Bool
		return _ImFontAtlas_GetCustomRect(self, id, outR);

	@:hlNative("sfimgui", "ImFontAtlas_GetGlyphRangesDefault")
	private static function _ImFontAtlas_GetGlyphRangesDefault(self:ImFontAtlas):hl.Bytes {
		return null;
	}

	public static inline function ImFontAtlas_GetGlyphRangesDefault(self:ImFontAtlas):hl.Bytes
		return _ImFontAtlas_GetGlyphRangesDefault(self);

	@:hlNative("sfimgui", "ImFontAtlas_RemoveCustomRect")
	private static function _ImFontAtlas_RemoveCustomRect(self:ImFontAtlas, id:Int):Void {
	}

	public static inline function ImFontAtlas_RemoveCustomRect(self:ImFontAtlas, id:Int):Void
		_ImFontAtlas_RemoveCustomRect(self, id);

	@:hlNative("sfimgui", "ImFontAtlas_RemoveFont")
	private static function _ImFontAtlas_RemoveFont(self:ImFontAtlas, font:ImFont):Void {
	}

	public static inline function ImFontAtlas_RemoveFont(self:ImFontAtlas, font:ImFont):Void
		_ImFontAtlas_RemoveFont(self, font);

	@:hlNative("sfimgui", "ImFontAtlas_SetFontLoader")
	private static function _ImFontAtlas_SetFontLoader(self:ImFontAtlas, font_loader:ImFontLoader):Void {
	}

	public static inline function ImFontAtlas_SetFontLoader(self:ImFontAtlas, fontLoader:ImFontLoader):Void
		_ImFontAtlas_SetFontLoader(self, fontLoader);

	@:hlNative("sfimgui", "ImFontBaked_ClearOutputData")
	private static function _ImFontBaked_ClearOutputData(self:ImFontBaked):Void {
	}

	public static inline function ImFontBaked_ClearOutputData(self:ImFontBaked):Void
		_ImFontBaked_ClearOutputData(self);

	@:hlNative("sfimgui", "ImFontBaked_FindGlyph")
	private static function _ImFontBaked_FindGlyph(self:ImFontBaked, c:Int):ImFontGlyph {
		return null;
	}

	public static inline function ImFontBaked_FindGlyph(self:ImFontBaked, c:Int):ImFontGlyph
		return _ImFontBaked_FindGlyph(self, c);

	@:hlNative("sfimgui", "ImFontBaked_FindGlyphNoFallback")
	private static function _ImFontBaked_FindGlyphNoFallback(self:ImFontBaked, c:Int):ImFontGlyph {
		return null;
	}

	public static inline function ImFontBaked_FindGlyphNoFallback(self:ImFontBaked, c:Int):ImFontGlyph
		return _ImFontBaked_FindGlyphNoFallback(self, c);

	@:hlNative("sfimgui", "ImFontBaked_GetCharAdvance")
	private static function _ImFontBaked_GetCharAdvance(self:ImFontBaked, c:Int):Single {
		return 0;
	}

	public static inline function ImFontBaked_GetCharAdvance(self:ImFontBaked, c:Int):Single
		return _ImFontBaked_GetCharAdvance(self, c);

	@:hlNative("sfimgui", "ImFontBaked_IsGlyphLoaded")
	private static function _ImFontBaked_IsGlyphLoaded(self:ImFontBaked, c:Int):Bool {
		return false;
	}

	public static inline function ImFontBaked_IsGlyphLoaded(self:ImFontBaked, c:Int):Bool
		return _ImFontBaked_IsGlyphLoaded(self, c);

	@:hlNative("sfimgui", "ImFontGlyphRangesBuilder_AddChar")
	private static function _ImFontGlyphRangesBuilder_AddChar(self:ImFontGlyphRangesBuilder, c:Int):Void {
	}

	public static inline function ImFontGlyphRangesBuilder_AddChar(self:ImFontGlyphRangesBuilder, c:Int):Void
		_ImFontGlyphRangesBuilder_AddChar(self, c);

	@:hlNative("sfimgui", "ImFontGlyphRangesBuilder_AddRanges")
	private static function _ImFontGlyphRangesBuilder_AddRanges(self:ImFontGlyphRangesBuilder, ranges:hl.Bytes):Void {
	}

	public static inline function ImFontGlyphRangesBuilder_AddRanges(self:ImFontGlyphRangesBuilder, ranges:hl.Bytes):Void
		_ImFontGlyphRangesBuilder_AddRanges(self, ranges);

	@:hlNative("sfimgui", "ImFontGlyphRangesBuilder_AddText")
	private static function _ImFontGlyphRangesBuilder_AddText(self:ImFontGlyphRangesBuilder, text:hl.Bytes, text_end:hl.Bytes):Void {
	}

	public static inline function ImFontGlyphRangesBuilder_AddText(self:ImFontGlyphRangesBuilder, text:String):Void
		_ImFontGlyphRangesBuilder_AddText(self, cstr(text), null);

	@:hlNative("sfimgui", "ImFontGlyphRangesBuilder_Clear")
	private static function _ImFontGlyphRangesBuilder_Clear(self:ImFontGlyphRangesBuilder):Void {
	}

	public static inline function ImFontGlyphRangesBuilder_Clear(self:ImFontGlyphRangesBuilder):Void
		_ImFontGlyphRangesBuilder_Clear(self);

	@:hlNative("sfimgui", "ImFontGlyphRangesBuilder_GetBit")
	private static function _ImFontGlyphRangesBuilder_GetBit(self:ImFontGlyphRangesBuilder, n:hl.I64):Bool {
		return false;
	}

	public static inline function ImFontGlyphRangesBuilder_GetBit(self:ImFontGlyphRangesBuilder, n:hl.I64):Bool
		return _ImFontGlyphRangesBuilder_GetBit(self, n);

	@:hlNative("sfimgui", "ImFontGlyphRangesBuilder_SetBit")
	private static function _ImFontGlyphRangesBuilder_SetBit(self:ImFontGlyphRangesBuilder, n:hl.I64):Void {
	}

	public static inline function ImFontGlyphRangesBuilder_SetBit(self:ImFontGlyphRangesBuilder, n:hl.I64):Void
		_ImFontGlyphRangesBuilder_SetBit(self, n);

	@:hlNative("sfimgui", "ImFont_AddRemapChar")
	private static function _ImFont_AddRemapChar(self:ImFont, from_codepoint:Int, to_codepoint:Int):Void {
	}

	public static inline function ImFont_AddRemapChar(self:ImFont, fromCodepoint:Int, toCodepoint:Int):Void
		_ImFont_AddRemapChar(self, fromCodepoint, toCodepoint);

	@:hlNative("sfimgui", "ImFont_CalcTextSizeA")
	private static function _ImFont_CalcTextSizeA(self:ImFont, size:Single, max_width:Single, wrap_width:Single, text_begin:hl.Bytes, text_end:hl.Bytes, hlxOut:ImVec2):Void {
	}

	public static inline function ImFont_CalcTextSizeA(self:ImFont, size:Single, maxWidth:Single, wrapWidth:Single, text:String, hlxOut:ImVec2 = null):ImVec2 {
		hlxOut = hlxOut ?? new ImVec2();
		_ImFont_CalcTextSizeA(self, size, maxWidth, wrapWidth, cstr(text), null, hlxOut);
		return hlxOut;
	}

	@:hlNative("sfimgui", "ImFont_CalcWordWrapPosition")
	private static function _ImFont_CalcWordWrapPosition(self:ImFont, size:Single, text:hl.Bytes, text_end:hl.Bytes, wrap_width:Single):hl.Bytes {
		return null;
	}

	public static inline function ImFont_CalcWordWrapPosition(self:ImFont, size:Single, text:String, wrapWidth:Single):hl.Bytes
		return _ImFont_CalcWordWrapPosition(self, size, cstr(text), null, wrapWidth);

	@:hlNative("sfimgui", "ImFont_ClearOutputData")
	private static function _ImFont_ClearOutputData(self:ImFont):Void {
	}

	public static inline function ImFont_ClearOutputData(self:ImFont):Void
		_ImFont_ClearOutputData(self);

	@:hlNative("sfimgui", "ImFont_GetDebugName")
	private static function _ImFont_GetDebugName(self:ImFont):hl.Bytes {
		return null;
	}

	public static inline function ImFont_GetDebugName(self:ImFont):hl.Bytes
		return _ImFont_GetDebugName(self);

	@:hlNative("sfimgui", "ImFont_GetFontBaked")
	private static function _ImFont_GetFontBaked(self:ImFont, font_size:Single, density:Single):ImFontBaked {
		return null;
	}

	public static inline function ImFont_GetFontBaked(self:ImFont, fontSize:Single, density:Single = -1.0):ImFontBaked
		return _ImFont_GetFontBaked(self, fontSize, density);

	@:hlNative("sfimgui", "ImFont_IsGlyphInFont")
	private static function _ImFont_IsGlyphInFont(self:ImFont, c:Int):Bool {
		return false;
	}

	public static inline function ImFont_IsGlyphInFont(self:ImFont, c:Int):Bool
		return _ImFont_IsGlyphInFont(self, c);

	@:hlNative("sfimgui", "ImFont_IsGlyphRangeUnused")
	private static function _ImFont_IsGlyphRangeUnused(self:ImFont, c_begin:Int, c_last:Int):Bool {
		return false;
	}

	public static inline function ImFont_IsGlyphRangeUnused(self:ImFont, cBegin:Int, cLast:Int):Bool
		return _ImFont_IsGlyphRangeUnused(self, cBegin, cLast);

	@:hlNative("sfimgui", "ImFont_IsLoaded")
	private static function _ImFont_IsLoaded(self:ImFont):Bool {
		return false;
	}

	public static inline function ImFont_IsLoaded(self:ImFont):Bool
		return _ImFont_IsLoaded(self);

	@:hlNative("sfimgui", "ImFont_RenderText")
	private static function _ImFont_RenderText(self:ImFont, draw_list:ImDrawList, size:Single, pos:ImVec2, col:Int, clip_rect:ImVec4, text_begin:hl.Bytes, text_end:hl.Bytes, wrap_width:Single, flags:Int):Void {
	}

	public static inline function ImFont_RenderText(self:ImFont, drawList:ImDrawList, size:Single, pos:ImVec2, col:Int, clipRect:ImVec4, text:String, wrapWidth:Single = 0.0, flags:Int = 0):Void
		_ImFont_RenderText(self, drawList, size, pos, col, clipRect, cstr(text), null, wrapWidth, flags);

	@:hlNative("sfimgui", "ImGuiIO_AddFocusEvent")
	private static function _ImGuiIO_AddFocusEvent(self:ImGuiIO, focused:Bool):Void {
	}

	public static inline function ImGuiIO_AddFocusEvent(self:ImGuiIO, focused:Bool):Void
		_ImGuiIO_AddFocusEvent(self, focused);

	@:hlNative("sfimgui", "ImGuiIO_AddInputCharacter")
	private static function _ImGuiIO_AddInputCharacter(self:ImGuiIO, c:Int):Void {
	}

	public static inline function ImGuiIO_AddInputCharacter(self:ImGuiIO, c:Int):Void
		_ImGuiIO_AddInputCharacter(self, c);

	@:hlNative("sfimgui", "ImGuiIO_AddInputCharacterUTF16")
	private static function _ImGuiIO_AddInputCharacterUTF16(self:ImGuiIO, c:Int):Void {
	}

	public static inline function ImGuiIO_AddInputCharacterUTF16(self:ImGuiIO, c:Int):Void
		_ImGuiIO_AddInputCharacterUTF16(self, c);

	@:hlNative("sfimgui", "ImGuiIO_AddInputCharactersUTF8")
	private static function _ImGuiIO_AddInputCharactersUTF8(self:ImGuiIO, str:hl.Bytes):Void {
	}

	public static inline function ImGuiIO_AddInputCharactersUTF8(self:ImGuiIO, str:String):Void
		_ImGuiIO_AddInputCharactersUTF8(self, cstr(str));

	@:hlNative("sfimgui", "ImGuiIO_AddKeyAnalogEvent")
	private static function _ImGuiIO_AddKeyAnalogEvent(self:ImGuiIO, key:Int, down:Bool, v:Single):Void {
	}

	public static inline function ImGuiIO_AddKeyAnalogEvent(self:ImGuiIO, key:Int, down:Bool, v:Single):Void
		_ImGuiIO_AddKeyAnalogEvent(self, key, down, v);

	@:hlNative("sfimgui", "ImGuiIO_AddKeyEvent")
	private static function _ImGuiIO_AddKeyEvent(self:ImGuiIO, key:Int, down:Bool):Void {
	}

	public static inline function ImGuiIO_AddKeyEvent(self:ImGuiIO, key:Int, down:Bool):Void
		_ImGuiIO_AddKeyEvent(self, key, down);

	@:hlNative("sfimgui", "ImGuiIO_AddMouseButtonEvent")
	private static function _ImGuiIO_AddMouseButtonEvent(self:ImGuiIO, button:Int, down:Bool):Void {
	}

	public static inline function ImGuiIO_AddMouseButtonEvent(self:ImGuiIO, button:Int, down:Bool):Void
		_ImGuiIO_AddMouseButtonEvent(self, button, down);

	@:hlNative("sfimgui", "ImGuiIO_AddMousePosEvent")
	private static function _ImGuiIO_AddMousePosEvent(self:ImGuiIO, x:Single, y:Single):Void {
	}

	public static inline function ImGuiIO_AddMousePosEvent(self:ImGuiIO, x:Single, y:Single):Void
		_ImGuiIO_AddMousePosEvent(self, x, y);

	@:hlNative("sfimgui", "ImGuiIO_AddMouseSourceEvent")
	private static function _ImGuiIO_AddMouseSourceEvent(self:ImGuiIO, source:Int):Void {
	}

	public static inline function ImGuiIO_AddMouseSourceEvent(self:ImGuiIO, source:Int):Void
		_ImGuiIO_AddMouseSourceEvent(self, source);

	@:hlNative("sfimgui", "ImGuiIO_AddMouseWheelEvent")
	private static function _ImGuiIO_AddMouseWheelEvent(self:ImGuiIO, wheel_x:Single, wheel_y:Single):Void {
	}

	public static inline function ImGuiIO_AddMouseWheelEvent(self:ImGuiIO, wheelX:Single, wheelY:Single):Void
		_ImGuiIO_AddMouseWheelEvent(self, wheelX, wheelY);

	@:hlNative("sfimgui", "ImGuiIO_ClearEventsQueue")
	private static function _ImGuiIO_ClearEventsQueue(self:ImGuiIO):Void {
	}

	public static inline function ImGuiIO_ClearEventsQueue(self:ImGuiIO):Void
		_ImGuiIO_ClearEventsQueue(self);

	@:hlNative("sfimgui", "ImGuiIO_ClearInputKeys")
	private static function _ImGuiIO_ClearInputKeys(self:ImGuiIO):Void {
	}

	public static inline function ImGuiIO_ClearInputKeys(self:ImGuiIO):Void
		_ImGuiIO_ClearInputKeys(self);

	@:hlNative("sfimgui", "ImGuiIO_ClearInputMouse")
	private static function _ImGuiIO_ClearInputMouse(self:ImGuiIO):Void {
	}

	public static inline function ImGuiIO_ClearInputMouse(self:ImGuiIO):Void
		_ImGuiIO_ClearInputMouse(self);

	@:hlNative("sfimgui", "ImGuiIO_SetAppAcceptingEvents")
	private static function _ImGuiIO_SetAppAcceptingEvents(self:ImGuiIO, accepting_events:Bool):Void {
	}

	public static inline function ImGuiIO_SetAppAcceptingEvents(self:ImGuiIO, acceptingEvents:Bool):Void
		_ImGuiIO_SetAppAcceptingEvents(self, acceptingEvents);

	@:hlNative("sfimgui", "ImGuiIO_SetKeyEventNativeData")
	private static function _ImGuiIO_SetKeyEventNativeData(self:ImGuiIO, key:Int, native_keycode:Int, native_scancode:Int, native_legacy_index:Int):Void {
	}

	public static inline function ImGuiIO_SetKeyEventNativeData(self:ImGuiIO, key:Int, nativeKeycode:Int, nativeScancode:Int, nativeLegacyIndex:Int = -1):Void
		_ImGuiIO_SetKeyEventNativeData(self, key, nativeKeycode, nativeScancode, nativeLegacyIndex);

	@:hlNative("sfimgui", "ImGuiInputTextCallbackData_ClearSelection")
	private static function _ImGuiInputTextCallbackData_ClearSelection(self:ImGuiInputTextCallbackData):Void {
	}

	public static inline function ImGuiInputTextCallbackData_ClearSelection(self:ImGuiInputTextCallbackData):Void
		_ImGuiInputTextCallbackData_ClearSelection(self);

	@:hlNative("sfimgui", "ImGuiInputTextCallbackData_DeleteChars")
	private static function _ImGuiInputTextCallbackData_DeleteChars(self:ImGuiInputTextCallbackData, pos:Int, bytes_count:Int):Void {
	}

	public static inline function ImGuiInputTextCallbackData_DeleteChars(self:ImGuiInputTextCallbackData, pos:Int, bytesCount:Int):Void
		_ImGuiInputTextCallbackData_DeleteChars(self, pos, bytesCount);

	@:hlNative("sfimgui", "ImGuiInputTextCallbackData_HasSelection")
	private static function _ImGuiInputTextCallbackData_HasSelection(self:ImGuiInputTextCallbackData):Bool {
		return false;
	}

	public static inline function ImGuiInputTextCallbackData_HasSelection(self:ImGuiInputTextCallbackData):Bool
		return _ImGuiInputTextCallbackData_HasSelection(self);

	@:hlNative("sfimgui", "ImGuiInputTextCallbackData_InsertChars")
	private static function _ImGuiInputTextCallbackData_InsertChars(self:ImGuiInputTextCallbackData, pos:Int, text:hl.Bytes, text_end:hl.Bytes):Void {
	}

	public static inline function ImGuiInputTextCallbackData_InsertChars(self:ImGuiInputTextCallbackData, pos:Int, text:String):Void
		_ImGuiInputTextCallbackData_InsertChars(self, pos, cstr(text), null);

	@:hlNative("sfimgui", "ImGuiInputTextCallbackData_SelectAll")
	private static function _ImGuiInputTextCallbackData_SelectAll(self:ImGuiInputTextCallbackData):Void {
	}

	public static inline function ImGuiInputTextCallbackData_SelectAll(self:ImGuiInputTextCallbackData):Void
		_ImGuiInputTextCallbackData_SelectAll(self);

	@:hlNative("sfimgui", "ImGuiInputTextCallbackData_SetSelection")
	private static function _ImGuiInputTextCallbackData_SetSelection(self:ImGuiInputTextCallbackData, s:Int, e:Int):Void {
	}

	public static inline function ImGuiInputTextCallbackData_SetSelection(self:ImGuiInputTextCallbackData, s:Int, e:Int):Void
		_ImGuiInputTextCallbackData_SetSelection(self, s, e);

	@:hlNative("sfimgui", "ImGuiListClipper_Begin")
	private static function _ImGuiListClipper_Begin(self:ImGuiListClipper, items_count:Int, items_height:Single):Void {
	}

	public static inline function ImGuiListClipper_Begin(self:ImGuiListClipper, itemsCount:Int, itemsHeight:Single = -1.0):Void
		_ImGuiListClipper_Begin(self, itemsCount, itemsHeight);

	@:hlNative("sfimgui", "ImGuiListClipper_End")
	private static function _ImGuiListClipper_End(self:ImGuiListClipper):Void {
	}

	public static inline function ImGuiListClipper_End(self:ImGuiListClipper):Void
		_ImGuiListClipper_End(self);

	@:hlNative("sfimgui", "ImGuiListClipper_IncludeItemByIndex")
	private static function _ImGuiListClipper_IncludeItemByIndex(self:ImGuiListClipper, item_index:Int):Void {
	}

	public static inline function ImGuiListClipper_IncludeItemByIndex(self:ImGuiListClipper, itemIndex:Int):Void
		_ImGuiListClipper_IncludeItemByIndex(self, itemIndex);

	@:hlNative("sfimgui", "ImGuiListClipper_IncludeItemsByIndex")
	private static function _ImGuiListClipper_IncludeItemsByIndex(self:ImGuiListClipper, item_begin:Int, item_end:Int):Void {
	}

	public static inline function ImGuiListClipper_IncludeItemsByIndex(self:ImGuiListClipper, itemBegin:Int, itemEnd:Int):Void
		_ImGuiListClipper_IncludeItemsByIndex(self, itemBegin, itemEnd);

	@:hlNative("sfimgui", "ImGuiListClipper_SeekCursorForItem")
	private static function _ImGuiListClipper_SeekCursorForItem(self:ImGuiListClipper, item_index:Int):Void {
	}

	public static inline function ImGuiListClipper_SeekCursorForItem(self:ImGuiListClipper, itemIndex:Int):Void
		_ImGuiListClipper_SeekCursorForItem(self, itemIndex);

	@:hlNative("sfimgui", "ImGuiListClipper_Step")
	private static function _ImGuiListClipper_Step(self:ImGuiListClipper):Bool {
		return false;
	}

	public static inline function ImGuiListClipper_Step(self:ImGuiListClipper):Bool
		return _ImGuiListClipper_Step(self);

	@:hlNative("sfimgui", "ImGuiPayload_Clear")
	private static function _ImGuiPayload_Clear(self:ImGuiPayload):Void {
	}

	public static inline function ImGuiPayload_Clear(self:ImGuiPayload):Void
		_ImGuiPayload_Clear(self);

	@:hlNative("sfimgui", "ImGuiPayload_IsDataType")
	private static function _ImGuiPayload_IsDataType(self:ImGuiPayload, type:hl.Bytes):Bool {
		return false;
	}

	public static inline function ImGuiPayload_IsDataType(self:ImGuiPayload, type:String):Bool
		return _ImGuiPayload_IsDataType(self, cstr(type));

	@:hlNative("sfimgui", "ImGuiPayload_IsDelivery")
	private static function _ImGuiPayload_IsDelivery(self:ImGuiPayload):Bool {
		return false;
	}

	public static inline function ImGuiPayload_IsDelivery(self:ImGuiPayload):Bool
		return _ImGuiPayload_IsDelivery(self);

	@:hlNative("sfimgui", "ImGuiPayload_IsPreview")
	private static function _ImGuiPayload_IsPreview(self:ImGuiPayload):Bool {
		return false;
	}

	public static inline function ImGuiPayload_IsPreview(self:ImGuiPayload):Bool
		return _ImGuiPayload_IsPreview(self);

	@:hlNative("sfimgui", "ImGuiPlatformIO_ClearPlatformHandlers")
	private static function _ImGuiPlatformIO_ClearPlatformHandlers(self:ImGuiPlatformIO):Void {
	}

	public static inline function ImGuiPlatformIO_ClearPlatformHandlers(self:ImGuiPlatformIO):Void
		_ImGuiPlatformIO_ClearPlatformHandlers(self);

	@:hlNative("sfimgui", "ImGuiPlatformIO_ClearRendererHandlers")
	private static function _ImGuiPlatformIO_ClearRendererHandlers(self:ImGuiPlatformIO):Void {
	}

	public static inline function ImGuiPlatformIO_ClearRendererHandlers(self:ImGuiPlatformIO):Void
		_ImGuiPlatformIO_ClearRendererHandlers(self);

	@:hlNative("sfimgui", "ImGuiSelectionBasicStorage_Clear")
	private static function _ImGuiSelectionBasicStorage_Clear(self:ImGuiSelectionBasicStorage):Void {
	}

	public static inline function ImGuiSelectionBasicStorage_Clear(self:ImGuiSelectionBasicStorage):Void
		_ImGuiSelectionBasicStorage_Clear(self);

	@:hlNative("sfimgui", "ImGuiSelectionBasicStorage_Contains")
	private static function _ImGuiSelectionBasicStorage_Contains(self:ImGuiSelectionBasicStorage, id:Int):Bool {
		return false;
	}

	public static inline function ImGuiSelectionBasicStorage_Contains(self:ImGuiSelectionBasicStorage, id:Int):Bool
		return _ImGuiSelectionBasicStorage_Contains(self, id);

	@:hlNative("sfimgui", "ImGuiSelectionBasicStorage_GetStorageIdFromIndex")
	private static function _ImGuiSelectionBasicStorage_GetStorageIdFromIndex(self:ImGuiSelectionBasicStorage, idx:Int):Int {
		return 0;
	}

	public static inline function ImGuiSelectionBasicStorage_GetStorageIdFromIndex(self:ImGuiSelectionBasicStorage, idx:Int):Int
		return _ImGuiSelectionBasicStorage_GetStorageIdFromIndex(self, idx);

	@:hlNative("sfimgui", "ImGuiSelectionBasicStorage_SetItemSelected")
	private static function _ImGuiSelectionBasicStorage_SetItemSelected(self:ImGuiSelectionBasicStorage, id:Int, selected:Bool):Void {
	}

	public static inline function ImGuiSelectionBasicStorage_SetItemSelected(self:ImGuiSelectionBasicStorage, id:Int, selected:Bool):Void
		_ImGuiSelectionBasicStorage_SetItemSelected(self, id, selected);

	@:hlNative("sfimgui", "ImGuiSelectionBasicStorage_Swap")
	private static function _ImGuiSelectionBasicStorage_Swap(self:ImGuiSelectionBasicStorage, r:ImGuiSelectionBasicStorage):Void {
	}

	public static inline function ImGuiSelectionBasicStorage_Swap(self:ImGuiSelectionBasicStorage, r:ImGuiSelectionBasicStorage):Void
		_ImGuiSelectionBasicStorage_Swap(self, r);

	@:hlNative("sfimgui", "ImGuiStyle_ScaleAllSizes")
	private static function _ImGuiStyle_ScaleAllSizes(self:ImGuiStyle, scale_factor:Single):Void {
	}

	public static inline function ImGuiStyle_ScaleAllSizes(self:ImGuiStyle, scaleFactor:Single):Void
		_ImGuiStyle_ScaleAllSizes(self, scaleFactor);

	@:hlNative("sfimgui", "ImGuiTextBuffer_append")
	private static function _ImGuiTextBuffer_append(self:ImGuiTextBuffer, str:hl.Bytes, str_end:hl.Bytes):Void {
	}

	public static inline function ImGuiTextBuffer_append(self:ImGuiTextBuffer, str:String):Void
		_ImGuiTextBuffer_append(self, cstr(str), null);

	@:hlNative("sfimgui", "ImGuiTextBuffer_appendf")
	private static function _ImGuiTextBuffer_appendf(self:ImGuiTextBuffer, fmt:hl.Bytes):Void {
	}

	public static inline function ImGuiTextBuffer_appendf(self:ImGuiTextBuffer, text:String):Void
		_ImGuiTextBuffer_appendf(self, cstr(text));

	@:hlNative("sfimgui", "ImGuiTextBuffer_begin")
	private static function _ImGuiTextBuffer_begin(self:ImGuiTextBuffer):hl.Bytes {
		return null;
	}

	public static inline function ImGuiTextBuffer_begin(self:ImGuiTextBuffer):hl.Bytes
		return _ImGuiTextBuffer_begin(self);

	@:hlNative("sfimgui", "ImGuiTextBuffer_c_str")
	private static function _ImGuiTextBuffer_c_str(self:ImGuiTextBuffer):hl.Bytes {
		return null;
	}

	public static inline function ImGuiTextBuffer_c_str(self:ImGuiTextBuffer):hl.Bytes
		return _ImGuiTextBuffer_c_str(self);

	@:hlNative("sfimgui", "ImGuiTextBuffer_clear")
	private static function _ImGuiTextBuffer_clear(self:ImGuiTextBuffer):Void {
	}

	public static inline function ImGuiTextBuffer_clear(self:ImGuiTextBuffer):Void
		_ImGuiTextBuffer_clear(self);

	@:hlNative("sfimgui", "ImGuiTextBuffer_empty")
	private static function _ImGuiTextBuffer_empty(self:ImGuiTextBuffer):Bool {
		return false;
	}

	public static inline function ImGuiTextBuffer_empty(self:ImGuiTextBuffer):Bool
		return _ImGuiTextBuffer_empty(self);

	@:hlNative("sfimgui", "ImGuiTextBuffer_end")
	private static function _ImGuiTextBuffer_end(self:ImGuiTextBuffer):hl.Bytes {
		return null;
	}

	public static inline function ImGuiTextBuffer_end(self:ImGuiTextBuffer):hl.Bytes
		return _ImGuiTextBuffer_end(self);

	@:hlNative("sfimgui", "ImGuiTextBuffer_reserve")
	private static function _ImGuiTextBuffer_reserve(self:ImGuiTextBuffer, capacity:Int):Void {
	}

	public static inline function ImGuiTextBuffer_reserve(self:ImGuiTextBuffer, capacity:Int):Void
		_ImGuiTextBuffer_reserve(self, capacity);

	@:hlNative("sfimgui", "ImGuiTextBuffer_resize")
	private static function _ImGuiTextBuffer_resize(self:ImGuiTextBuffer, size:Int):Void {
	}

	public static inline function ImGuiTextBuffer_resize(self:ImGuiTextBuffer, size:Int):Void
		_ImGuiTextBuffer_resize(self, size);

	@:hlNative("sfimgui", "ImGuiTextBuffer_size")
	private static function _ImGuiTextBuffer_size(self:ImGuiTextBuffer):Int {
		return 0;
	}

	public static inline function ImGuiTextBuffer_size(self:ImGuiTextBuffer):Int
		return _ImGuiTextBuffer_size(self);

	@:hlNative("sfimgui", "ImGuiTextFilter_Build")
	private static function _ImGuiTextFilter_Build(self:ImGuiTextFilter):Void {
	}

	public static inline function ImGuiTextFilter_Build(self:ImGuiTextFilter):Void
		_ImGuiTextFilter_Build(self);

	@:hlNative("sfimgui", "ImGuiTextFilter_Clear")
	private static function _ImGuiTextFilter_Clear(self:ImGuiTextFilter):Void {
	}

	public static inline function ImGuiTextFilter_Clear(self:ImGuiTextFilter):Void
		_ImGuiTextFilter_Clear(self);

	@:hlNative("sfimgui", "ImGuiTextFilter_Draw")
	private static function _ImGuiTextFilter_Draw(self:ImGuiTextFilter, label:hl.Bytes, width:Single):Bool {
		return false;
	}

	public static inline function ImGuiTextFilter_Draw(self:ImGuiTextFilter, label:String = "Filter(inc,-exc)", width:Single = 0.0):Bool
		return _ImGuiTextFilter_Draw(self, cstr(label), width);

	@:hlNative("sfimgui", "ImGuiTextFilter_IsActive")
	private static function _ImGuiTextFilter_IsActive(self:ImGuiTextFilter):Bool {
		return false;
	}

	public static inline function ImGuiTextFilter_IsActive(self:ImGuiTextFilter):Bool
		return _ImGuiTextFilter_IsActive(self);

	@:hlNative("sfimgui", "ImGuiTextFilter_PassFilter")
	private static function _ImGuiTextFilter_PassFilter(self:ImGuiTextFilter, text:hl.Bytes, text_end:hl.Bytes):Bool {
		return false;
	}

	public static inline function ImGuiTextFilter_PassFilter(self:ImGuiTextFilter, text:String):Bool
		return _ImGuiTextFilter_PassFilter(self, cstr(text), null);

	@:hlNative("sfimgui", "ImGuiViewport_GetCenter")
	private static function _ImGuiViewport_GetCenter(self:ImGuiViewport, hlxOut:ImVec2):Void {
	}

	public static inline function ImGuiViewport_GetCenter(self:ImGuiViewport, hlxOut:ImVec2 = null):ImVec2 {
		hlxOut = hlxOut ?? new ImVec2();
		_ImGuiViewport_GetCenter(self, hlxOut);
		return hlxOut;
	}

	@:hlNative("sfimgui", "ImGuiViewport_GetWorkCenter")
	private static function _ImGuiViewport_GetWorkCenter(self:ImGuiViewport, hlxOut:ImVec2):Void {
	}

	public static inline function ImGuiViewport_GetWorkCenter(self:ImGuiViewport, hlxOut:ImVec2 = null):ImVec2 {
		hlxOut = hlxOut ?? new ImVec2();
		_ImGuiViewport_GetWorkCenter(self, hlxOut);
		return hlxOut;
	}

	@:hlNative("sfimgui", "ImTextureData_DestroyPixels")
	private static function _ImTextureData_DestroyPixels(self:ImTextureData):Void {
	}

	public static inline function ImTextureData_DestroyPixels(self:ImTextureData):Void
		_ImTextureData_DestroyPixels(self);

	@:hlNative("sfimgui", "ImTextureData_GetPitch")
	private static function _ImTextureData_GetPitch(self:ImTextureData):Int {
		return 0;
	}

	public static inline function ImTextureData_GetPitch(self:ImTextureData):Int
		return _ImTextureData_GetPitch(self);

	@:hlNative("sfimgui", "ImTextureData_GetSizeInBytes")
	private static function _ImTextureData_GetSizeInBytes(self:ImTextureData):Int {
		return 0;
	}

	public static inline function ImTextureData_GetSizeInBytes(self:ImTextureData):Int
		return _ImTextureData_GetSizeInBytes(self);

	@:hlNative("sfimgui", "ImTextureData_GetTexID")
	private static function _ImTextureData_GetTexID(self:ImTextureData):hl.I64 {
		return 0;
	}

	public static inline function ImTextureData_GetTexID(self:ImTextureData):hl.I64
		return _ImTextureData_GetTexID(self);

	@:hlNative("sfimgui", "ImTextureData_SetTexID")
	private static function _ImTextureData_SetTexID(self:ImTextureData, tex_id:hl.I64):Void {
	}

	public static inline function ImTextureData_SetTexID(self:ImTextureData, texId:hl.I64):Void
		_ImTextureData_SetTexID(self, texId);

	@:hlNative("sfimgui", "ImTextureRef_GetTexID")
	private static function _ImTextureRef_GetTexID(self:ImTextureRef):hl.I64 {
		return 0;
	}

	public static inline function ImTextureRef_GetTexID(self:ImTextureRef):hl.I64
		return _ImTextureRef_GetTexID(self);

	@:hlNative("sfimgui", "igAcceptDragDropPayload")
	private static function _acceptDragDropPayload(type:hl.Bytes, flags:Int):ImGuiPayload {
		return null;
	}

	public static inline function acceptDragDropPayload(type:String, flags:Int = 0):ImGuiPayload
		return _acceptDragDropPayload(cstr(type), flags);

	@:hlNative("sfimgui", "igAlignTextToFramePadding")
	private static function _alignTextToFramePadding():Void {
	}

	public static inline function alignTextToFramePadding():Void
		_alignTextToFramePadding();

	@:hlNative("sfimgui", "igArrowButton")
	private static function _arrowButton(str_id:hl.Bytes, dir:Int):Bool {
		return false;
	}

	public static inline function arrowButton(strId:String, dir:Int):Bool
		return _arrowButton(cstr(strId), dir);

	@:hlNative("sfimgui", "igBegin_Ptr")
	private static function _begin_Ptr(name:hl.Bytes, p_open:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function begin(name:String, open:BoolRef = null, flags:Int = 0):Bool
		return _begin_Ptr(cstr(name), open, flags);

	@:hlNative("sfimgui", "igBeginChild_Str")
	private static function _beginChild_Str(str_id:hl.Bytes, size:ImVec2, child_flags:Int, window_flags:Int):Bool {
		return false;
	}

	public static overload extern inline function beginChild(strId:String, size:ImVec2 = null, childFlags:Int = 0, windowFlags:Int = 0):Bool {
		size = size ?? vec2(0, 0);
		return _beginChild_Str(cstr(strId), size, childFlags, windowFlags);
	}

	@:hlNative("sfimgui", "igBeginChild_ID")
	private static function _beginChild_ID(id:Int, size:ImVec2, child_flags:Int, window_flags:Int):Bool {
		return false;
	}

	public static overload extern inline function beginChild(id:Int, size:ImVec2 = null, childFlags:Int = 0, windowFlags:Int = 0):Bool {
		size = size ?? vec2(0, 0);
		return _beginChild_ID(id, size, childFlags, windowFlags);
	}

	@:hlNative("sfimgui", "igBeginCombo")
	private static function _beginCombo(label:hl.Bytes, preview_value:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function beginCombo(label:String, previewValue:String, flags:Int = 0):Bool
		return _beginCombo(cstr(label), cstr(previewValue), flags);

	@:hlNative("sfimgui", "igBeginDisabled")
	private static function _beginDisabled(disabled:Bool):Void {
	}

	public static inline function beginDisabled(disabled:Bool = true):Void
		_beginDisabled(disabled);

	@:hlNative("sfimgui", "igBeginDragDropSource")
	private static function _beginDragDropSource(flags:Int):Bool {
		return false;
	}

	public static inline function beginDragDropSource(flags:Int = 0):Bool
		return _beginDragDropSource(flags);

	@:hlNative("sfimgui", "igBeginDragDropTarget")
	private static function _beginDragDropTarget():Bool {
		return false;
	}

	public static inline function beginDragDropTarget():Bool
		return _beginDragDropTarget();

	@:hlNative("sfimgui", "igBeginGroup")
	private static function _beginGroup():Void {
	}

	public static inline function beginGroup():Void
		_beginGroup();

	@:hlNative("sfimgui", "igBeginItemTooltip")
	private static function _beginItemTooltip():Bool {
		return false;
	}

	public static inline function beginItemTooltip():Bool
		return _beginItemTooltip();

	@:hlNative("sfimgui", "igBeginListBox")
	private static function _beginListBox(label:hl.Bytes, size:ImVec2):Bool {
		return false;
	}

	public static inline function beginListBox(label:String, size:ImVec2 = null):Bool {
		size = size ?? vec2(0, 0);
		return _beginListBox(cstr(label), size);
	}

	@:hlNative("sfimgui", "igBeginMainMenuBar")
	private static function _beginMainMenuBar():Bool {
		return false;
	}

	public static inline function beginMainMenuBar():Bool
		return _beginMainMenuBar();

	@:hlNative("sfimgui", "igBeginMenu")
	private static function _beginMenu(label:hl.Bytes, enabled:Bool):Bool {
		return false;
	}

	public static inline function beginMenu(label:String, enabled:Bool = true):Bool
		return _beginMenu(cstr(label), enabled);

	@:hlNative("sfimgui", "igBeginMenuBar")
	private static function _beginMenuBar():Bool {
		return false;
	}

	public static inline function beginMenuBar():Bool
		return _beginMenuBar();

	@:hlNative("sfimgui", "igBeginPopup")
	private static function _beginPopup(str_id:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function beginPopup(strId:String, flags:Int = 0):Bool
		return _beginPopup(cstr(strId), flags);

	@:hlNative("sfimgui", "igBeginPopupContextItem")
	private static function _beginPopupContextItem(str_id:hl.Bytes, popup_flags:Int):Bool {
		return false;
	}

	public static inline function beginPopupContextItem(strId:String = null, popupFlags:Int = 0):Bool
		return _beginPopupContextItem(cstr(strId), popupFlags);

	@:hlNative("sfimgui", "igBeginPopupContextVoid")
	private static function _beginPopupContextVoid(str_id:hl.Bytes, popup_flags:Int):Bool {
		return false;
	}

	public static inline function beginPopupContextVoid(strId:String = null, popupFlags:Int = 0):Bool
		return _beginPopupContextVoid(cstr(strId), popupFlags);

	@:hlNative("sfimgui", "igBeginPopupContextWindow")
	private static function _beginPopupContextWindow(str_id:hl.Bytes, popup_flags:Int):Bool {
		return false;
	}

	public static inline function beginPopupContextWindow(strId:String = null, popupFlags:Int = 0):Bool
		return _beginPopupContextWindow(cstr(strId), popupFlags);

	@:hlNative("sfimgui", "igBeginPopupModal_Ptr")
	private static function _beginPopupModal_Ptr(name:hl.Bytes, p_open:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function beginPopupModal(name:String, open:BoolRef = null, flags:Int = 0):Bool
		return _beginPopupModal_Ptr(cstr(name), open, flags);

	@:hlNative("sfimgui", "igBeginTabBar")
	private static function _beginTabBar(str_id:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function beginTabBar(strId:String, flags:Int = 0):Bool
		return _beginTabBar(cstr(strId), flags);

	@:hlNative("sfimgui", "igBeginTabItem_Ptr")
	private static function _beginTabItem_Ptr(label:hl.Bytes, p_open:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function beginTabItem(label:String, open:BoolRef = null, flags:Int = 0):Bool
		return _beginTabItem_Ptr(cstr(label), open, flags);

	@:hlNative("sfimgui", "igBeginTable")
	private static function _beginTable(str_id:hl.Bytes, columns:Int, flags:Int, outer_size:ImVec2, inner_width:Single):Bool {
		return false;
	}

	public static inline function beginTable(strId:String, columns:Int, flags:Int = 0, outerSize:ImVec2 = null, innerWidth:Single = 0.0):Bool {
		outerSize = outerSize ?? vec2(0.0, 0.0);
		return _beginTable(cstr(strId), columns, flags, outerSize, innerWidth);
	}

	@:hlNative("sfimgui", "igBeginTooltip")
	private static function _beginTooltip():Bool {
		return false;
	}

	public static inline function beginTooltip():Bool
		return _beginTooltip();

	@:hlNative("sfimgui", "igBullet")
	private static function _bullet():Void {
	}

	public static inline function bullet():Void
		_bullet();

	@:hlNative("sfimgui", "igBulletText")
	private static function _bulletText(fmt:hl.Bytes):Void {
	}

	public static inline function bulletText(text:String):Void
		_bulletText(cstr(text));

	@:hlNative("sfimgui", "igButton")
	private static function _button(label:hl.Bytes, size:ImVec2):Bool {
		return false;
	}

	public static inline function button(label:String, size:ImVec2 = null):Bool {
		size = size ?? vec2(0, 0);
		return _button(cstr(label), size);
	}

	@:hlNative("sfimgui", "igCalcItemWidth")
	private static function _calcItemWidth():Single {
		return 0;
	}

	public static inline function calcItemWidth():Single
		return _calcItemWidth();

	@:hlNative("sfimgui", "igCalcTextSize")
	private static function _calcTextSize(text:hl.Bytes, text_end:hl.Bytes, hide_text_after_double_hash:Bool, wrap_width:Single, hlxOut:ImVec2):Void {
	}

	public static inline function calcTextSize(text:String, hideTextAfterDoubleHash:Bool = false, wrapWidth:Single = -1.0, hlxOut:ImVec2 = null):ImVec2 {
		hlxOut = hlxOut ?? new ImVec2();
		_calcTextSize(cstr(text), null, hideTextAfterDoubleHash, wrapWidth, hlxOut);
		return hlxOut;
	}

	@:hlNative("sfimgui", "igCheckbox_Ptr")
	private static function _checkbox_Ptr(label:hl.Bytes, v:hl.Bytes):Bool {
		return false;
	}

	public static inline function checkbox(label:String, v:BoolRef):Bool
		return _checkbox_Ptr(cstr(label), v);

	@:hlNative("sfimgui", "igCheckboxFlags_IntPtr_Ptr")
	private static function _checkboxFlags_IntPtr_Ptr(label:hl.Bytes, flags:hl.Bytes, flags_value:Int):Bool {
		return false;
	}

	public static inline function checkboxFlags_IntPtr(label:String, flags:IntRef, flagsValue:Int):Bool
		return _checkboxFlags_IntPtr_Ptr(cstr(label), flags, flagsValue);

	@:hlNative("sfimgui", "igCheckboxFlags_UintPtr_Ptr")
	private static function _checkboxFlags_UintPtr_Ptr(label:hl.Bytes, flags:hl.Bytes, flags_value:Int):Bool {
		return false;
	}

	public static inline function checkboxFlags_UintPtr(label:String, flags:IntRef, flagsValue:Int):Bool
		return _checkboxFlags_UintPtr_Ptr(cstr(label), flags, flagsValue);

	@:hlNative("sfimgui", "igCloseCurrentPopup")
	private static function _closeCurrentPopup():Void {
	}

	public static inline function closeCurrentPopup():Void
		_closeCurrentPopup();

	@:hlNative("sfimgui", "igCollapsingHeader_TreeNodeFlags")
	private static function _collapsingHeader_TreeNodeFlags(label:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static overload extern inline function collapsingHeader(label:String, flags:Int = 0):Bool
		return _collapsingHeader_TreeNodeFlags(cstr(label), flags);

	@:hlNative("sfimgui", "igCollapsingHeader_BoolPtr_Ptr")
	private static function _collapsingHeader_BoolPtr_Ptr(label:hl.Bytes, p_visible:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static overload extern inline function collapsingHeader(label:String, visible:BoolRef, flags:Int = 0):Bool
		return _collapsingHeader_BoolPtr_Ptr(cstr(label), visible, flags);

	@:hlNative("sfimgui", "igColorButton")
	private static function _colorButton(desc_id:hl.Bytes, col:ImVec4, flags:Int, size:ImVec2):Bool {
		return false;
	}

	public static inline function colorButton(descId:String, col:ImVec4, flags:Int = 0, size:ImVec2 = null):Bool {
		size = size ?? vec2(0, 0);
		return _colorButton(cstr(descId), col, flags, size);
	}

	@:hlNative("sfimgui", "igColorConvertFloat4ToU32")
	private static function _colorConvertFloat4ToU32(in_:ImVec4):Int {
		return 0;
	}

	public static inline function colorConvertFloat4ToU32(in_:ImVec4):Int
		return _colorConvertFloat4ToU32(in_);

	@:hlNative("sfimgui", "igColorConvertHSVtoRGB_Ptr")
	private static function _colorConvertHSVtoRGB_Ptr(h:Single, s:Single, v:Single, out_r:hl.Bytes, out_g:hl.Bytes, out_b:hl.Bytes):Void {
	}

	public static inline function colorConvertHSVtoRGB(h:Single, s:Single, v:Single, outR:FloatRef, outG:FloatRef, outB:FloatRef):Void
		_colorConvertHSVtoRGB_Ptr(h, s, v, outR, outG, outB);

	@:hlNative("sfimgui", "igColorConvertRGBtoHSV_Ptr")
	private static function _colorConvertRGBtoHSV_Ptr(r:Single, g:Single, b:Single, out_h:hl.Bytes, out_s:hl.Bytes, out_v:hl.Bytes):Void {
	}

	public static inline function colorConvertRGBtoHSV(r:Single, g:Single, b:Single, outH:FloatRef, outS:FloatRef, outV:FloatRef):Void
		_colorConvertRGBtoHSV_Ptr(r, g, b, outH, outS, outV);

	@:hlNative("sfimgui", "igColorConvertU32ToFloat4")
	private static function _colorConvertU32ToFloat4(in_:Int, hlxOut:ImVec4):Void {
	}

	public static inline function colorConvertU32ToFloat4(in_:Int, hlxOut:ImVec4 = null):ImVec4 {
		hlxOut = hlxOut ?? new ImVec4();
		_colorConvertU32ToFloat4(in_, hlxOut);
		return hlxOut;
	}

	@:hlNative("sfimgui", "igColorEdit3")
	private static function _colorEdit3(label:hl.Bytes, col:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function colorEdit3(label:String, col:hl.Bytes, flags:Int = 0):Bool
		return _colorEdit3(cstr(label), col, flags);

	@:hlNative("sfimgui", "igColorEdit4")
	private static function _colorEdit4(label:hl.Bytes, col:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function colorEdit4(label:String, col:hl.Bytes, flags:Int = 0):Bool
		return _colorEdit4(cstr(label), col, flags);

	@:hlNative("sfimgui", "igColorPicker3")
	private static function _colorPicker3(label:hl.Bytes, col:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function colorPicker3(label:String, col:hl.Bytes, flags:Int = 0):Bool
		return _colorPicker3(cstr(label), col, flags);

	@:hlNative("sfimgui", "igColorPicker4")
	private static function _colorPicker4(label:hl.Bytes, col:hl.Bytes, flags:Int, ref_col:hl.Bytes):Bool {
		return false;
	}

	public static inline function colorPicker4(label:String, col:hl.Bytes, flags:Int = 0, refCol:hl.Bytes = null):Bool
		return _colorPicker4(cstr(label), col, flags, refCol);

	@:hlNative("sfimgui", "igColumns")
	private static function _columns(count:Int, id:hl.Bytes, borders:Bool):Void {
	}

	public static inline function columns(count:Int = 1, id:String = null, borders:Bool = true):Void
		_columns(count, cstr(id), borders);

	@:hlNative("sfimgui", "igCombo_Str_Ptr")
	private static function _combo_Str_Ptr(label:hl.Bytes, current_item:hl.Bytes, items_separated_by_zeros:hl.Bytes, popup_max_height_in_items:Int):Bool {
		return false;
	}

	public static inline function combo(label:String, currentItem:IntRef, itemsSeparatedByZeros:String, popupMaxHeightInItems:Int = -1):Bool
		return _combo_Str_Ptr(cstr(label), currentItem, cstr(itemsSeparatedByZeros), popupMaxHeightInItems);

	@:hlNative("sfimgui", "igCreateContext")
	private static function _createContext(shared_font_atlas:ImFontAtlas):ImGuiContext {
		return null;
	}

	public static inline function createContext(sharedFontAtlas:ImFontAtlas = null):ImGuiContext
		return _createContext(sharedFontAtlas);

	@:hlNative("sfimgui", "igDebugCheckVersionAndDataLayout")
	private static function _debugCheckVersionAndDataLayout(version_str:hl.Bytes, sz_io:hl.I64, sz_style:hl.I64, sz_vec2:hl.I64, sz_vec4:hl.I64, sz_drawvert:hl.I64, sz_drawidx:hl.I64):Bool {
		return false;
	}

	public static inline function debugCheckVersionAndDataLayout(versionStr:String, szIo:hl.I64, szStyle:hl.I64, szVec2:hl.I64, szVec4:hl.I64, szDrawvert:hl.I64, szDrawidx:hl.I64):Bool
		return _debugCheckVersionAndDataLayout(cstr(versionStr), szIo, szStyle, szVec2, szVec4, szDrawvert, szDrawidx);

	@:hlNative("sfimgui", "igDebugFlashStyleColor")
	private static function _debugFlashStyleColor(idx:Int):Void {
	}

	public static inline function debugFlashStyleColor(idx:Int):Void
		_debugFlashStyleColor(idx);

	@:hlNative("sfimgui", "igDebugLog")
	private static function _debugLog(fmt:hl.Bytes):Void {
	}

	public static inline function debugLog(text:String):Void
		_debugLog(cstr(text));

	@:hlNative("sfimgui", "igDebugStartItemPicker")
	private static function _debugStartItemPicker():Void {
	}

	public static inline function debugStartItemPicker():Void
		_debugStartItemPicker();

	@:hlNative("sfimgui", "igDebugTextEncoding")
	private static function _debugTextEncoding(text:hl.Bytes):Void {
	}

	public static inline function debugTextEncoding(text:String):Void
		_debugTextEncoding(cstr(text));

	@:hlNative("sfimgui", "igDestroyContext")
	private static function _destroyContext(ctx:ImGuiContext):Void {
	}

	public static inline function destroyContext(ctx:ImGuiContext = null):Void
		_destroyContext(ctx);

	@:hlNative("sfimgui", "igDragFloat_Ptr")
	private static function _dragFloat_Ptr(label:hl.Bytes, v:hl.Bytes, v_speed:Single, v_min:Single, v_max:Single, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function dragFloat(label:String, v:FloatRef, vSpeed:Single = 1.0, vMin:Single = 0.0, vMax:Single = 0.0, format:String = "%.3f", flags:Int = 0):Bool
		return _dragFloat_Ptr(cstr(label), v, vSpeed, vMin, vMax, cstr(format), flags);

	@:hlNative("sfimgui", "igDragFloat2")
	private static function _dragFloat2(label:hl.Bytes, v:hl.Bytes, v_speed:Single, v_min:Single, v_max:Single, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function dragFloat2(label:String, v:hl.Bytes, vSpeed:Single = 1.0, vMin:Single = 0.0, vMax:Single = 0.0, format:String = "%.3f", flags:Int = 0):Bool
		return _dragFloat2(cstr(label), v, vSpeed, vMin, vMax, cstr(format), flags);

	@:hlNative("sfimgui", "igDragFloat3")
	private static function _dragFloat3(label:hl.Bytes, v:hl.Bytes, v_speed:Single, v_min:Single, v_max:Single, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function dragFloat3(label:String, v:hl.Bytes, vSpeed:Single = 1.0, vMin:Single = 0.0, vMax:Single = 0.0, format:String = "%.3f", flags:Int = 0):Bool
		return _dragFloat3(cstr(label), v, vSpeed, vMin, vMax, cstr(format), flags);

	@:hlNative("sfimgui", "igDragFloat4")
	private static function _dragFloat4(label:hl.Bytes, v:hl.Bytes, v_speed:Single, v_min:Single, v_max:Single, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function dragFloat4(label:String, v:hl.Bytes, vSpeed:Single = 1.0, vMin:Single = 0.0, vMax:Single = 0.0, format:String = "%.3f", flags:Int = 0):Bool
		return _dragFloat4(cstr(label), v, vSpeed, vMin, vMax, cstr(format), flags);

	@:hlNative("sfimgui", "igDragFloatRange2_Ptr")
	private static function _dragFloatRange2_Ptr(label:hl.Bytes, v_current_min:hl.Bytes, v_current_max:hl.Bytes, v_speed:Single, v_min:Single, v_max:Single, format:hl.Bytes, format_max:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function dragFloatRange2(label:String, vCurrentMin:FloatRef, vCurrentMax:FloatRef, vSpeed:Single = 1.0, vMin:Single = 0.0, vMax:Single = 0.0, format:String = "%.3f", formatMax:String = null, flags:Int = 0):Bool
		return _dragFloatRange2_Ptr(cstr(label), vCurrentMin, vCurrentMax, vSpeed, vMin, vMax, cstr(format), cstr(formatMax), flags);

	@:hlNative("sfimgui", "igDragInt_Ptr")
	private static function _dragInt_Ptr(label:hl.Bytes, v:hl.Bytes, v_speed:Single, v_min:Int, v_max:Int, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function dragInt(label:String, v:IntRef, vSpeed:Single = 1.0, vMin:Int = 0, vMax:Int = 0, format:String = "%d", flags:Int = 0):Bool
		return _dragInt_Ptr(cstr(label), v, vSpeed, vMin, vMax, cstr(format), flags);

	@:hlNative("sfimgui", "igDragInt2")
	private static function _dragInt2(label:hl.Bytes, v:hl.Bytes, v_speed:Single, v_min:Int, v_max:Int, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function dragInt2(label:String, v:hl.Bytes, vSpeed:Single = 1.0, vMin:Int = 0, vMax:Int = 0, format:String = "%d", flags:Int = 0):Bool
		return _dragInt2(cstr(label), v, vSpeed, vMin, vMax, cstr(format), flags);

	@:hlNative("sfimgui", "igDragInt3")
	private static function _dragInt3(label:hl.Bytes, v:hl.Bytes, v_speed:Single, v_min:Int, v_max:Int, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function dragInt3(label:String, v:hl.Bytes, vSpeed:Single = 1.0, vMin:Int = 0, vMax:Int = 0, format:String = "%d", flags:Int = 0):Bool
		return _dragInt3(cstr(label), v, vSpeed, vMin, vMax, cstr(format), flags);

	@:hlNative("sfimgui", "igDragInt4")
	private static function _dragInt4(label:hl.Bytes, v:hl.Bytes, v_speed:Single, v_min:Int, v_max:Int, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function dragInt4(label:String, v:hl.Bytes, vSpeed:Single = 1.0, vMin:Int = 0, vMax:Int = 0, format:String = "%d", flags:Int = 0):Bool
		return _dragInt4(cstr(label), v, vSpeed, vMin, vMax, cstr(format), flags);

	@:hlNative("sfimgui", "igDragIntRange2_Ptr")
	private static function _dragIntRange2_Ptr(label:hl.Bytes, v_current_min:hl.Bytes, v_current_max:hl.Bytes, v_speed:Single, v_min:Int, v_max:Int, format:hl.Bytes, format_max:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function dragIntRange2(label:String, vCurrentMin:IntRef, vCurrentMax:IntRef, vSpeed:Single = 1.0, vMin:Int = 0, vMax:Int = 0, format:String = "%d", formatMax:String = null, flags:Int = 0):Bool
		return _dragIntRange2_Ptr(cstr(label), vCurrentMin, vCurrentMax, vSpeed, vMin, vMax, cstr(format), cstr(formatMax), flags);

	@:hlNative("sfimgui", "igDummy")
	private static function _dummy(size:ImVec2):Void {
	}

	public static inline function dummy(size:ImVec2):Void
		_dummy(size);

	@:hlNative("sfimgui", "igEnd")
	private static function _end():Void {
	}

	public static inline function end():Void
		_end();

	@:hlNative("sfimgui", "igEndChild")
	private static function _endChild():Void {
	}

	public static inline function endChild():Void
		_endChild();

	@:hlNative("sfimgui", "igEndCombo")
	private static function _endCombo():Void {
	}

	public static inline function endCombo():Void
		_endCombo();

	@:hlNative("sfimgui", "igEndDisabled")
	private static function _endDisabled():Void {
	}

	public static inline function endDisabled():Void
		_endDisabled();

	@:hlNative("sfimgui", "igEndDragDropSource")
	private static function _endDragDropSource():Void {
	}

	public static inline function endDragDropSource():Void
		_endDragDropSource();

	@:hlNative("sfimgui", "igEndDragDropTarget")
	private static function _endDragDropTarget():Void {
	}

	public static inline function endDragDropTarget():Void
		_endDragDropTarget();

	@:hlNative("sfimgui", "igEndFrame")
	private static function _endFrame():Void {
	}

	public static inline function endFrame():Void
		_endFrame();

	@:hlNative("sfimgui", "igEndGroup")
	private static function _endGroup():Void {
	}

	public static inline function endGroup():Void
		_endGroup();

	@:hlNative("sfimgui", "igEndListBox")
	private static function _endListBox():Void {
	}

	public static inline function endListBox():Void
		_endListBox();

	@:hlNative("sfimgui", "igEndMainMenuBar")
	private static function _endMainMenuBar():Void {
	}

	public static inline function endMainMenuBar():Void
		_endMainMenuBar();

	@:hlNative("sfimgui", "igEndMenu")
	private static function _endMenu():Void {
	}

	public static inline function endMenu():Void
		_endMenu();

	@:hlNative("sfimgui", "igEndMenuBar")
	private static function _endMenuBar():Void {
	}

	public static inline function endMenuBar():Void
		_endMenuBar();

	@:hlNative("sfimgui", "igEndPopup")
	private static function _endPopup():Void {
	}

	public static inline function endPopup():Void
		_endPopup();

	@:hlNative("sfimgui", "igEndTabBar")
	private static function _endTabBar():Void {
	}

	public static inline function endTabBar():Void
		_endTabBar();

	@:hlNative("sfimgui", "igEndTabItem")
	private static function _endTabItem():Void {
	}

	public static inline function endTabItem():Void
		_endTabItem();

	@:hlNative("sfimgui", "igEndTable")
	private static function _endTable():Void {
	}

	public static inline function endTable():Void
		_endTable();

	@:hlNative("sfimgui", "igEndTooltip")
	private static function _endTooltip():Void {
	}

	public static inline function endTooltip():Void
		_endTooltip();

	@:hlNative("sfimgui", "igGetBackgroundDrawList_Nil")
	private static function _getBackgroundDrawList_Nil():ImDrawList {
		return null;
	}

	public static inline function getBackgroundDrawList():ImDrawList
		return _getBackgroundDrawList_Nil();

	@:hlNative("sfimgui", "igGetClipboardText")
	private static function _getClipboardText():hl.Bytes {
		return null;
	}

	public static inline function getClipboardText():hl.Bytes
		return _getClipboardText();

	@:hlNative("sfimgui", "igGetColorU32_Col")
	private static function _getColorU32_Col(idx:Int, alpha_mul:Single):Int {
		return 0;
	}

	public static inline function getColorU32_Col(idx:Int, alphaMul:Single = 1.0):Int
		return _getColorU32_Col(idx, alphaMul);

	@:hlNative("sfimgui", "igGetColorU32_Vec4")
	private static function _getColorU32_Vec4(col:ImVec4):Int {
		return 0;
	}

	public static inline function getColorU32_Vec4(col:ImVec4):Int
		return _getColorU32_Vec4(col);

	@:hlNative("sfimgui", "igGetColorU32_U32")
	private static function _getColorU32_U32(col:Int, alpha_mul:Single):Int {
		return 0;
	}

	public static inline function getColorU32_U32(col:Int, alphaMul:Single = 1.0):Int
		return _getColorU32_U32(col, alphaMul);

	@:hlNative("sfimgui", "igGetColumnIndex")
	private static function _getColumnIndex():Int {
		return 0;
	}

	public static inline function getColumnIndex():Int
		return _getColumnIndex();

	@:hlNative("sfimgui", "igGetColumnOffset")
	private static function _getColumnOffset(column_index:Int):Single {
		return 0;
	}

	public static inline function getColumnOffset(columnIndex:Int = -1):Single
		return _getColumnOffset(columnIndex);

	@:hlNative("sfimgui", "igGetColumnWidth")
	private static function _getColumnWidth(column_index:Int):Single {
		return 0;
	}

	public static inline function getColumnWidth(columnIndex:Int = -1):Single
		return _getColumnWidth(columnIndex);

	@:hlNative("sfimgui", "igGetColumnsCount")
	private static function _getColumnsCount():Int {
		return 0;
	}

	public static inline function getColumnsCount():Int
		return _getColumnsCount();

	@:hlNative("sfimgui", "igGetContentRegionAvail")
	private static function _getContentRegionAvail(hlxOut:ImVec2):Void {
	}

	public static inline function getContentRegionAvail(hlxOut:ImVec2 = null):ImVec2 {
		hlxOut = hlxOut ?? new ImVec2();
		_getContentRegionAvail(hlxOut);
		return hlxOut;
	}

	@:hlNative("sfimgui", "igGetCurrentContext")
	private static function _getCurrentContext():ImGuiContext {
		return null;
	}

	public static inline function getCurrentContext():ImGuiContext
		return _getCurrentContext();

	@:hlNative("sfimgui", "igGetCursorPos")
	private static function _getCursorPos(hlxOut:ImVec2):Void {
	}

	public static inline function getCursorPos(hlxOut:ImVec2 = null):ImVec2 {
		hlxOut = hlxOut ?? new ImVec2();
		_getCursorPos(hlxOut);
		return hlxOut;
	}

	@:hlNative("sfimgui", "igGetCursorPosX")
	private static function _getCursorPosX():Single {
		return 0;
	}

	public static inline function getCursorPosX():Single
		return _getCursorPosX();

	@:hlNative("sfimgui", "igGetCursorPosY")
	private static function _getCursorPosY():Single {
		return 0;
	}

	public static inline function getCursorPosY():Single
		return _getCursorPosY();

	@:hlNative("sfimgui", "igGetCursorScreenPos")
	private static function _getCursorScreenPos(hlxOut:ImVec2):Void {
	}

	public static inline function getCursorScreenPos(hlxOut:ImVec2 = null):ImVec2 {
		hlxOut = hlxOut ?? new ImVec2();
		_getCursorScreenPos(hlxOut);
		return hlxOut;
	}

	@:hlNative("sfimgui", "igGetCursorStartPos")
	private static function _getCursorStartPos(hlxOut:ImVec2):Void {
	}

	public static inline function getCursorStartPos(hlxOut:ImVec2 = null):ImVec2 {
		hlxOut = hlxOut ?? new ImVec2();
		_getCursorStartPos(hlxOut);
		return hlxOut;
	}

	@:hlNative("sfimgui", "igGetDragDropPayload")
	private static function _getDragDropPayload():ImGuiPayload {
		return null;
	}

	public static inline function getDragDropPayload():ImGuiPayload
		return _getDragDropPayload();

	@:hlNative("sfimgui", "igGetDrawData")
	private static function _getDrawData():ImDrawData {
		return null;
	}

	public static inline function getDrawData():ImDrawData
		return _getDrawData();

	@:hlNative("sfimgui", "igGetDrawListSharedData")
	private static function _getDrawListSharedData():ImDrawListSharedData {
		return null;
	}

	public static inline function getDrawListSharedData():ImDrawListSharedData
		return _getDrawListSharedData();

	@:hlNative("sfimgui", "igGetFont")
	private static function _getFont():ImFont {
		return null;
	}

	public static inline function getFont():ImFont
		return _getFont();

	@:hlNative("sfimgui", "igGetFontBaked")
	private static function _getFontBaked():ImFontBaked {
		return null;
	}

	public static inline function getFontBaked():ImFontBaked
		return _getFontBaked();

	@:hlNative("sfimgui", "igGetFontSize")
	private static function _getFontSize():Single {
		return 0;
	}

	public static inline function getFontSize():Single
		return _getFontSize();

	@:hlNative("sfimgui", "igGetFontTexUvWhitePixel")
	private static function _getFontTexUvWhitePixel(hlxOut:ImVec2):Void {
	}

	public static inline function getFontTexUvWhitePixel(hlxOut:ImVec2 = null):ImVec2 {
		hlxOut = hlxOut ?? new ImVec2();
		_getFontTexUvWhitePixel(hlxOut);
		return hlxOut;
	}

	@:hlNative("sfimgui", "igGetForegroundDrawList_Nil")
	private static function _getForegroundDrawList_Nil():ImDrawList {
		return null;
	}

	public static inline function getForegroundDrawList():ImDrawList
		return _getForegroundDrawList_Nil();

	@:hlNative("sfimgui", "igGetFrameCount")
	private static function _getFrameCount():Int {
		return 0;
	}

	public static inline function getFrameCount():Int
		return _getFrameCount();

	@:hlNative("sfimgui", "igGetFrameHeight")
	private static function _getFrameHeight():Single {
		return 0;
	}

	public static inline function getFrameHeight():Single
		return _getFrameHeight();

	@:hlNative("sfimgui", "igGetFrameHeightWithSpacing")
	private static function _getFrameHeightWithSpacing():Single {
		return 0;
	}

	public static inline function getFrameHeightWithSpacing():Single
		return _getFrameHeightWithSpacing();

	@:hlNative("sfimgui", "igGetID_Str")
	private static function _getID_Str(str_id:hl.Bytes):Int {
		return 0;
	}

	public static inline function getID_Str(strId:String):Int
		return _getID_Str(cstr(strId));

	@:hlNative("sfimgui", "igGetID_StrStr")
	private static function _getID_StrStr(str_id_begin:hl.Bytes, str_id_end:hl.Bytes):Int {
		return 0;
	}

	public static inline function getID_StrStr(strId:String):Int
		return _getID_StrStr(cstr(strId), null);

	@:hlNative("sfimgui", "igGetID_Int")
	private static function _getID_Int(int_id:Int):Int {
		return 0;
	}

	public static inline function getID_Int(intId:Int):Int
		return _getID_Int(intId);

	@:hlNative("sfimgui", "igGetIO_Nil")
	private static function _getIO_Nil():ImGuiIO {
		return null;
	}

	public static inline function getIO():ImGuiIO
		return _getIO_Nil();

	@:hlNative("sfimgui", "igGetItemClickedCountWithSingleClickDelay")
	private static function _getItemClickedCountWithSingleClickDelay(mouse_button:Int, delay:Single):Int {
		return 0;
	}

	public static inline function getItemClickedCountWithSingleClickDelay(mouseButton:Int = 0, delay:Single = -1.0):Int
		return _getItemClickedCountWithSingleClickDelay(mouseButton, delay);

	@:hlNative("sfimgui", "igGetItemFlags")
	private static function _getItemFlags():Int {
		return 0;
	}

	public static inline function getItemFlags():Int
		return _getItemFlags();

	@:hlNative("sfimgui", "igGetItemID")
	private static function _getItemID():Int {
		return 0;
	}

	public static inline function getItemID():Int
		return _getItemID();

	@:hlNative("sfimgui", "igGetItemRectMax")
	private static function _getItemRectMax(hlxOut:ImVec2):Void {
	}

	public static inline function getItemRectMax(hlxOut:ImVec2 = null):ImVec2 {
		hlxOut = hlxOut ?? new ImVec2();
		_getItemRectMax(hlxOut);
		return hlxOut;
	}

	@:hlNative("sfimgui", "igGetItemRectMin")
	private static function _getItemRectMin(hlxOut:ImVec2):Void {
	}

	public static inline function getItemRectMin(hlxOut:ImVec2 = null):ImVec2 {
		hlxOut = hlxOut ?? new ImVec2();
		_getItemRectMin(hlxOut);
		return hlxOut;
	}

	@:hlNative("sfimgui", "igGetItemRectSize")
	private static function _getItemRectSize(hlxOut:ImVec2):Void {
	}

	public static inline function getItemRectSize(hlxOut:ImVec2 = null):ImVec2 {
		hlxOut = hlxOut ?? new ImVec2();
		_getItemRectSize(hlxOut);
		return hlxOut;
	}

	@:hlNative("sfimgui", "igGetKeyName")
	private static function _getKeyName(key:Int):hl.Bytes {
		return null;
	}

	public static inline function getKeyName(key:Int):hl.Bytes
		return _getKeyName(key);

	@:hlNative("sfimgui", "igGetKeyPressedAmount")
	private static function _getKeyPressedAmount(key:Int, repeat_delay:Single, rate:Single):Int {
		return 0;
	}

	public static inline function getKeyPressedAmount(key:Int, repeatDelay:Single, rate:Single):Int
		return _getKeyPressedAmount(key, repeatDelay, rate);

	@:hlNative("sfimgui", "igGetMainViewport")
	private static function _getMainViewport():ImGuiViewport {
		return null;
	}

	public static inline function getMainViewport():ImGuiViewport
		return _getMainViewport();

	@:hlNative("sfimgui", "igGetMouseClickedCount")
	private static function _getMouseClickedCount(button:Int):Int {
		return 0;
	}

	public static inline function getMouseClickedCount(button:Int):Int
		return _getMouseClickedCount(button);

	@:hlNative("sfimgui", "igGetMouseCursor")
	private static function _getMouseCursor():Int {
		return 0;
	}

	public static inline function getMouseCursor():Int
		return _getMouseCursor();

	@:hlNative("sfimgui", "igGetMouseDragDelta")
	private static function _getMouseDragDelta(button:Int, lock_threshold:Single, hlxOut:ImVec2):Void {
	}

	public static inline function getMouseDragDelta(button:Int = 0, lockThreshold:Single = -1.0, hlxOut:ImVec2 = null):ImVec2 {
		hlxOut = hlxOut ?? new ImVec2();
		_getMouseDragDelta(button, lockThreshold, hlxOut);
		return hlxOut;
	}

	@:hlNative("sfimgui", "igGetMousePos")
	private static function _getMousePos(hlxOut:ImVec2):Void {
	}

	public static inline function getMousePos(hlxOut:ImVec2 = null):ImVec2 {
		hlxOut = hlxOut ?? new ImVec2();
		_getMousePos(hlxOut);
		return hlxOut;
	}

	@:hlNative("sfimgui", "igGetMousePosOnOpeningCurrentPopup")
	private static function _getMousePosOnOpeningCurrentPopup(hlxOut:ImVec2):Void {
	}

	public static inline function getMousePosOnOpeningCurrentPopup(hlxOut:ImVec2 = null):ImVec2 {
		hlxOut = hlxOut ?? new ImVec2();
		_getMousePosOnOpeningCurrentPopup(hlxOut);
		return hlxOut;
	}

	@:hlNative("sfimgui", "igGetPlatformIO_Nil")
	private static function _getPlatformIO_Nil():ImGuiPlatformIO {
		return null;
	}

	public static inline function getPlatformIO():ImGuiPlatformIO
		return _getPlatformIO_Nil();

	@:hlNative("sfimgui", "igGetScrollMaxX")
	private static function _getScrollMaxX():Single {
		return 0;
	}

	public static inline function getScrollMaxX():Single
		return _getScrollMaxX();

	@:hlNative("sfimgui", "igGetScrollMaxY")
	private static function _getScrollMaxY():Single {
		return 0;
	}

	public static inline function getScrollMaxY():Single
		return _getScrollMaxY();

	@:hlNative("sfimgui", "igGetScrollX")
	private static function _getScrollX():Single {
		return 0;
	}

	public static inline function getScrollX():Single
		return _getScrollX();

	@:hlNative("sfimgui", "igGetScrollY")
	private static function _getScrollY():Single {
		return 0;
	}

	public static inline function getScrollY():Single
		return _getScrollY();

	@:hlNative("sfimgui", "igGetStyle")
	private static function _getStyle():ImGuiStyle {
		return null;
	}

	public static inline function getStyle():ImGuiStyle
		return _getStyle();

	@:hlNative("sfimgui", "igGetStyleColorName")
	private static function _getStyleColorName(idx:Int):hl.Bytes {
		return null;
	}

	public static inline function getStyleColorName(idx:Int):hl.Bytes
		return _getStyleColorName(idx);

	@:hlNative("sfimgui", "igGetTextLineHeight")
	private static function _getTextLineHeight():Single {
		return 0;
	}

	public static inline function getTextLineHeight():Single
		return _getTextLineHeight();

	@:hlNative("sfimgui", "igGetTextLineHeightWithSpacing")
	private static function _getTextLineHeightWithSpacing():Single {
		return 0;
	}

	public static inline function getTextLineHeightWithSpacing():Single
		return _getTextLineHeightWithSpacing();

	@:hlNative("sfimgui", "igGetTime")
	private static function _getTime():Float {
		return 0;
	}

	public static inline function getTime():Float
		return _getTime();

	@:hlNative("sfimgui", "igGetTreeNodeToLabelSpacing")
	private static function _getTreeNodeToLabelSpacing():Single {
		return 0;
	}

	public static inline function getTreeNodeToLabelSpacing():Single
		return _getTreeNodeToLabelSpacing();

	@:hlNative("sfimgui", "igGetVersion")
	private static function _getVersion():hl.Bytes {
		return null;
	}

	public static inline function getVersion():hl.Bytes
		return _getVersion();

	@:hlNative("sfimgui", "igGetWindowDrawList")
	private static function _getWindowDrawList():ImDrawList {
		return null;
	}

	public static inline function getWindowDrawList():ImDrawList
		return _getWindowDrawList();

	@:hlNative("sfimgui", "igGetWindowHeight")
	private static function _getWindowHeight():Single {
		return 0;
	}

	public static inline function getWindowHeight():Single
		return _getWindowHeight();

	@:hlNative("sfimgui", "igGetWindowPos")
	private static function _getWindowPos(hlxOut:ImVec2):Void {
	}

	public static inline function getWindowPos(hlxOut:ImVec2 = null):ImVec2 {
		hlxOut = hlxOut ?? new ImVec2();
		_getWindowPos(hlxOut);
		return hlxOut;
	}

	@:hlNative("sfimgui", "igGetWindowSize")
	private static function _getWindowSize(hlxOut:ImVec2):Void {
	}

	public static inline function getWindowSize(hlxOut:ImVec2 = null):ImVec2 {
		hlxOut = hlxOut ?? new ImVec2();
		_getWindowSize(hlxOut);
		return hlxOut;
	}

	@:hlNative("sfimgui", "igGetWindowWidth")
	private static function _getWindowWidth():Single {
		return 0;
	}

	public static inline function getWindowWidth():Single
		return _getWindowWidth();

	@:hlNative("sfimgui", "igIndent")
	private static function _indent(indent_w:Single):Void {
	}

	public static inline function indent(indentW:Single = 0.0):Void
		_indent(indentW);

	@:hlNative("sfimgui", "igInputDouble_Ptr")
	private static function _inputDouble_Ptr(label:hl.Bytes, v:hl.Bytes, step:Float, step_fast:Float, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function inputDouble(label:String, v:DoubleRef, step:Float = 0.0, stepFast:Float = 0.0, format:String = "%.6f", flags:Int = 0):Bool
		return _inputDouble_Ptr(cstr(label), v, step, stepFast, cstr(format), flags);

	@:hlNative("sfimgui", "igInputFloat_Ptr")
	private static function _inputFloat_Ptr(label:hl.Bytes, v:hl.Bytes, step:Single, step_fast:Single, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function inputFloat(label:String, v:FloatRef, step:Single = 0.0, stepFast:Single = 0.0, format:String = "%.3f", flags:Int = 0):Bool
		return _inputFloat_Ptr(cstr(label), v, step, stepFast, cstr(format), flags);

	@:hlNative("sfimgui", "igInputFloat2")
	private static function _inputFloat2(label:hl.Bytes, v:hl.Bytes, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function inputFloat2(label:String, v:hl.Bytes, format:String = "%.3f", flags:Int = 0):Bool
		return _inputFloat2(cstr(label), v, cstr(format), flags);

	@:hlNative("sfimgui", "igInputFloat3")
	private static function _inputFloat3(label:hl.Bytes, v:hl.Bytes, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function inputFloat3(label:String, v:hl.Bytes, format:String = "%.3f", flags:Int = 0):Bool
		return _inputFloat3(cstr(label), v, cstr(format), flags);

	@:hlNative("sfimgui", "igInputFloat4")
	private static function _inputFloat4(label:hl.Bytes, v:hl.Bytes, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function inputFloat4(label:String, v:hl.Bytes, format:String = "%.3f", flags:Int = 0):Bool
		return _inputFloat4(cstr(label), v, cstr(format), flags);

	@:hlNative("sfimgui", "igInputInt_Ptr")
	private static function _inputInt_Ptr(label:hl.Bytes, v:hl.Bytes, step:Int, step_fast:Int, flags:Int):Bool {
		return false;
	}

	public static inline function inputInt(label:String, v:IntRef, step:Int = 1, stepFast:Int = 100, flags:Int = 0):Bool
		return _inputInt_Ptr(cstr(label), v, step, stepFast, flags);

	@:hlNative("sfimgui", "igInputInt2")
	private static function _inputInt2(label:hl.Bytes, v:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function inputInt2(label:String, v:hl.Bytes, flags:Int = 0):Bool
		return _inputInt2(cstr(label), v, flags);

	@:hlNative("sfimgui", "igInputInt3")
	private static function _inputInt3(label:hl.Bytes, v:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function inputInt3(label:String, v:hl.Bytes, flags:Int = 0):Bool
		return _inputInt3(cstr(label), v, flags);

	@:hlNative("sfimgui", "igInputInt4")
	private static function _inputInt4(label:hl.Bytes, v:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function inputInt4(label:String, v:hl.Bytes, flags:Int = 0):Bool
		return _inputInt4(cstr(label), v, flags);

	@:hlNative("sfimgui", "igInputText")
	private static function _inputText(label:hl.Bytes, buf:hl.Bytes, buf_size:hl.I64, flags:Int):Bool {
		return false;
	}

	public static inline function inputText(label:String, buf:hl.Bytes, bufSize:hl.I64, flags:Int = 0):Bool
		return _inputText(cstr(label), buf, bufSize, flags);

	@:hlNative("sfimgui", "igInputTextMultiline")
	private static function _inputTextMultiline(label:hl.Bytes, buf:hl.Bytes, buf_size:hl.I64, size:ImVec2, flags:Int):Bool {
		return false;
	}

	public static inline function inputTextMultiline(label:String, buf:hl.Bytes, bufSize:hl.I64, size:ImVec2 = null, flags:Int = 0):Bool {
		size = size ?? vec2(0, 0);
		return _inputTextMultiline(cstr(label), buf, bufSize, size, flags);
	}

	@:hlNative("sfimgui", "igInputTextWithHint")
	private static function _inputTextWithHint(label:hl.Bytes, hint:hl.Bytes, buf:hl.Bytes, buf_size:hl.I64, flags:Int):Bool {
		return false;
	}

	public static inline function inputTextWithHint(label:String, hint:String, buf:hl.Bytes, bufSize:hl.I64, flags:Int = 0):Bool
		return _inputTextWithHint(cstr(label), cstr(hint), buf, bufSize, flags);

	@:hlNative("sfimgui", "igInvisibleButton")
	private static function _invisibleButton(str_id:hl.Bytes, size:ImVec2, flags:Int):Bool {
		return false;
	}

	public static inline function invisibleButton(strId:String, size:ImVec2, flags:Int = 0):Bool
		return _invisibleButton(cstr(strId), size, flags);

	@:hlNative("sfimgui", "igIsAnyItemActive")
	private static function _isAnyItemActive():Bool {
		return false;
	}

	public static inline function isAnyItemActive():Bool
		return _isAnyItemActive();

	@:hlNative("sfimgui", "igIsAnyItemFocused")
	private static function _isAnyItemFocused():Bool {
		return false;
	}

	public static inline function isAnyItemFocused():Bool
		return _isAnyItemFocused();

	@:hlNative("sfimgui", "igIsAnyItemHovered")
	private static function _isAnyItemHovered():Bool {
		return false;
	}

	public static inline function isAnyItemHovered():Bool
		return _isAnyItemHovered();

	@:hlNative("sfimgui", "igIsAnyMouseDown")
	private static function _isAnyMouseDown():Bool {
		return false;
	}

	public static inline function isAnyMouseDown():Bool
		return _isAnyMouseDown();

	@:hlNative("sfimgui", "igIsItemActivated")
	private static function _isItemActivated():Bool {
		return false;
	}

	public static inline function isItemActivated():Bool
		return _isItemActivated();

	@:hlNative("sfimgui", "igIsItemActive")
	private static function _isItemActive():Bool {
		return false;
	}

	public static inline function isItemActive():Bool
		return _isItemActive();

	@:hlNative("sfimgui", "igIsItemClicked")
	private static function _isItemClicked(mouse_button:Int):Bool {
		return false;
	}

	public static inline function isItemClicked(mouseButton:Int = 0):Bool
		return _isItemClicked(mouseButton);

	@:hlNative("sfimgui", "igIsItemDeactivated")
	private static function _isItemDeactivated():Bool {
		return false;
	}

	public static inline function isItemDeactivated():Bool
		return _isItemDeactivated();

	@:hlNative("sfimgui", "igIsItemDeactivatedAfterEdit")
	private static function _isItemDeactivatedAfterEdit():Bool {
		return false;
	}

	public static inline function isItemDeactivatedAfterEdit():Bool
		return _isItemDeactivatedAfterEdit();

	@:hlNative("sfimgui", "igIsItemEdited")
	private static function _isItemEdited():Bool {
		return false;
	}

	public static inline function isItemEdited():Bool
		return _isItemEdited();

	@:hlNative("sfimgui", "igIsItemFocused")
	private static function _isItemFocused():Bool {
		return false;
	}

	public static inline function isItemFocused():Bool
		return _isItemFocused();

	@:hlNative("sfimgui", "igIsItemHovered")
	private static function _isItemHovered(flags:Int):Bool {
		return false;
	}

	public static inline function isItemHovered(flags:Int = 0):Bool
		return _isItemHovered(flags);

	@:hlNative("sfimgui", "igIsItemToggledOpen")
	private static function _isItemToggledOpen():Bool {
		return false;
	}

	public static inline function isItemToggledOpen():Bool
		return _isItemToggledOpen();

	@:hlNative("sfimgui", "igIsItemToggledSelection")
	private static function _isItemToggledSelection():Bool {
		return false;
	}

	public static inline function isItemToggledSelection():Bool
		return _isItemToggledSelection();

	@:hlNative("sfimgui", "igIsItemVisible")
	private static function _isItemVisible():Bool {
		return false;
	}

	public static inline function isItemVisible():Bool
		return _isItemVisible();

	@:hlNative("sfimgui", "igIsKeyChordPressed_Nil")
	private static function _isKeyChordPressed_Nil(key_chord:Int):Bool {
		return false;
	}

	public static inline function isKeyChordPressed(keyChord:Int):Bool
		return _isKeyChordPressed_Nil(keyChord);

	@:hlNative("sfimgui", "igIsKeyDown_Nil")
	private static function _isKeyDown_Nil(key:Int):Bool {
		return false;
	}

	public static inline function isKeyDown(key:Int):Bool
		return _isKeyDown_Nil(key);

	@:hlNative("sfimgui", "igIsKeyPressed_Bool")
	private static function _isKeyPressed_Bool(key:Int, repeat:Bool):Bool {
		return false;
	}

	public static inline function isKeyPressed(key:Int, repeat:Bool = true):Bool
		return _isKeyPressed_Bool(key, repeat);

	@:hlNative("sfimgui", "igIsKeyReleased_Nil")
	private static function _isKeyReleased_Nil(key:Int):Bool {
		return false;
	}

	public static inline function isKeyReleased(key:Int):Bool
		return _isKeyReleased_Nil(key);

	@:hlNative("sfimgui", "igIsMouseClicked_Bool")
	private static function _isMouseClicked_Bool(button:Int, repeat:Bool):Bool {
		return false;
	}

	public static inline function isMouseClicked(button:Int, repeat:Bool = false):Bool
		return _isMouseClicked_Bool(button, repeat);

	@:hlNative("sfimgui", "igIsMouseDoubleClicked_Nil")
	private static function _isMouseDoubleClicked_Nil(button:Int):Bool {
		return false;
	}

	public static inline function isMouseDoubleClicked(button:Int):Bool
		return _isMouseDoubleClicked_Nil(button);

	@:hlNative("sfimgui", "igIsMouseDown_Nil")
	private static function _isMouseDown_Nil(button:Int):Bool {
		return false;
	}

	public static inline function isMouseDown(button:Int):Bool
		return _isMouseDown_Nil(button);

	@:hlNative("sfimgui", "igIsMouseDragging")
	private static function _isMouseDragging(button:Int, lock_threshold:Single):Bool {
		return false;
	}

	public static inline function isMouseDragging(button:Int, lockThreshold:Single = -1.0):Bool
		return _isMouseDragging(button, lockThreshold);

	@:hlNative("sfimgui", "igIsMouseHoveringRect")
	private static function _isMouseHoveringRect(r_min:ImVec2, r_max:ImVec2, clip:Bool):Bool {
		return false;
	}

	public static inline function isMouseHoveringRect(rMin:ImVec2, rMax:ImVec2, clip:Bool = true):Bool
		return _isMouseHoveringRect(rMin, rMax, clip);

	@:hlNative("sfimgui", "igIsMousePosValid")
	private static function _isMousePosValid(mouse_pos:hl.Bytes):Bool {
		return false;
	}

	public static inline function isMousePosValid(mousePos:hl.Bytes = null):Bool
		return _isMousePosValid(mousePos);

	@:hlNative("sfimgui", "igIsMouseReleased_Nil")
	private static function _isMouseReleased_Nil(button:Int):Bool {
		return false;
	}

	public static inline function isMouseReleased(button:Int):Bool
		return _isMouseReleased_Nil(button);

	@:hlNative("sfimgui", "igIsMouseReleasedWithDelay")
	private static function _isMouseReleasedWithDelay(button:Int, delay:Single):Bool {
		return false;
	}

	public static inline function isMouseReleasedWithDelay(button:Int, delay:Single = -1.):Bool
		return _isMouseReleasedWithDelay(button, delay);

	@:hlNative("sfimgui", "igIsPopupOpen_Str")
	private static function _isPopupOpen_Str(str_id:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function isPopupOpen(strId:String, flags:Int = 0):Bool
		return _isPopupOpen_Str(cstr(strId), flags);

	@:hlNative("sfimgui", "igIsRectVisible_Nil")
	private static function _isRectVisible_Nil(size:ImVec2):Bool {
		return false;
	}

	public static overload extern inline function isRectVisible(size:ImVec2):Bool
		return _isRectVisible_Nil(size);

	@:hlNative("sfimgui", "igIsRectVisible_Vec2")
	private static function _isRectVisible_Vec2(rect_min:ImVec2, rect_max:ImVec2):Bool {
		return false;
	}

	public static overload extern inline function isRectVisible(rectMin:ImVec2, rectMax:ImVec2):Bool
		return _isRectVisible_Vec2(rectMin, rectMax);

	@:hlNative("sfimgui", "igIsWindowAppearing")
	private static function _isWindowAppearing():Bool {
		return false;
	}

	public static inline function isWindowAppearing():Bool
		return _isWindowAppearing();

	@:hlNative("sfimgui", "igIsWindowCollapsed")
	private static function _isWindowCollapsed():Bool {
		return false;
	}

	public static inline function isWindowCollapsed():Bool
		return _isWindowCollapsed();

	@:hlNative("sfimgui", "igIsWindowFocused")
	private static function _isWindowFocused(flags:Int):Bool {
		return false;
	}

	public static inline function isWindowFocused(flags:Int = 0):Bool
		return _isWindowFocused(flags);

	@:hlNative("sfimgui", "igIsWindowHovered")
	private static function _isWindowHovered(flags:Int):Bool {
		return false;
	}

	public static inline function isWindowHovered(flags:Int = 0):Bool
		return _isWindowHovered(flags);

	@:hlNative("sfimgui", "igLabelText")
	private static function _labelText(label:hl.Bytes, fmt:hl.Bytes):Void {
	}

	public static inline function labelText(label:String, text:String):Void
		_labelText(cstr(label), cstr(text));

	@:hlNative("sfimgui", "igLoadIniSettingsFromDisk")
	private static function _loadIniSettingsFromDisk(ini_filename:hl.Bytes):Void {
	}

	public static inline function loadIniSettingsFromDisk(iniFilename:String):Void
		_loadIniSettingsFromDisk(cstr(iniFilename));

	@:hlNative("sfimgui", "igLoadIniSettingsFromMemory")
	private static function _loadIniSettingsFromMemory(ini_data:hl.Bytes, ini_size:hl.I64):Void {
	}

	public static inline function loadIniSettingsFromMemory(iniData:String, iniSize:hl.I64 = 0):Void
		_loadIniSettingsFromMemory(cstr(iniData), iniSize);

	@:hlNative("sfimgui", "igLogButtons")
	private static function _logButtons():Void {
	}

	public static inline function logButtons():Void
		_logButtons();

	@:hlNative("sfimgui", "igLogFinish")
	private static function _logFinish():Void {
	}

	public static inline function logFinish():Void
		_logFinish();

	@:hlNative("sfimgui", "igLogText")
	private static function _logText(fmt:hl.Bytes):Void {
	}

	public static inline function logText(text:String):Void
		_logText(cstr(text));

	@:hlNative("sfimgui", "igLogToClipboard")
	private static function _logToClipboard(auto_open_depth:Int):Void {
	}

	public static inline function logToClipboard(autoOpenDepth:Int = -1):Void
		_logToClipboard(autoOpenDepth);

	@:hlNative("sfimgui", "igLogToFile")
	private static function _logToFile(auto_open_depth:Int, filename:hl.Bytes):Void {
	}

	public static inline function logToFile(autoOpenDepth:Int = -1, filename:String = null):Void
		_logToFile(autoOpenDepth, cstr(filename));

	@:hlNative("sfimgui", "igLogToTTY")
	private static function _logToTTY(auto_open_depth:Int):Void {
	}

	public static inline function logToTTY(autoOpenDepth:Int = -1):Void
		_logToTTY(autoOpenDepth);

	@:hlNative("sfimgui", "igMenuItem_Bool")
	private static function _menuItem_Bool(label:hl.Bytes, shortcut:hl.Bytes, selected:Bool, enabled:Bool):Bool {
		return false;
	}

	public static overload extern inline function menuItem(label:String, shortcut:String = null, selected:Bool = false, enabled:Bool = true):Bool
		return _menuItem_Bool(cstr(label), cstr(shortcut), selected, enabled);

	@:hlNative("sfimgui", "igMenuItem_BoolPtr_Ptr")
	private static function _menuItem_BoolPtr_Ptr(label:hl.Bytes, shortcut:hl.Bytes, p_selected:hl.Bytes, enabled:Bool):Bool {
		return false;
	}

	public static overload extern inline function menuItem(label:String, shortcut:String, selected:BoolRef, enabled:Bool = true):Bool
		return _menuItem_BoolPtr_Ptr(cstr(label), cstr(shortcut), selected, enabled);

	@:hlNative("sfimgui", "igNewFrame")
	private static function _newFrame():Void {
	}

	@:hlNative("sfimgui", "igNewLine")
	private static function _newLine():Void {
	}

	public static inline function newLine():Void
		_newLine();

	@:hlNative("sfimgui", "igNextColumn")
	private static function _nextColumn():Void {
	}

	public static inline function nextColumn():Void
		_nextColumn();

	@:hlNative("sfimgui", "igOpenPopup_Str")
	private static function _openPopup_Str(str_id:hl.Bytes, popup_flags:Int):Bool {
		return false;
	}

	public static overload extern inline function openPopup(strId:String, popupFlags:Int = 0):Bool
		return _openPopup_Str(cstr(strId), popupFlags);

	@:hlNative("sfimgui", "igOpenPopup_ID")
	private static function _openPopup_ID(id:Int, popup_flags:Int):Bool {
		return false;
	}

	public static overload extern inline function openPopup(id:Int, popupFlags:Int = 0):Bool
		return _openPopup_ID(id, popupFlags);

	@:hlNative("sfimgui", "igOpenPopupOnItemClick")
	private static function _openPopupOnItemClick(str_id:hl.Bytes, popup_flags:Int):Bool {
		return false;
	}

	public static inline function openPopupOnItemClick(strId:String = null, popupFlags:Int = 0):Bool
		return _openPopupOnItemClick(cstr(strId), popupFlags);

	@:hlNative("sfimgui", "igPlotHistogram_FloatPtr")
	private static function _plotHistogram_FloatPtr(label:hl.Bytes, values:hl.Bytes, values_count:Int, values_offset:Int, overlay_text:hl.Bytes, scale_min:Single, scale_max:Single, graph_size:ImVec2, stride:Int):Void {
	}

	public static inline function plotHistogram(label:String, values:hl.Bytes, valuesCount:Int, valuesOffset:Int = 0, overlayText:String = null, scaleMin:Single = 3.4028234663852886e+38, scaleMax:Single = 3.4028234663852886e+38, graphSize:ImVec2 = null, stride:Int = 4):Void {
		graphSize = graphSize ?? vec2(0, 0);
		_plotHistogram_FloatPtr(cstr(label), values, valuesCount, valuesOffset, cstr(overlayText), scaleMin, scaleMax, graphSize, stride);
	}

	@:hlNative("sfimgui", "igPlotLines_FloatPtr")
	private static function _plotLines_FloatPtr(label:hl.Bytes, values:hl.Bytes, values_count:Int, values_offset:Int, overlay_text:hl.Bytes, scale_min:Single, scale_max:Single, graph_size:ImVec2, stride:Int):Void {
	}

	public static inline function plotLines(label:String, values:hl.Bytes, valuesCount:Int, valuesOffset:Int = 0, overlayText:String = null, scaleMin:Single = 3.4028234663852886e+38, scaleMax:Single = 3.4028234663852886e+38, graphSize:ImVec2 = null, stride:Int = 4):Void {
		graphSize = graphSize ?? vec2(0, 0);
		_plotLines_FloatPtr(cstr(label), values, valuesCount, valuesOffset, cstr(overlayText), scaleMin, scaleMax, graphSize, stride);
	}

	@:hlNative("sfimgui", "igPopClipRect")
	private static function _popClipRect():Void {
	}

	public static inline function popClipRect():Void
		_popClipRect();

	@:hlNative("sfimgui", "igPopFont")
	private static function _popFont():Void {
	}

	public static inline function popFont():Void
		_popFont();

	@:hlNative("sfimgui", "igPopID")
	private static function _popID():Void {
	}

	public static inline function popID():Void
		_popID();

	@:hlNative("sfimgui", "igPopItemFlag")
	private static function _popItemFlag():Void {
	}

	public static inline function popItemFlag():Void
		_popItemFlag();

	@:hlNative("sfimgui", "igPopItemWidth")
	private static function _popItemWidth():Void {
	}

	public static inline function popItemWidth():Void
		_popItemWidth();

	@:hlNative("sfimgui", "igPopStyleColor")
	private static function _popStyleColor(count:Int):Void {
	}

	public static inline function popStyleColor(count:Int = 1):Void
		_popStyleColor(count);

	@:hlNative("sfimgui", "igPopStyleVar")
	private static function _popStyleVar(count:Int):Void {
	}

	public static inline function popStyleVar(count:Int = 1):Void
		_popStyleVar(count);

	@:hlNative("sfimgui", "igPopTextWrapPos")
	private static function _popTextWrapPos():Void {
	}

	public static inline function popTextWrapPos():Void
		_popTextWrapPos();

	@:hlNative("sfimgui", "igProgressBar")
	private static function _progressBar(fraction:Single, size_arg:ImVec2, overlay:hl.Bytes):Void {
	}

	public static inline function progressBar(fraction:Single, sizeArg:ImVec2 = null, overlay:String = null):Void {
		sizeArg = sizeArg ?? vec2(-1.1754943508222875e-38, 0);
		_progressBar(fraction, sizeArg, cstr(overlay));
	}

	@:hlNative("sfimgui", "igPushClipRect")
	private static function _pushClipRect(clip_rect_min:ImVec2, clip_rect_max:ImVec2, intersect_with_current_clip_rect:Bool):Void {
	}

	public static inline function pushClipRect(clipRectMin:ImVec2, clipRectMax:ImVec2, intersectWithCurrentClipRect:Bool):Void
		_pushClipRect(clipRectMin, clipRectMax, intersectWithCurrentClipRect);

	@:hlNative("sfimgui", "igPushFont")
	private static function _pushFont(font:ImFont, font_size_base_unscaled:Single):Void {
	}

	public static inline function pushFont(font:ImFont, fontSizeBaseUnscaled:Single):Void
		_pushFont(font, fontSizeBaseUnscaled);

	@:hlNative("sfimgui", "igPushID_Str")
	private static function _pushID_Str(str_id:hl.Bytes):Void {
	}

	public static inline function pushID_Str(strId:String):Void
		_pushID_Str(cstr(strId));

	@:hlNative("sfimgui", "igPushID_StrStr")
	private static function _pushID_StrStr(str_id_begin:hl.Bytes, str_id_end:hl.Bytes):Void {
	}

	public static inline function pushID_StrStr(strId:String):Void
		_pushID_StrStr(cstr(strId), null);

	@:hlNative("sfimgui", "igPushID_Int")
	private static function _pushID_Int(int_id:Int):Void {
	}

	public static inline function pushID_Int(intId:Int):Void
		_pushID_Int(intId);

	@:hlNative("sfimgui", "igPushItemFlag")
	private static function _pushItemFlag(option:Int, enabled:Bool):Void {
	}

	public static inline function pushItemFlag(option:Int, enabled:Bool):Void
		_pushItemFlag(option, enabled);

	@:hlNative("sfimgui", "igPushItemWidth")
	private static function _pushItemWidth(item_width:Single):Void {
	}

	public static inline function pushItemWidth(itemWidth:Single):Void
		_pushItemWidth(itemWidth);

	@:hlNative("sfimgui", "igPushStyleColor_U32")
	private static function _pushStyleColor_U32(idx:Int, col:Int):Void {
	}

	public static overload extern inline function pushStyleColor(idx:Int, col:Int):Void
		_pushStyleColor_U32(idx, col);

	@:hlNative("sfimgui", "igPushStyleColor_Vec4")
	private static function _pushStyleColor_Vec4(idx:Int, col:ImVec4):Void {
	}

	public static overload extern inline function pushStyleColor(idx:Int, col:ImVec4):Void
		_pushStyleColor_Vec4(idx, col);

	@:hlNative("sfimgui", "igPushStyleVar_Float")
	private static function _pushStyleVar_Float(idx:Int, val:Single):Void {
	}

	public static overload extern inline function pushStyleVar(idx:Int, val:Single):Void
		_pushStyleVar_Float(idx, val);

	@:hlNative("sfimgui", "igPushStyleVar_Vec2")
	private static function _pushStyleVar_Vec2(idx:Int, val:ImVec2):Void {
	}

	public static overload extern inline function pushStyleVar(idx:Int, val:ImVec2):Void
		_pushStyleVar_Vec2(idx, val);

	@:hlNative("sfimgui", "igPushStyleVarX")
	private static function _pushStyleVarX(idx:Int, val_x:Single):Void {
	}

	public static inline function pushStyleVarX(idx:Int, valX:Single):Void
		_pushStyleVarX(idx, valX);

	@:hlNative("sfimgui", "igPushStyleVarY")
	private static function _pushStyleVarY(idx:Int, val_y:Single):Void {
	}

	public static inline function pushStyleVarY(idx:Int, valY:Single):Void
		_pushStyleVarY(idx, valY);

	@:hlNative("sfimgui", "igPushTextWrapPos")
	private static function _pushTextWrapPos(wrap_local_pos_x:Single):Void {
	}

	public static inline function pushTextWrapPos(wrapLocalPosX:Single = 0.0):Void
		_pushTextWrapPos(wrapLocalPosX);

	@:hlNative("sfimgui", "igRadioButton_Bool")
	private static function _radioButton_Bool(label:hl.Bytes, active:Bool):Bool {
		return false;
	}

	public static overload extern inline function radioButton(label:String, active:Bool):Bool
		return _radioButton_Bool(cstr(label), active);

	@:hlNative("sfimgui", "igRadioButton_IntPtr_Ptr")
	private static function _radioButton_IntPtr_Ptr(label:hl.Bytes, v:hl.Bytes, v_button:Int):Bool {
		return false;
	}

	public static overload extern inline function radioButton(label:String, v:IntRef, vButton:Int):Bool
		return _radioButton_IntPtr_Ptr(cstr(label), v, vButton);

	@:hlNative("sfimgui", "igRender")
	private static function _render():Void {
	}

	@:hlNative("sfimgui", "igResetMouseDragDelta")
	private static function _resetMouseDragDelta(button:Int):Void {
	}

	public static inline function resetMouseDragDelta(button:Int = 0):Void
		_resetMouseDragDelta(button);

	@:hlNative("sfimgui", "igSameLine")
	private static function _sameLine(offset_from_start_x:Single, spacing:Single):Void {
	}

	public static inline function sameLine(offsetFromStartX:Single = 0.0, spacing:Single = -1.0):Void
		_sameLine(offsetFromStartX, spacing);

	@:hlNative("sfimgui", "igSaveIniSettingsToDisk")
	private static function _saveIniSettingsToDisk(ini_filename:hl.Bytes):Void {
	}

	public static inline function saveIniSettingsToDisk(iniFilename:String):Void
		_saveIniSettingsToDisk(cstr(iniFilename));

	@:hlNative("sfimgui", "igSaveIniSettingsToMemory_Ptr")
	private static function _saveIniSettingsToMemory_Ptr(out_ini_size:hl.Bytes):hl.Bytes {
		return null;
	}

	public static inline function saveIniSettingsToMemory(outIniSize:hl.Bytes = null):hl.Bytes
		return _saveIniSettingsToMemory_Ptr(outIniSize);

	@:hlNative("sfimgui", "igSelectable_Bool")
	private static function _selectable_Bool(label:hl.Bytes, selected:Bool, flags:Int, size:ImVec2):Bool {
		return false;
	}

	public static overload extern inline function selectable(label:String, selected:Bool = false, flags:Int = 0, size:ImVec2 = null):Bool {
		size = size ?? vec2(0, 0);
		return _selectable_Bool(cstr(label), selected, flags, size);
	}

	@:hlNative("sfimgui", "igSelectable_BoolPtr_Ptr")
	private static function _selectable_BoolPtr_Ptr(label:hl.Bytes, p_selected:hl.Bytes, flags:Int, size:ImVec2):Bool {
		return false;
	}

	public static overload extern inline function selectable(label:String, selected:BoolRef, flags:Int = 0, size:ImVec2 = null):Bool {
		size = size ?? vec2(0, 0);
		return _selectable_BoolPtr_Ptr(cstr(label), selected, flags, size);
	}

	@:hlNative("sfimgui", "igSeparator")
	private static function _separator():Void {
	}

	public static inline function separator():Void
		_separator();

	@:hlNative("sfimgui", "igSeparatorText")
	private static function _separatorText(label:hl.Bytes):Void {
	}

	public static inline function separatorText(label:String):Void
		_separatorText(cstr(label));

	@:hlNative("sfimgui", "igSetClipboardText")
	private static function _setClipboardText(text:hl.Bytes):Void {
	}

	public static inline function setClipboardText(text:String):Void
		_setClipboardText(cstr(text));

	@:hlNative("sfimgui", "igSetColumnOffset")
	private static function _setColumnOffset(column_index:Int, offset_x:Single):Void {
	}

	public static inline function setColumnOffset(columnIndex:Int, offsetX:Single):Void
		_setColumnOffset(columnIndex, offsetX);

	@:hlNative("sfimgui", "igSetColumnWidth")
	private static function _setColumnWidth(column_index:Int, width:Single):Void {
	}

	public static inline function setColumnWidth(columnIndex:Int, width:Single):Void
		_setColumnWidth(columnIndex, width);

	@:hlNative("sfimgui", "igSetCurrentContext")
	private static function _setCurrentContext(ctx:ImGuiContext):Void {
	}

	public static inline function setCurrentContext(ctx:ImGuiContext):Void
		_setCurrentContext(ctx);

	@:hlNative("sfimgui", "igSetCursorPos")
	private static function _setCursorPos(local_pos:ImVec2):Void {
	}

	public static inline function setCursorPos(localPos:ImVec2):Void
		_setCursorPos(localPos);

	@:hlNative("sfimgui", "igSetCursorPosX")
	private static function _setCursorPosX(local_x:Single):Void {
	}

	public static inline function setCursorPosX(localX:Single):Void
		_setCursorPosX(localX);

	@:hlNative("sfimgui", "igSetCursorPosY")
	private static function _setCursorPosY(local_y:Single):Void {
	}

	public static inline function setCursorPosY(localY:Single):Void
		_setCursorPosY(localY);

	@:hlNative("sfimgui", "igSetCursorScreenPos")
	private static function _setCursorScreenPos(pos:ImVec2):Void {
	}

	public static inline function setCursorScreenPos(pos:ImVec2):Void
		_setCursorScreenPos(pos);

	@:hlNative("sfimgui", "igSetItemDefaultFocus")
	private static function _setItemDefaultFocus():Void {
	}

	public static inline function setItemDefaultFocus():Void
		_setItemDefaultFocus();

	@:hlNative("sfimgui", "igSetItemKeyOwner_Nil")
	private static function _setItemKeyOwner_Nil(key:Int):Bool {
		return false;
	}

	public static inline function setItemKeyOwner(key:Int):Bool
		return _setItemKeyOwner_Nil(key);

	@:hlNative("sfimgui", "igSetItemTooltip")
	private static function _setItemTooltip(fmt:hl.Bytes):Void {
	}

	public static inline function setItemTooltip(text:String):Void
		_setItemTooltip(cstr(text));

	@:hlNative("sfimgui", "igSetKeyboardFocusHere")
	private static function _setKeyboardFocusHere(offset:Int):Void {
	}

	public static inline function setKeyboardFocusHere(offset:Int = 0):Void
		_setKeyboardFocusHere(offset);

	@:hlNative("sfimgui", "igSetMouseCursor")
	private static function _setMouseCursor(cursor_type:Int):Void {
	}

	public static inline function setMouseCursor(cursorType:Int):Void
		_setMouseCursor(cursorType);

	@:hlNative("sfimgui", "igSetNavCursorVisible")
	private static function _setNavCursorVisible(visible:Bool):Void {
	}

	public static inline function setNavCursorVisible(visible:Bool):Void
		_setNavCursorVisible(visible);

	@:hlNative("sfimgui", "igSetNextFrameWantCaptureKeyboard")
	private static function _setNextFrameWantCaptureKeyboard(want_capture_keyboard:Bool):Void {
	}

	public static inline function setNextFrameWantCaptureKeyboard(wantCaptureKeyboard:Bool):Void
		_setNextFrameWantCaptureKeyboard(wantCaptureKeyboard);

	@:hlNative("sfimgui", "igSetNextFrameWantCaptureMouse")
	private static function _setNextFrameWantCaptureMouse(want_capture_mouse:Bool):Void {
	}

	public static inline function setNextFrameWantCaptureMouse(wantCaptureMouse:Bool):Void
		_setNextFrameWantCaptureMouse(wantCaptureMouse);

	@:hlNative("sfimgui", "igSetNextItemAllowOverlap")
	private static function _setNextItemAllowOverlap():Void {
	}

	public static inline function setNextItemAllowOverlap():Void
		_setNextItemAllowOverlap();

	@:hlNative("sfimgui", "igSetNextItemOpen")
	private static function _setNextItemOpen(is_open:Bool, cond:Int):Void {
	}

	public static inline function setNextItemOpen(isOpen:Bool, cond:Int = 0):Void
		_setNextItemOpen(isOpen, cond);

	@:hlNative("sfimgui", "igSetNextItemSelectionUserData")
	private static function _setNextItemSelectionUserData(selection_user_data:hl.I64):Void {
	}

	public static inline function setNextItemSelectionUserData(selectionUserData:hl.I64):Void
		_setNextItemSelectionUserData(selectionUserData);

	@:hlNative("sfimgui", "igSetNextItemShortcut")
	private static function _setNextItemShortcut(key_chord:Int, flags:Int):Void {
	}

	public static inline function setNextItemShortcut(keyChord:Int, flags:Int = 0):Void
		_setNextItemShortcut(keyChord, flags);

	@:hlNative("sfimgui", "igSetNextItemStorageID")
	private static function _setNextItemStorageID(storage_id:Int):Void {
	}

	public static inline function setNextItemStorageID(storageId:Int):Void
		_setNextItemStorageID(storageId);

	@:hlNative("sfimgui", "igSetNextItemWidth")
	private static function _setNextItemWidth(item_width:Single):Void {
	}

	public static inline function setNextItemWidth(itemWidth:Single):Void
		_setNextItemWidth(itemWidth);

	@:hlNative("sfimgui", "igSetNextWindowBgAlpha")
	private static function _setNextWindowBgAlpha(alpha:Single):Void {
	}

	public static inline function setNextWindowBgAlpha(alpha:Single):Void
		_setNextWindowBgAlpha(alpha);

	@:hlNative("sfimgui", "igSetNextWindowCollapsed")
	private static function _setNextWindowCollapsed(collapsed:Bool, cond:Int):Void {
	}

	public static inline function setNextWindowCollapsed(collapsed:Bool, cond:Int = 0):Void
		_setNextWindowCollapsed(collapsed, cond);

	@:hlNative("sfimgui", "igSetNextWindowContentSize")
	private static function _setNextWindowContentSize(size:ImVec2):Void {
	}

	public static inline function setNextWindowContentSize(size:ImVec2):Void
		_setNextWindowContentSize(size);

	@:hlNative("sfimgui", "igSetNextWindowFocus")
	private static function _setNextWindowFocus():Void {
	}

	public static inline function setNextWindowFocus():Void
		_setNextWindowFocus();

	@:hlNative("sfimgui", "igSetNextWindowPos")
	private static function _setNextWindowPos(pos:ImVec2, cond:Int, pivot:ImVec2):Void {
	}

	public static inline function setNextWindowPos(pos:ImVec2, cond:Int = 0, pivot:ImVec2 = null):Void {
		pivot = pivot ?? vec2(0, 0);
		_setNextWindowPos(pos, cond, pivot);
	}

	@:hlNative("sfimgui", "igSetNextWindowScroll")
	private static function _setNextWindowScroll(scroll:ImVec2):Void {
	}

	public static inline function setNextWindowScroll(scroll:ImVec2):Void
		_setNextWindowScroll(scroll);

	@:hlNative("sfimgui", "igSetNextWindowSize")
	private static function _setNextWindowSize(size:ImVec2, cond:Int):Void {
	}

	public static inline function setNextWindowSize(size:ImVec2, cond:Int = 0):Void
		_setNextWindowSize(size, cond);

	@:hlNative("sfimgui", "igSetNextWindowSizeConstraints")
	private static function _setNextWindowSizeConstraints(size_min:ImVec2, size_max:ImVec2):Void {
	}

	public static inline function setNextWindowSizeConstraints(sizeMin:ImVec2, sizeMax:ImVec2):Void
		_setNextWindowSizeConstraints(sizeMin, sizeMax);

	@:hlNative("sfimgui", "igSetScrollFromPosX_Float")
	private static function _setScrollFromPosX_Float(local_x:Single, center_x_ratio:Single):Void {
	}

	public static inline function setScrollFromPosX(localX:Single, centerXRatio:Single = 0.5):Void
		_setScrollFromPosX_Float(localX, centerXRatio);

	@:hlNative("sfimgui", "igSetScrollFromPosY_Float")
	private static function _setScrollFromPosY_Float(local_y:Single, center_y_ratio:Single):Void {
	}

	public static inline function setScrollFromPosY(localY:Single, centerYRatio:Single = 0.5):Void
		_setScrollFromPosY_Float(localY, centerYRatio);

	@:hlNative("sfimgui", "igSetScrollHereX")
	private static function _setScrollHereX(center_x_ratio:Single):Void {
	}

	public static inline function setScrollHereX(centerXRatio:Single = 0.5):Void
		_setScrollHereX(centerXRatio);

	@:hlNative("sfimgui", "igSetScrollHereY")
	private static function _setScrollHereY(center_y_ratio:Single):Void {
	}

	public static inline function setScrollHereY(centerYRatio:Single = 0.5):Void
		_setScrollHereY(centerYRatio);

	@:hlNative("sfimgui", "igSetScrollX_Float")
	private static function _setScrollX_Float(scroll_x:Single):Void {
	}

	public static inline function setScrollX(scrollX:Single):Void
		_setScrollX_Float(scrollX);

	@:hlNative("sfimgui", "igSetScrollY_Float")
	private static function _setScrollY_Float(scroll_y:Single):Void {
	}

	public static inline function setScrollY(scrollY:Single):Void
		_setScrollY_Float(scrollY);

	@:hlNative("sfimgui", "igSetTabItemClosed")
	private static function _setTabItemClosed(tab_or_docked_window_label:hl.Bytes):Void {
	}

	public static inline function setTabItemClosed(tabOrDockedWindowLabel:String):Void
		_setTabItemClosed(cstr(tabOrDockedWindowLabel));

	@:hlNative("sfimgui", "igSetTooltip")
	private static function _setTooltip(fmt:hl.Bytes):Void {
	}

	public static inline function setTooltip(text:String):Void
		_setTooltip(cstr(text));

	@:hlNative("sfimgui", "igSetWindowCollapsed_Bool")
	private static function _setWindowCollapsed_Bool(collapsed:Bool, cond:Int):Void {
	}

	public static overload extern inline function setWindowCollapsed(collapsed:Bool, cond:Int = 0):Void
		_setWindowCollapsed_Bool(collapsed, cond);

	@:hlNative("sfimgui", "igSetWindowCollapsed_Str")
	private static function _setWindowCollapsed_Str(name:hl.Bytes, collapsed:Bool, cond:Int):Void {
	}

	public static overload extern inline function setWindowCollapsed(name:String, collapsed:Bool, cond:Int = 0):Void
		_setWindowCollapsed_Str(cstr(name), collapsed, cond);

	@:hlNative("sfimgui", "igSetWindowFocus_Nil")
	private static function _setWindowFocus_Nil():Void {
	}

	public static overload extern inline function setWindowFocus():Void
		_setWindowFocus_Nil();

	@:hlNative("sfimgui", "igSetWindowFocus_Str")
	private static function _setWindowFocus_Str(name:hl.Bytes):Void {
	}

	public static overload extern inline function setWindowFocus(name:String):Void
		_setWindowFocus_Str(cstr(name));

	@:hlNative("sfimgui", "igSetWindowPos_Vec2")
	private static function _setWindowPos_Vec2(pos:ImVec2, cond:Int):Void {
	}

	public static overload extern inline function setWindowPos(pos:ImVec2, cond:Int = 0):Void
		_setWindowPos_Vec2(pos, cond);

	@:hlNative("sfimgui", "igSetWindowPos_Str")
	private static function _setWindowPos_Str(name:hl.Bytes, pos:ImVec2, cond:Int):Void {
	}

	public static overload extern inline function setWindowPos(name:String, pos:ImVec2, cond:Int = 0):Void
		_setWindowPos_Str(cstr(name), pos, cond);

	@:hlNative("sfimgui", "igSetWindowSize_Vec2")
	private static function _setWindowSize_Vec2(size:ImVec2, cond:Int):Void {
	}

	public static overload extern inline function setWindowSize(size:ImVec2, cond:Int = 0):Void
		_setWindowSize_Vec2(size, cond);

	@:hlNative("sfimgui", "igSetWindowSize_Str")
	private static function _setWindowSize_Str(name:hl.Bytes, size:ImVec2, cond:Int):Void {
	}

	public static overload extern inline function setWindowSize(name:String, size:ImVec2, cond:Int = 0):Void
		_setWindowSize_Str(cstr(name), size, cond);

	@:hlNative("sfimgui", "igShortcut_Nil")
	private static function _shortcut_Nil(key_chord:Int, flags:Int):Bool {
		return false;
	}

	public static inline function shortcut(keyChord:Int, flags:Int = 0):Bool
		return _shortcut_Nil(keyChord, flags);

	@:hlNative("sfimgui", "igShowAboutWindow_Ptr")
	private static function _showAboutWindow_Ptr(p_open:hl.Bytes):Void {
	}

	public static inline function showAboutWindow(open:BoolRef = null):Void
		_showAboutWindow_Ptr(open);

	@:hlNative("sfimgui", "igShowDebugLogWindow_Ptr")
	private static function _showDebugLogWindow_Ptr(p_open:hl.Bytes):Void {
	}

	public static inline function showDebugLogWindow(open:BoolRef = null):Void
		_showDebugLogWindow_Ptr(open);

	@:hlNative("sfimgui", "igShowDemoWindow_Ptr")
	private static function _showDemoWindow_Ptr(p_open:hl.Bytes):Void {
	}

	public static inline function showDemoWindow(open:BoolRef = null):Void
		_showDemoWindow_Ptr(open);

	@:hlNative("sfimgui", "igShowFontSelector")
	private static function _showFontSelector(label:hl.Bytes):Void {
	}

	public static inline function showFontSelector(label:String):Void
		_showFontSelector(cstr(label));

	@:hlNative("sfimgui", "igShowIDStackToolWindow_Ptr")
	private static function _showIDStackToolWindow_Ptr(p_open:hl.Bytes):Void {
	}

	public static inline function showIDStackToolWindow(open:BoolRef = null):Void
		_showIDStackToolWindow_Ptr(open);

	@:hlNative("sfimgui", "igShowMetricsWindow_Ptr")
	private static function _showMetricsWindow_Ptr(p_open:hl.Bytes):Void {
	}

	public static inline function showMetricsWindow(open:BoolRef = null):Void
		_showMetricsWindow_Ptr(open);

	@:hlNative("sfimgui", "igShowStyleEditor")
	private static function _showStyleEditor(ref:ImGuiStyle):Void {
	}

	public static inline function showStyleEditor(ref:ImGuiStyle = null):Void
		_showStyleEditor(ref);

	@:hlNative("sfimgui", "igShowStyleSelector")
	private static function _showStyleSelector(label:hl.Bytes):Bool {
		return false;
	}

	public static inline function showStyleSelector(label:String):Bool
		return _showStyleSelector(cstr(label));

	@:hlNative("sfimgui", "igShowUserGuide")
	private static function _showUserGuide():Void {
	}

	public static inline function showUserGuide():Void
		_showUserGuide();

	@:hlNative("sfimgui", "igSliderAngle_Ptr")
	private static function _sliderAngle_Ptr(label:hl.Bytes, v_rad:hl.Bytes, v_degrees_min:Single, v_degrees_max:Single, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function sliderAngle(label:String, vRad:FloatRef, vDegreesMin:Single = -360.0, vDegreesMax:Single = 360.0, format:String = "%.0f deg", flags:Int = 0):Bool
		return _sliderAngle_Ptr(cstr(label), vRad, vDegreesMin, vDegreesMax, cstr(format), flags);

	@:hlNative("sfimgui", "igSliderFloat_Ptr")
	private static function _sliderFloat_Ptr(label:hl.Bytes, v:hl.Bytes, v_min:Single, v_max:Single, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function sliderFloat(label:String, v:FloatRef, vMin:Single, vMax:Single, format:String = "%.3f", flags:Int = 0):Bool
		return _sliderFloat_Ptr(cstr(label), v, vMin, vMax, cstr(format), flags);

	@:hlNative("sfimgui", "igSliderFloat2")
	private static function _sliderFloat2(label:hl.Bytes, v:hl.Bytes, v_min:Single, v_max:Single, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function sliderFloat2(label:String, v:hl.Bytes, vMin:Single, vMax:Single, format:String = "%.3f", flags:Int = 0):Bool
		return _sliderFloat2(cstr(label), v, vMin, vMax, cstr(format), flags);

	@:hlNative("sfimgui", "igSliderFloat3")
	private static function _sliderFloat3(label:hl.Bytes, v:hl.Bytes, v_min:Single, v_max:Single, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function sliderFloat3(label:String, v:hl.Bytes, vMin:Single, vMax:Single, format:String = "%.3f", flags:Int = 0):Bool
		return _sliderFloat3(cstr(label), v, vMin, vMax, cstr(format), flags);

	@:hlNative("sfimgui", "igSliderFloat4")
	private static function _sliderFloat4(label:hl.Bytes, v:hl.Bytes, v_min:Single, v_max:Single, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function sliderFloat4(label:String, v:hl.Bytes, vMin:Single, vMax:Single, format:String = "%.3f", flags:Int = 0):Bool
		return _sliderFloat4(cstr(label), v, vMin, vMax, cstr(format), flags);

	@:hlNative("sfimgui", "igSliderInt_Ptr")
	private static function _sliderInt_Ptr(label:hl.Bytes, v:hl.Bytes, v_min:Int, v_max:Int, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function sliderInt(label:String, v:IntRef, vMin:Int, vMax:Int, format:String = "%d", flags:Int = 0):Bool
		return _sliderInt_Ptr(cstr(label), v, vMin, vMax, cstr(format), flags);

	@:hlNative("sfimgui", "igSliderInt2")
	private static function _sliderInt2(label:hl.Bytes, v:hl.Bytes, v_min:Int, v_max:Int, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function sliderInt2(label:String, v:hl.Bytes, vMin:Int, vMax:Int, format:String = "%d", flags:Int = 0):Bool
		return _sliderInt2(cstr(label), v, vMin, vMax, cstr(format), flags);

	@:hlNative("sfimgui", "igSliderInt3")
	private static function _sliderInt3(label:hl.Bytes, v:hl.Bytes, v_min:Int, v_max:Int, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function sliderInt3(label:String, v:hl.Bytes, vMin:Int, vMax:Int, format:String = "%d", flags:Int = 0):Bool
		return _sliderInt3(cstr(label), v, vMin, vMax, cstr(format), flags);

	@:hlNative("sfimgui", "igSliderInt4")
	private static function _sliderInt4(label:hl.Bytes, v:hl.Bytes, v_min:Int, v_max:Int, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function sliderInt4(label:String, v:hl.Bytes, vMin:Int, vMax:Int, format:String = "%d", flags:Int = 0):Bool
		return _sliderInt4(cstr(label), v, vMin, vMax, cstr(format), flags);

	@:hlNative("sfimgui", "igSmallButton")
	private static function _smallButton(label:hl.Bytes):Bool {
		return false;
	}

	public static inline function smallButton(label:String):Bool
		return _smallButton(cstr(label));

	@:hlNative("sfimgui", "igSpacing")
	private static function _spacing():Void {
	}

	public static inline function spacing():Void
		_spacing();

	@:hlNative("sfimgui", "igStyleColorsClassic")
	private static function _styleColorsClassic(dst:ImGuiStyle):Void {
	}

	public static inline function styleColorsClassic(dst:ImGuiStyle = null):Void
		_styleColorsClassic(dst);

	@:hlNative("sfimgui", "igStyleColorsDark")
	private static function _styleColorsDark(dst:ImGuiStyle):Void {
	}

	public static inline function styleColorsDark(dst:ImGuiStyle = null):Void
		_styleColorsDark(dst);

	@:hlNative("sfimgui", "igStyleColorsLight")
	private static function _styleColorsLight(dst:ImGuiStyle):Void {
	}

	public static inline function styleColorsLight(dst:ImGuiStyle = null):Void
		_styleColorsLight(dst);

	@:hlNative("sfimgui", "igTabItemButton")
	private static function _tabItemButton(label:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function tabItemButton(label:String, flags:Int = 0):Bool
		return _tabItemButton(cstr(label), flags);

	@:hlNative("sfimgui", "igTableAngledHeadersRow")
	private static function _tableAngledHeadersRow():Void {
	}

	public static inline function tableAngledHeadersRow():Void
		_tableAngledHeadersRow();

	@:hlNative("sfimgui", "igTableGetColumnCount")
	private static function _tableGetColumnCount():Int {
		return 0;
	}

	public static inline function tableGetColumnCount():Int
		return _tableGetColumnCount();

	@:hlNative("sfimgui", "igTableGetColumnFlags")
	private static function _tableGetColumnFlags(column_n:Int):Int {
		return 0;
	}

	public static inline function tableGetColumnFlags(columnN:Int = -1):Int
		return _tableGetColumnFlags(columnN);

	@:hlNative("sfimgui", "igTableGetColumnIndex")
	private static function _tableGetColumnIndex():Int {
		return 0;
	}

	public static inline function tableGetColumnIndex():Int
		return _tableGetColumnIndex();

	@:hlNative("sfimgui", "igTableGetColumnName_Int")
	private static function _tableGetColumnName_Int(column_n:Int):hl.Bytes {
		return null;
	}

	public static inline function tableGetColumnName(columnN:Int = -1):hl.Bytes
		return _tableGetColumnName_Int(columnN);

	@:hlNative("sfimgui", "igTableGetHoveredColumn")
	private static function _tableGetHoveredColumn():Int {
		return 0;
	}

	public static inline function tableGetHoveredColumn():Int
		return _tableGetHoveredColumn();

	@:hlNative("sfimgui", "igTableGetRowIndex")
	private static function _tableGetRowIndex():Int {
		return 0;
	}

	public static inline function tableGetRowIndex():Int
		return _tableGetRowIndex();

	@:hlNative("sfimgui", "igTableGetSortSpecs")
	private static function _tableGetSortSpecs():ImGuiTableSortSpecs {
		return null;
	}

	public static inline function tableGetSortSpecs():ImGuiTableSortSpecs
		return _tableGetSortSpecs();

	@:hlNative("sfimgui", "igTableHeader")
	private static function _tableHeader(label:hl.Bytes):Void {
	}

	public static inline function tableHeader(label:String):Void
		_tableHeader(cstr(label));

	@:hlNative("sfimgui", "igTableHeadersRow")
	private static function _tableHeadersRow():Void {
	}

	public static inline function tableHeadersRow():Void
		_tableHeadersRow();

	@:hlNative("sfimgui", "igTableNextColumn")
	private static function _tableNextColumn():Bool {
		return false;
	}

	public static inline function tableNextColumn():Bool
		return _tableNextColumn();

	@:hlNative("sfimgui", "igTableNextRow")
	private static function _tableNextRow(row_flags:Int, min_row_height:Single):Void {
	}

	public static inline function tableNextRow(rowFlags:Int = 0, minRowHeight:Single = 0.0):Void
		_tableNextRow(rowFlags, minRowHeight);

	@:hlNative("sfimgui", "igTableSetBgColor")
	private static function _tableSetBgColor(target:Int, color:Int, column_n:Int):Void {
	}

	public static inline function tableSetBgColor(target:Int, color:Int, columnN:Int = -1):Void
		_tableSetBgColor(target, color, columnN);

	@:hlNative("sfimgui", "igTableSetColumnEnabled")
	private static function _tableSetColumnEnabled(column_n:Int, v:Bool):Void {
	}

	public static inline function tableSetColumnEnabled(columnN:Int, v:Bool):Void
		_tableSetColumnEnabled(columnN, v);

	@:hlNative("sfimgui", "igTableSetColumnIndex")
	private static function _tableSetColumnIndex(column_n:Int):Bool {
		return false;
	}

	public static inline function tableSetColumnIndex(columnN:Int):Bool
		return _tableSetColumnIndex(columnN);

	@:hlNative("sfimgui", "igTableSetupColumn")
	private static function _tableSetupColumn(label:hl.Bytes, flags:Int, init_width_or_weight:Single, user_data:Int):Void {
	}

	public static inline function tableSetupColumn(label:String, flags:Int = 0, initWidthOrWeight:Single = 0.0, userData:Int = 0):Void
		_tableSetupColumn(cstr(label), flags, initWidthOrWeight, userData);

	@:hlNative("sfimgui", "igTableSetupScrollFreeze")
	private static function _tableSetupScrollFreeze(cols:Int, rows:Int):Void {
	}

	public static inline function tableSetupScrollFreeze(cols:Int, rows:Int):Void
		_tableSetupScrollFreeze(cols, rows);

	@:hlNative("sfimgui", "igTextColored")
	private static function _textColored(col:ImVec4, fmt:hl.Bytes):Void {
	}

	public static inline function textColored(col:ImVec4, text:String):Void
		_textColored(col, cstr(text));

	@:hlNative("sfimgui", "igTextDisabled")
	private static function _textDisabled(fmt:hl.Bytes):Void {
	}

	public static inline function textDisabled(text:String):Void
		_textDisabled(cstr(text));

	@:hlNative("sfimgui", "igTextLink")
	private static function _textLink(label:hl.Bytes):Bool {
		return false;
	}

	public static inline function textLink(label:String):Bool
		return _textLink(cstr(label));

	@:hlNative("sfimgui", "igTextLinkOpenURL")
	private static function _textLinkOpenURL(label:hl.Bytes, url:hl.Bytes):Bool {
		return false;
	}

	public static inline function textLinkOpenURL(label:String, url:String = null):Bool
		return _textLinkOpenURL(cstr(label), cstr(url));

	@:hlNative("sfimgui", "igTextUnformatted")
	private static function _textUnformatted(text:hl.Bytes, text_end:hl.Bytes):Void {
	}

	public static inline function textUnformatted(text:String):Void
		_textUnformatted(cstr(text), null);

	@:hlNative("sfimgui", "igTextWrapped")
	private static function _textWrapped(fmt:hl.Bytes):Void {
	}

	public static inline function textWrapped(text:String):Void
		_textWrapped(cstr(text));

	@:hlNative("sfimgui", "igTreeNode_Str")
	private static function _treeNode_Str(label:hl.Bytes):Bool {
		return false;
	}

	public static overload extern inline function treeNode(label:String):Bool
		return _treeNode_Str(cstr(label));

	@:hlNative("sfimgui", "igTreeNode_StrStr")
	private static function _treeNode_StrStr(str_id:hl.Bytes, fmt:hl.Bytes):Bool {
		return false;
	}

	public static overload extern inline function treeNode(strId:String, text:String):Bool
		return _treeNode_StrStr(cstr(strId), cstr(text));

	@:hlNative("sfimgui", "igTreeNodeEx_Str")
	private static function _treeNodeEx_Str(label:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static overload extern inline function treeNodeEx(label:String, flags:Int = 0):Bool
		return _treeNodeEx_Str(cstr(label), flags);

	@:hlNative("sfimgui", "igTreeNodeEx_StrStr")
	private static function _treeNodeEx_StrStr(str_id:hl.Bytes, flags:Int, fmt:hl.Bytes):Bool {
		return false;
	}

	public static overload extern inline function treeNodeEx(strId:String, flags:Int, text:String):Bool
		return _treeNodeEx_StrStr(cstr(strId), flags, cstr(text));

	@:hlNative("sfimgui", "igTreeNodeGetOpen")
	private static function _treeNodeGetOpen(storage_id:Int):Bool {
		return false;
	}

	public static inline function treeNodeGetOpen(storageId:Int):Bool
		return _treeNodeGetOpen(storageId);

	@:hlNative("sfimgui", "igTreePop")
	private static function _treePop():Void {
	}

	public static inline function treePop():Void
		_treePop();

	@:hlNative("sfimgui", "igTreePush_Str")
	private static function _treePush_Str(str_id:hl.Bytes):Void {
	}

	public static inline function treePush(strId:String):Void
		_treePush_Str(cstr(strId));

	@:hlNative("sfimgui", "igUnindent")
	private static function _unindent(indent_w:Single):Void {
	}

	public static inline function unindent(indentW:Single = 0.0):Void
		_unindent(indentW);

	@:hlNative("sfimgui", "igVSliderFloat_Ptr")
	private static function _vSliderFloat_Ptr(label:hl.Bytes, size:ImVec2, v:hl.Bytes, v_min:Single, v_max:Single, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function vSliderFloat(label:String, size:ImVec2, v:FloatRef, vMin:Single, vMax:Single, format:String = "%.3f", flags:Int = 0):Bool
		return _vSliderFloat_Ptr(cstr(label), size, v, vMin, vMax, cstr(format), flags);

	@:hlNative("sfimgui", "igVSliderInt_Ptr")
	private static function _vSliderInt_Ptr(label:hl.Bytes, size:ImVec2, v:hl.Bytes, v_min:Int, v_max:Int, format:hl.Bytes, flags:Int):Bool {
		return false;
	}

	public static inline function vSliderInt(label:String, size:ImVec2, v:IntRef, vMin:Int, vMax:Int, format:String = "%d", flags:Int = 0):Bool
		return _vSliderInt_Ptr(cstr(label), size, v, vMin, vMax, cstr(format), flags);

	@:hlNative("sfimgui", "igValue_Bool")
	private static function _value_Bool(prefix:hl.Bytes, b:Bool):Void {
	}

	public static inline function value_Bool(prefix:String, b:Bool):Void
		_value_Bool(cstr(prefix), b);

	@:hlNative("sfimgui", "igValue_Int")
	private static function _value_Int(prefix:hl.Bytes, v:Int):Void {
	}

	public static inline function value_Int(prefix:String, v:Int):Void
		_value_Int(cstr(prefix), v);

	@:hlNative("sfimgui", "igValue_Uint")
	private static function _value_Uint(prefix:hl.Bytes, v:Int):Void {
	}

	public static inline function value_Uint(prefix:String, v:Int):Void
		_value_Uint(cstr(prefix), v);

	@:hlNative("sfimgui", "igValue_Float")
	private static function _value_Float(prefix:hl.Bytes, v:Single, float_format:hl.Bytes):Void {
	}

	public static inline function value_Float(prefix:String, v:Single, floatFormat:String = null):Void
		_value_Float(cstr(prefix), v, cstr(floatFormat));

	// <<< END GENERATED <<<

	// -- helpers --------------------------------------------------------------------------------

	public static inline function vec2(x:Single, y:Single):Vec2 {
		var v = new ImVec2();
		v.x = x;
		v.y = y;
		return v;
	}

	// Used by generate.mts's compileDispatcher whenever a bound function's real cimgui default for a
	// by-value ImVec4 param is anything other than blank (0,0,0,0) - none currently are (see that
	// function's own doc comment), but kept alongside vec2() so a future cimgui bump binding one
	// doesn't silently need this added under time pressure.
	public static inline function vec4(x:Single, y:Single, z:Single, w:Single):Vec4 {
		var v = new ImVec4();
		v.x = x;
		v.y = y;
		v.z = z;
		v.w = w;
		return v;
	}

	// Unlike vec2()/vec4() above, these return a raw hl.Bytes buffer, not an ImVec3/ImVec4 struct - there's
	// no ImVec3, and widgets like sliderFloat3/colorEdit3/colorEdit4 already take hl.Bytes directly
	// (no hl.Ref<T> scalar to route around, see ImGui.checkbox's doc comment), so this is just a
	// convenience constructor for that same buffer shape instead of a caller poking setF32 by hand.
	public static inline function v3(x:Single, y:Single, z:Single):hl.Bytes {
		var b = new hl.Bytes(12);
		b.setF32(0, x);
		b.setF32(4, y);
		b.setF32(8, z);
		return b;
	}

	public static inline function v4(x:Single, y:Single, z:Single, w:Single):hl.Bytes {
		var b = new hl.Bytes(16);
		b.setF32(0, x);
		b.setF32(4, y);
		b.setF32(8, z);
		b.setF32(12, w);
		return b;
	}

	static inline function cstr(s:String):hl.Bytes
		return s == null ? null : @:privateAccess s.toUtf8();
}

typedef Vec2 = ImVec2;
typedef Vec4 = ImVec4;
