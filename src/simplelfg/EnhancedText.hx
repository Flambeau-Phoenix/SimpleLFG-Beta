package simplelfg;

import imgui.ImGui;
import imgui.Structs.ImVec2;

/** Title shadow adapted to retained geometry and the local theme. */
class EnhancedText {
    static var offset=new ImVec2();
    public static function shadowed(dl:imgui.ImGui.ImDrawList,pos:ImVec2,text:String,color:Int,shadow:Int):Void {
        offset.x=pos.x+1;offset.y=pos.y+1;
        ImGui.ImDrawList_AddText_Vec2(dl,offset,shadow,text);
        ImGui.ImDrawList_AddText_Vec2(dl,pos,color,text);
    }
}
