package simplelfg;

import imgui.ImGui;
import imgui.Structs.ImVec2;
import imgui.Structs.ImVec4;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiTableFlags;
import imgui.Enums.ImGuiTableColumnFlags;
import imgui.Enums.ImGuiStyleVar;
import imgui.ref.BoolRef;
import imgui.ref.IntRef;

/** Scope ownership is local to SimpleLFG, including exception unwinding. */
class Scope {
    static final padding=new ImVec2(4,2);
    public static function wrapped(text:String,contextMenu:Bool=true):Void {
        ImGui.pushTextWrapPos();var error:Dynamic=null;
        try {
            ImGui.textUnformatted(text);
            if(contextMenu){
                ImGui.pushID_Str(text);var menuError:Dynamic=null;
                try ContextMenuSystem.text("##textContext",text) catch(e:Dynamic)menuError=e;
                ImGui.popID();if(menuError!=null)throw menuError;
            }
        } catch(e:Dynamic)error=e;
        ImGui.popTextWrapPos();if(error!=null)throw error;
    }
    public static function colored(color:ImVec4,text:String):Void {
        ImGui.pushStyleColor(ImGuiCol.Text,color);var error:Dynamic=null;
        try wrapped(text) catch(e:Dynamic)error=e;
        ImGui.popStyleColor();if(error!=null)throw error;
    }
    public static var cancelPopups:Bool=false;
    public static function child(id:String,size:ImVec2,body:Void->Void,childFlags:Int=0,windowFlags:Int=0):Void {
        var shown=ImGui.beginChild(id,size,childFlags,windowFlags);
        var error:Dynamic=null;
        try {if(shown) body();} catch(e:Dynamic) error=e;
        ImGui.endChild();if(error!=null) throw error;
    }
    public static function tab(label:String,body:Void->Void,flags:Int=0):Void {
        if(!ImGui.beginTabItem(label,null,flags)) return;
        var error:Dynamic=null;
        try body() catch(e:Dynamic) error=e;
        ImGui.endTabItem();if(error!=null) throw error;
    }
    public static function properties(id:String,body:Void->Void):Void {
        ImGui.pushStyleVar(ImGuiStyleVar.CellPadding,padding);
        ImGui.pushStyleVar(ImGuiStyleVar.ItemSpacing,padding);
        if(!ImGui.beginTable(id,2,ImGuiTableFlags.SizingStretchProp|ImGuiTableFlags.BordersOuter|ImGuiTableFlags.BordersInnerH|ImGuiTableFlags.NoSavedSettings)) {ImGui.popStyleVar(2);return;}
        var error:Dynamic=null;
        try {
            ImGui.tableSetupColumn("Label",ImGuiTableColumnFlags.WidthFixed,132);
            ImGui.tableSetupColumn("Value",ImGuiTableColumnFlags.WidthStretch,1);
            body();
        } catch(e:Dynamic) error=e;
        ImGui.endTable();ImGui.popStyleVar(2);if(error!=null) throw error;
    }
    public static function row(label:String):Void {
        ImGui.tableNextRow();ImGui.tableSetColumnIndex(0);ImGui.alignTextToFramePadding();wrapped(label);
        ImGui.tableSetColumnIndex(1);ImGui.setNextItemWidth(-1);
    }
    static var cellIds=["##cell0","##cell1","##cell2"];
    static var inlinePadding=new ImVec2(6,2);
    static var cellAvailable=new ImVec2();
    public static function inlineGroup(id:String,count:Int,cell:Int->Float->Void):Void {
        ImGui.pushStyleVar(ImGuiStyleVar.CellPadding,inlinePadding);
        if(!ImGui.beginTable(id,count,ImGuiTableFlags.SizingStretchProp|ImGuiTableFlags.NoSavedSettings|ImGuiTableFlags.NoPadOuterX)){ImGui.popStyleVar();return;}
        var error:Dynamic=null;
        try {
            for(i in 0...count)ImGui.tableSetupColumn(cellIds[i],ImGuiTableColumnFlags.WidthStretch,1);
            ImGui.tableNextRow();
            for(i in 0...count){ImGui.tableSetColumnIndex(i);ImGui.getContentRegionAvail(cellAvailable);ImGui.pushItemWidth(-1);var e:Dynamic=null;try cell(i,cellAvailable.x) catch(x:Dynamic)e=x;ImGui.popItemWidth();if(e!=null)throw e;}
        }catch(e:Dynamic)error=e;
        ImGui.endTable();ImGui.popStyleVar();if(error!=null)throw error;
    }
    public static function selectable(id:String,label:String,selected:Bool=false):Bool {
        ImGui.pushID_Str(id);var picked=false;var error:Dynamic=null;
        try picked=ImGui.selectable(label,selected) catch(e:Dynamic)error=e;
        ImGui.popID();if(error!=null)throw error;return picked;
    }
    public static function checkbox(id:String,label:String,ref:BoolRef):Bool {
        ImGui.pushID_Str(id);var changed=false;var error:Dynamic=null;
        try changed=ImGui.checkbox(label,ref) catch(e:Dynamic)error=e;
        ImGui.popID();if(error!=null)throw error;return changed;
    }
    public static function color(id:String,buffer:hl.Bytes):Bool {
        ImGui.pushID_Str(id);var changed=false;var error:Dynamic=null;
        try changed=ImGui.colorEdit3("##color",buffer) catch(e:Dynamic)error=e;
        ImGui.popID();if(error!=null)throw error;return changed;
    }
    public static function combo(id:String,label:String,body:Void->Void):Void {
        if(!ImGui.beginCombo(id,label))return;var error:Dynamic=null;
        try {if(cancelPopups)ImGui.closeCurrentPopup();else body();}catch(e:Dynamic)error=e;
        ImGui.endCombo();if(error!=null)throw error;
    }
    /** Individual options avoid the binding's NUL-truncating string conversion. */
    public static function choice(id:String,current:IntRef,options:Array<String>):Bool {
        if(options.length==0)return false;
        var index=current.get();if(index<0||index>=options.length){index=0;current.set(0);}
        if(!ImGui.beginCombo(id,options[index]))return false;
        var changed=false;var error:Dynamic=null;
        try {
            if(cancelPopups)ImGui.closeCurrentPopup();else for(i in 0...options.length){
                ImGui.pushID_Int(i);
                var picked=false;var failure:Dynamic=null;
                try {picked=ImGui.selectable(options[i],i==index);if(i==index)ImGui.setItemDefaultFocus();}catch(e:Dynamic)failure=e;
                ImGui.popID();if(failure!=null)throw failure;
                if(picked&&i!=index){current.set(i);changed=true;}
            }
        }catch(e:Dynamic)error=e;
        ImGui.endCombo();if(error!=null)throw error;return changed;
    }
}
