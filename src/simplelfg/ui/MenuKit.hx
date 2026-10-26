package simplelfg.ui;

import imgui.ImGui;

/** Menu-bar scopes: End runs only when Begin returned true, even if the body throws. */
class MenuKit {
    public static function bar(body:Void->Void):Void {
        if(!ImGui.beginMenuBar())return;
        var error:Dynamic=null;try body() catch(e:Dynamic)error=e;
        ImGui.endMenuBar();if(error!=null)throw error;
    }
    public static function menu(label:String,body:Void->Void,enabled:Bool=true):Void {
        if(!ImGui.beginMenu(label,enabled))return;
        var error:Dynamic=null;try {if(simplelfg.Scope.cancelPopups)ImGui.closeCurrentPopup();else body();}catch(e:Dynamic)error=e;
        ImGui.endMenu();if(error!=null)throw error;
    }
    public static inline function item(label:String,shortcut:String="",selected:Bool=false,enabled:Bool=true):Bool return ImGui.menuItem(label,shortcut,selected,enabled);
}
