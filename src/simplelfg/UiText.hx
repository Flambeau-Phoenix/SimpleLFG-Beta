package simplelfg;

import imgui.ImGui;
import imgui.Structs.ImVec2;

/** Portable input menus and multiline editors, with retained geometry. */
class UiText {
    static var size=new ImVec2();
    public static function input(id:String,hint:String,buffer:TextBuffer,multiline:Bool=false):Bool {
        var changed=buffer.takeEdit();
        if(multiline){size.x=-1;size.y=ImGui.getTextLineHeight()*3+16;changed=ImGui.inputTextMultiline(id,buffer.bytes,buffer.size,size)||changed;}
        else changed=ImGui.inputTextWithHint(id,hint,buffer.bytes,buffer.size)||changed;
        ImGui.pushID_Str(id);var error:Dynamic=null;
        try {
            ContextMenuSystem.openForItem("##inputMenu");
            if(ImGui.beginPopup("##inputMenu")){
                var inner:Dynamic=null;
                try {if(Scope.cancelPopups)ImGui.closeCurrentPopup();else {
                    if(ImGui.menuItem("Copy all"))UiActionQueue.copy(buffer.get());
                    if(ImGui.menuItem("Paste (replace all)"))UiActionQueue.paste(buffer);
                    if(ImGui.menuItem("Clear"))UiActionQueue.clear(buffer);
                }}catch(e:Dynamic)inner=e;
                ImGui.endPopup();if(inner!=null)throw inner;
            }
        }catch(e:Dynamic)error=e;
        ImGui.popID();if(error!=null)throw error;return changed;
    }
}
