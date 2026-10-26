package simplelfg;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiChildFlags;
import imgui.Structs.ImVec2;
import simplelfg.UiState.Confirmation;

/** Local playbook vocabulary. Retained scratch geometry; no external UI services. */
class Chrome {
    public var palette:Palette;
    public var rowRightClicked(default,null):Bool=false;
    var a=new ImVec2();var b=new ImVec2();var c=new ImVec2();var d=new ImVec2();
    var textSize=new ImVec2();var available=new ImVec2();var buttonSize=new ImVec2();
    var zero=new ImVec2();var gapSize=new ImVec2();
    public function new(p:Palette)palette=p;
    public function gap(px:Float=8):Void {gapSize.x=0;gapSize.y=px;ImGui.dummy(gapSize);}
    public function card(id:String,size:ImVec2,body:Void->Void):Void {
        ImGui.getCursorScreenPos(a);ImGui.getContentRegionAvail(available);
        b.x=a.x+(size.x<=0?available.x:size.x);b.y=a.y+size.y;
        c.x=a.x+3;c.y=a.y+5;d.x=b.x+3;d.y=b.y+5;
        ImGui.ImDrawList_AddRectFilled(ImGui.getWindowDrawList(),c,d,palette.shadowColor,10);
        ImGui.pushStyleVar(ImGuiStyleVar.ChildRounding,10);ImGui.pushStyleVar(ImGuiStyleVar.ChildBorderSize,1.5);
        ImGui.pushStyleColor(ImGuiCol.ChildBg,palette.surface);ImGui.pushStyleColor(ImGuiCol.Border,palette.border);
        var error:Dynamic=null;
        try Scope.child(id,size,body,ImGuiChildFlags.Borders|ImGuiChildFlags.AlwaysUseWindowPadding) catch(e:Dynamic)error=e;
        ImGui.popStyleColor(2);ImGui.popStyleVar(2);if(error!=null)throw error;
    }
    public function canvas(id:String,size:ImVec2,body:Void->Void):Void {
        ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding,zero);var error:Dynamic=null;
        try Scope.child(id,size,body) catch(e:Dynamic)error=e;
        ImGui.popStyleVar();if(error!=null)throw error;
    }
    public function header(label:String):Void {
        ImGui.pushFont(ImGui.getFont(),ImGui.getFontSize()*1.15);var error:Dynamic=null;
        try drawHeaderContent(label) catch(e:Dynamic)error=e;
        ImGui.popFont();if(error!=null)throw error;
    }
    function drawHeaderContent(label:String):Void {
        ImGui.getCursorScreenPos(a);ImGui.getContentRegionAvail(available);ImGui.calcTextSize(label,false,-1,textSize);
        var height=Math.max(32,ImGui.getFontSize()+12);b.x=a.x+available.x;b.y=a.y+height;
        gapSize.x=available.x;gapSize.y=height+4;ImGui.dummy(gapSize);
        var dl=ImGui.getWindowDrawList();ImGui.ImDrawList_AddRectFilled(dl,a,b,palette.headerColor,6);
        c.x=a.x+1;c.y=a.y+1;d.x=b.x-1;d.y=a.y+height*0.45;ImGui.ImDrawList_AddRectFilled(dl,c,d,palette.shadowColor,6);
        ImGui.ImDrawList_AddRect(dl,a,b,palette.accentColor,6,1);
        c.x=a.x+Math.max(0,(available.x-textSize.x)*0.5);c.y=a.y+(height-textSize.y)*0.5;
        ImGui.pushClipRect(a,b,true);
        ImGui.ImDrawList_AddText_Vec2(dl,c,palette.textColor,label);
        ImGui.popClipRect();
        c.x=a.x+8;c.y=b.y-2;d.x=b.x-8;d.y=c.y;ImGui.ImDrawList_AddLine(dl,c,d,palette.accentColor,1.5);
    }
    public function subHeader(label:String):Void {ImGui.alignTextToFramePadding();ImGui.textUnformatted(label);ImGui.separator();}
    public function actionRow(text:String,action:String,?id:String):Bool {
        if(id!=null)ImGui.pushID_Str(id);var result=false;var error:Dynamic=null;
        try result=actionRowContent(text,action) catch(e:Dynamic)error=e;
        if(id!=null)ImGui.popID();if(error!=null)throw error;return result;
    }
    function actionRowContent(text:String,action:String):Bool {
        ImGui.getContentRegionAvail(available);ImGui.calcTextSize(action,true,-1,textSize);
        var buttonW=textSize.x+20;gapSize.x=Math.max(1,available.x-buttonW-8);gapSize.y=Math.max(28,ImGui.getFontSize()+12);
        ImGui.getCursorScreenPos(a);b.x=a.x+gapSize.x;b.y=a.y+gapSize.y;ImGui.invisibleButton("##rowLabel",gapSize);rowRightClicked=ImGui.isItemClicked(1);
        c.x=a.x;c.y=a.y+(gapSize.y-ImGui.getTextLineHeight())*0.5;
        ImGui.pushClipRect(a,b,true);ImGui.ImDrawList_AddText_Vec2(ImGui.getWindowDrawList(),c,palette.textColor,text);ImGui.popClipRect();
        ImGui.sameLine(0,8);var pressed=button(action);rowRightClicked=rowRightClicked||ImGui.isItemClicked(1);return pressed;
    }
    public function button(label:String,primary:Bool=false,width:Float=0,selected:Bool=false,?id:String):Bool {
        ImGui.calcTextSize(label,true,-1,textSize);buttonSize.x=Math.max(width,textSize.x+20);buttonSize.y=Math.max(28,ImGui.getFontSize()+12);
        if(id!=null)ImGui.pushID_Str(id);
        ImGui.pushStyleVar(ImGuiStyleVar.FrameBorderSize,1);
        ImGui.pushStyleColor(ImGuiCol.Button,primary?palette.accent:(selected?palette.hover:palette.surface));
        var result=false;var error:Dynamic=null;
        try result=ImGui.button(label,buttonSize) catch(e:Dynamic)error=e;
        ImGui.popStyleColor();ImGui.popStyleVar();if(id!=null)ImGui.popID();if(error!=null)throw error;return result;
    }
    public function disabledButton(label:String,disabled:Bool,primary:Bool=false,width:Float=0):Bool {
        ImGui.beginDisabled(disabled);var result=false;var error:Dynamic=null;
        try result=button(label,primary,width) catch(e:Dynamic)error=e;
        ImGui.endDisabled();if(error!=null)throw error;return result;
    }
    public function nav(label:String,selected:Bool):Bool {
        ImGui.pushStyleColor(ImGuiCol.Border,selected?palette.accent:palette.border);
        var result=false;var error:Dynamic=null;try result=button(label,false,0,selected) catch(e:Dynamic)error=e;
        ImGui.popStyleColor();if(error!=null)throw error;
        if(selected){ImGui.getItemRectMin(a);ImGui.getItemRectMax(b);c.x=a.x+5;c.y=b.y-3;d.x=b.x-5;d.y=c.y;ImGui.ImDrawList_AddLine(ImGui.getWindowDrawList(),c,d,palette.accentColor,2);}
        return result;
    }
    public function confirm(label:String,state:Confirmation,id:String):Bool {
        ImGui.pushID_Str(id);var result=false;var error:Dynamic=null;
        try result=button(state.target==id?"Confirm?###confirm":label)&&state.press(id) catch(e:Dynamic)error=e;
        ImGui.popID();if(error!=null)throw error;return result;
    }
    public function note(text:String):Void {
        ImGui.pushStyleColor(ImGuiCol.Text,palette.muted);var error:Dynamic=null;
        try Scope.wrapped(text) catch(e:Dynamic)error=e;ImGui.popStyleColor();if(error!=null)throw error;
    }
    public function status(text:String,kind:Int=3):Void Scope.colored(palette.status(kind),text);
    public function empty(text:String):Void {
        gap(12);ImGui.getContentRegionAvail(available);ImGui.calcTextSize(text,false,available.x,textSize);
        ImGui.setCursorPosX(ImGui.getCursorPosX()+Math.max(0,(available.x-textSize.x)*0.5));note(text);gap(12);
    }
}
