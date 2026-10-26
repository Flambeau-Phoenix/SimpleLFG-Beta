package simplelfg;

import imgui.ImGui;
import imgui.Structs.ImVec2;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Enums.ImGuiStyleVar;
import imgui.ref.BoolRef;
import simplelfg.ui.ThemePalette;
import simplelfg.ui.UiChrome;

/**
 * The on-screen button: a small cel-shaded window with the shared window menu (right-click for
 * Lock, Transparent and Reset). Click opens the panel; dragging moves it unless locked.
 * Position is stored as a fraction of the screen, so it survives resolution changes.
 */
class Launcher {
    static inline var BUTTON:Float=44;
    static inline var PAD:Float=5;
    var engine:Engine;var art:LauncherArt;
    var pos=new ImVec2();var size=new ImVec2();var localPos=new ImVec2();var imagePos=new ImVec2();var mouse=new ImVec2();
    var imageSize=new ImVec2();var padding=new ImVec2(0,0);var uv0=new ImVec2(0,0);var uv1=new ImVec2(1,1);
    var tinyMinimum=new ImVec2(1,1);var corner=new ImVec2();
    var chipPos=new ImVec2();var chipSize=new ImVec2(118,34);
    /** Set by the panel: the party strip owns the two-step leave state. */
    public var leave:PartyStrip;
    /** Top-left of the button window and its outer size, kept current for the chip and badge. */
    public var x(default,null):Float=0;public var y(default,null):Float=0;public var extent(default,null):Float=BUTTON;
    var badge:String="";var lockRef=new BoolRef(false);var transRef=new BoolRef(false);
    var dragging=false;var didDrag=false;var moved=false;var grabX:Float=0;var grabY:Float=0;
    var menuBody:Void->Void;
    var width:Float=1920;var height:Float=1080;var now:Float=0;
    public function new(engine:Engine,?art:LauncherArt){this.engine=engine;this.art=art==null?new LauncherArt():art;menuBody=drawMenu;}
    public function observe(time:Float,w:Float,h:Float):Void {now=time;width=w;height=h;art.observe();badge=engine.alerts.unread>0?"New: "+engine.alerts.unread:"";}
    public function draw():Bool {
        if(!engine.state.available)return false;
        var c=engine.config;extent=BUTTON+(c.launcherTransparent?0:PAD*2);place(c);
        var clicked=c.launcherEnabled&&drawMain(c);
        drawLeaveChip();
        return clicked;
    }
    function place(c:Config):Void {
        if(c.launcherX>=0&&c.launcherY>=0){x=c.launcherX*width;y=c.launcherY*height;}
        else{x=Geometry.launcherX(c,width)-(extent-BUTTON)*0.5;y=Geometry.launcherY(c,height)-(extent-BUTTON)*0.5;}
        x=Geometry.clamp(x,0,width-extent);y=Geometry.clamp(y,0,height-extent);
    }
    /** Optional chip beside the button, only while a party can be left. Same two-step confirm as the strip. */
    function drawLeaveChip():Void {
        var c=engine.config;
        if(!c.quickLeaveChip||leave==null||!engine.social.party.canLeave||!engine.state.cursorFree)return;
        chipPos.x=x>=chipSize.x+8?x-chipSize.x-8:x+extent+8;chipPos.y=y+(extent-chipSize.y)*0.5;
        chipPos.x=Geometry.clamp(chipPos.x,0,width-chipSize.x);chipPos.y=Geometry.clamp(chipPos.y,0,height-chipSize.y);
        ImGui.setNextWindowPos(chipPos);ImGui.setNextWindowSize(chipSize);
        ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding,padding);ImGui.pushStyleVar(ImGuiStyleVar.WindowMinSize,tinyMinimum);
        var flags=ImGuiWindowFlags.NoTitleBar|ImGuiWindowFlags.NoResize|ImGuiWindowFlags.NoMove|ImGuiWindowFlags.NoSavedSettings|ImGuiWindowFlags.NoScrollbar|ImGuiWindowFlags.NoFocusOnAppearing;
        var shown=ImGui.begin("##SimpleLFG.LeaveChip",null,flags);var error:Dynamic=null;
        try if(shown){
            imageSize.x=chipSize.x;imageSize.y=chipSize.y;
            if(UiChrome.navButton(leave.isArmed()?"Confirm leave?###chipLeave":"Leave party###chipLeave",leave.isArmed(),imageSize))leave.requestLeave();
        }catch(e:Dynamic)error=e;
        ImGui.end();ImGui.popStyleVar(2);if(error!=null)throw error;
    }
    function drawMain(c:Config):Bool {
        var transparent=c.launcherTransparent;var pad=transparent?0:PAD;
        pos.x=x;pos.y=y;size.x=extent;size.y=extent;
        ImGui.setNextWindowPos(pos);ImGui.setNextWindowSize(size);
        if(!transparent)UiChrome.pushCelShade();
        padding.x=pad;padding.y=pad;
        ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding,padding);
        ImGui.pushStyleVar(ImGuiStyleVar.WindowMinSize,tinyMinimum);
        if(transparent)ImGui.pushStyleVar(ImGuiStyleVar.WindowBorderSize,0);
        var flags=ImGuiWindowFlags.NoTitleBar|ImGuiWindowFlags.NoResize|ImGuiWindowFlags.NoMove|ImGuiWindowFlags.NoSavedSettings|ImGuiWindowFlags.NoScrollbar|ImGuiWindowFlags.NoScrollWithMouse|ImGuiWindowFlags.NoFocusOnAppearing;
        if(transparent)flags|=ImGuiWindowFlags.NoBackground;
        if(!engine.state.cursorFree)flags|=ImGuiWindowFlags.NoInputs;
        var shown=ImGui.begin("##SimpleLFG.Launcher",null,flags);var error:Dynamic=null;var clicked=false;
        try if(shown){clicked=drawButton(c);drawContextMenu();}catch(e:Dynamic)error=e;
        ImGui.end();ImGui.popStyleVar(transparent?3:2);if(!transparent)UiChrome.popCelShade();
        if(error!=null)throw error;
        if(engine.alerts.unread>0){
            pos.x=Geometry.clamp(x,0,width-90);pos.y=Math.max(0,y-32);size.x=90;size.y=32;ImGui.setNextWindowPos(pos);ImGui.setNextWindowSize(size);
            padding.x=0;padding.y=0;ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding,padding);
            ImGui.pushStyleVar(ImGuiStyleVar.WindowMinSize,tinyMinimum);
            var b=ImGui.begin("##SimpleLFG.Badge",null,flags|ImGuiWindowFlags.NoInputs);if(b)ImGui.textUnformatted(badge);ImGui.end();
            ImGui.popStyleVar(2);
        }
        return clicked;
    }
    /** Click opens the panel; a drag past four pixels moves the window (unless locked) and never counts as a click. */
    function drawButton(c:Config):Bool {
        ImGui.getCursorPos(localPos);
        size.x=BUTTON;size.y=BUTTON;
        var pressed=ImGui.invisibleButton("##openLfg",size);
        var hovered=ImGui.isItemHovered();
        if(ImGui.isItemActive()){
            ImGui.getMousePos(mouse);
            if(!dragging){dragging=true;didDrag=false;grabX=mouse.x-x;grabY=mouse.y-y;}
            if(!c.launcherLocked&&ImGui.isMouseDragging(0,4)){
                didDrag=true;moved=true;
                x=Geometry.clamp(mouse.x-grabX,0,width-extent);y=Geometry.clamp(mouse.y-grabY,0,height-extent);
                c.launcherX=x/width;c.launcherY=y/height;pos.x=x;pos.y=y;ImGui.setWindowPos(pos);
            }
        }else{
            if(dragging&&moved){moved=false;engine.markDirty(now);}
            dragging=false;
        }
        if(pressed&&didDrag)pressed=false;
        var ratio=Geometry.fitScale(art.widths[LauncherArt.BUTTON],art.heights[LauncherArt.BUTTON],BUTTON-8);
        imageSize.x=art.widths[LauncherArt.BUTTON]*ratio;imageSize.y=art.heights[LauncherArt.BUTTON]*ratio;
        imagePos.x=localPos.x+(BUTTON-imageSize.x)/2;imagePos.y=localPos.y+(BUTTON-imageSize.y)/2;
        ImGui.setCursorPos(imagePos);
        if(art.textures[LauncherArt.BUTTON]!=(0:hl.I64))ImGui.image(art.textures[LauncherArt.BUTTON],imageSize,uv0,uv1);else ImGui.text("LFG");
        // Without a background the bounds are invisible, so outline them while the pointer is over the button.
        if(c.launcherTransparent&&hovered&&engine.state.cursorFree){
            corner.x=x+extent;corner.y=y+extent;pos.x=x;pos.y=y;
            ImGui.ImDrawList_AddRect(ImGui.getWindowDrawList(),pos,corner,ImGui.colorConvertFloat4ToU32(ThemePalette.current().accent),6,1.5);
        }
        return pressed;
    }
    /** Same menu shape as the other overlay windows: Lock, Transparent, Reset, plus the hide verb. */
    function drawContextMenu():Void {
        if(!engine.state.cursorFree||Scope.cancelPopups)return;
        if(!ImGui.beginPopupContextWindow(null,1))return;
        var error:Dynamic=null;try menuBody() catch(e:Dynamic)error=e;
        ImGui.endPopup();if(error!=null)throw error;
    }
    function drawMenu():Void {
        var c=engine.config;
        ImGui.separatorText("SimpleLFG button");
        lockRef.set(c.launcherLocked);
        if(ImGui.checkbox("Lock Window##launcherLock",lockRef)){c.launcherLocked=lockRef.get();engine.markDirty(now);}
        transRef.set(c.launcherTransparent);
        if(ImGui.checkbox("Transparent Window##launcherTransparent",transRef)){c.launcherTransparent=transRef.get();engine.markDirty(now);}
        ImGui.separator();
        if(ImGui.menuItem("Reset Position##launcherReset")){c.launcherX=-1;c.launcherY=-1;engine.markDirty(now);}
        if(ImGui.menuItem("Hide Button##launcherHide")){c.launcherEnabled=false;engine.markDirty(now);}
    }
}
