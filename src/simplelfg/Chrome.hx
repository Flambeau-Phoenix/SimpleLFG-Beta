package simplelfg;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiChildFlags;
import imgui.Structs.ImVec2;
import simplelfg.UiState.Confirmation;
import simplelfg.ui.UiChrome;

/** Local playbook vocabulary. Retained scratch geometry; no external UI services. */
class Chrome {
    public var palette:Palette;
    public var rowRightClicked(default,null):Bool=false;
    var a=new ImVec2();var b=new ImVec2();var c=new ImVec2();var d=new ImVec2();
    var textSize=new ImVec2();var available=new ImVec2();var buttonSize=new ImVec2();
    var zero=new ImVec2();var gapSize=new ImVec2();
    public function new(p:Palette)palette=p;
    public function gap(px:Float=8):Void {gapSize.x=0;gapSize.y=px;ImGui.dummy(gapSize);}
    /** Cel-shaded card from the shared kit: themed border, rounding and drop shadow. */
    public function card(id:String,size:ImVec2,body:Void->Void):Void UiChrome.celChild(id,size,body);
    /** Padding-free container for card layouts. Only the container itself drops its padding; the cards inside keep the window padding. */
    public function canvas(id:String,size:ImVec2,body:Void->Void):Void {
        ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding,zero);
        var shown=ImGui.beginChild(id,size,0,0);
        ImGui.popStyleVar();
        var error:Dynamic=null;try {if(shown)body();}catch(e:Dynamic)error=e;
        ImGui.endChild();if(error!=null)throw error;
    }
    public function header(label:String):Void UiChrome.centeredHeader(label);
    public function subHeader(label:String):Void UiChrome.subHeader(label);
    public function actionRow(text:String,action:String,?id:String):Bool {
        if(id!=null)ImGui.pushID_Str(id);var result=false;var error:Dynamic=null;
        try result=actionRowContent(text,action) catch(e:Dynamic)error=e;
        if(id!=null)ImGui.popID();if(error!=null)throw error;return result;
    }
    function actionRowContent(text:String,action:String):Bool {
        ImGui.getContentRegionAvail(available);ImGui.calcTextSize(action,true,-1,textSize);
        var buttonW=textSize.x+20;gapSize.x=Math.max(1,available.x-buttonW-8);
        ImGui.calcTextSize(text,false,gapSize.x,textSize);gapSize.y=Math.max(28,textSize.y+12);
        ImGui.getCursorScreenPos(a);b.x=a.x+gapSize.x;b.y=a.y+gapSize.y;ImGui.invisibleButton("##rowLabel",gapSize);rowRightClicked=ImGui.isItemClicked(1);
        c.x=a.x;c.y=a.y+(gapSize.y-ImGui.getTextLineHeight())*0.5;
        ImGui.pushClipRect(a,b,true);ImGui.setCursorScreenPos(c);
        ImGui.pushTextWrapPos(ImGui.getCursorPosX()+gapSize.x);var error:Dynamic=null;
        try ImGui.textUnformatted(text) catch(e:Dynamic)error=e;
        ImGui.popTextWrapPos();ImGui.popClipRect();if(error!=null)throw error;
        c.x=b.x+8;c.y=a.y;ImGui.setCursorScreenPos(c);var pressed=button(action);rowRightClicked=rowRightClicked||ImGui.isItemClicked(1);
        c.x=a.x;c.y=a.y+gapSize.y-2;ImGui.setCursorScreenPos(c);ImGui.dummy(zero);return pressed;
    }
    public function button(label:String,primary:Bool=false,width:Float=0,selected:Bool=false,?id:String):Bool {
        ImGui.calcTextSize(label,true,-1,textSize);buttonSize.x=Math.max(width,textSize.x+24);buttonSize.y=Math.max(28,ImGui.getFontSize()+12);
        if(id!=null)ImGui.pushID_Str(id);
        var result=false;var error:Dynamic=null;
        try result=primary?UiChrome.accentButton(label,buttonSize):(selected?UiChrome.navButton(label,true,buttonSize):UiChrome.ghostButton(label,buttonSize)) catch(e:Dynamic)error=e;
        if(id!=null)ImGui.popID();if(error!=null)throw error;return result;
    }
    public function disabledButton(label:String,disabled:Bool,primary:Bool=false,width:Float=0):Bool {
        ImGui.beginDisabled(disabled);var result=false;var error:Dynamic=null;
        try result=button(label,primary,width) catch(e:Dynamic)error=e;
        ImGui.endDisabled();if(error!=null)throw error;return result;
    }
    public function nav(label:String,selected:Bool):Bool return button(label,false,0,selected);
    public function confirm(label:String,state:Confirmation,id:String):Bool {
        ImGui.pushID_Str(id);var result=false;var error:Dynamic=null;
        try result=button(state.target==id?"Confirm?###confirm":label)&&state.press(id) catch(e:Dynamic)error=e;
        ImGui.popID();if(error!=null)throw error;return result;
    }
    public function note(text:String,contextMenu:Bool=true):Void {
        ImGui.pushStyleColor(ImGuiCol.Text,palette.muted);var error:Dynamic=null;
        try Scope.wrapped(text,contextMenu) catch(e:Dynamic)error=e;ImGui.popStyleColor();if(error!=null)throw error;
    }
    public function status(text:String,kind:Int=3):Void Scope.colored(palette.status(kind),text);
    public function empty(text:String):Void {
        gap(12);ImGui.getContentRegionAvail(available);ImGui.calcTextSize(text,false,available.x,textSize);
        ImGui.setCursorPosX(ImGui.getCursorPosX()+Math.max(0,(available.x-textSize.x)*0.5));note(text);gap(12);
    }
}
