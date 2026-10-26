package simplelfg;

import imgui.ImGui;

/** Callback owns the popup scope. Explicit right-click avoids binding flag ambiguity. */
class ContextMenuSystem {
    public static function openForItem(id:String):Bool {
        if(Scope.cancelPopups)return false;
        if(ImGui.isItemClicked(1)){ImGui.openPopup(id);return true;}return false;
    }
    public static function draw(id:String,body:Void->Void,valid:Bool=true):Void {
        if(!ImGui.beginPopup(id))return;
        var error:Dynamic=null;
        try {if(Scope.cancelPopups||!valid)ImGui.closeCurrentPopup();else body();}catch(e:Dynamic)error=e;
        ImGui.endPopup();if(error!=null)throw error;
    }
    public static function text(id:String,text:String):Void {
        openForItem(id);
        if(!ImGui.beginPopup(id))return;
        var error:Dynamic=null;
        try {if(Scope.cancelPopups)ImGui.closeCurrentPopup();else if(ImGui.menuItem("Copy text"))UiActionQueue.copy(text);}catch(e:Dynamic)error=e;
        ImGui.endPopup();if(error!=null)throw error;
    }
}
