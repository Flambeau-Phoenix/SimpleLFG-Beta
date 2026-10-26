package simplelfg;

import imgui.ImGui;
import imgui.Structs.ImVec2;
import imgui.Structs.ImVec4;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiStyleVar;

/** Full local style scope: no inherited transparent popup/title surfaces. */
class Palette {
    public var bg=new ImVec4();public var surface=new ImVec4();public var text=new ImVec4();
    public var muted=new ImVec4();public var accent=new ImVec4();public var hover=new ImVec4();
    public var border=new ImVec4();public var title=new ImVec4();
    public var textColor:Int=0;public var mutedColor:Int=0;public var accentColor:Int=0;public var headerColor:Int=0;public var shadowColor:Int=0x33000000;
    public var successColor:Int=0;public var dangerColor:Int=0;
    var statuses:Array<ImVec4>=[new ImVec4(),new ImVec4(),new ImVec4(),new ImVec4()];
    var titleAlign=new ImVec2(0.5,0.5);
    var padding=new ImVec2(12,10);var spacing=new ImVec2(8,6);var frames=new ImVec2(8,5);
    public function new(){}
    static function rgb(v:Int,out:ImVec4,alpha:Float=1):Void {out.x=((v>>16)&255)/255;out.y=((v>>8)&255)/255;out.z=(v&255)/255;out.w=alpha;}
    public function observe(c:Config):Void {
        rgb(c.background,bg,c.opacity);rgb(c.surface,surface);rgb(c.foreground,text);rgb(c.accent,accent);
        if(c.highContrast){rgb(0xFFFFFF,text);rgb(0x000000,bg);rgb(0x171717,surface);}
        muted.x=text.x*0.67;muted.y=text.y*0.67;muted.z=text.z*0.67;muted.w=1;
        hover.x=surface.x*0.82+accent.x*0.18;hover.y=surface.y*0.82+accent.y*0.18;hover.z=surface.z*0.82+accent.z*0.18;hover.w=1;
        border.x=accent.x*0.55;border.y=accent.y*0.55;border.z=accent.z*0.55;border.w=1;
        title.x=surface.x;title.y=surface.y;title.z=surface.z;title.w=1;
        textColor=ImGui.colorConvertFloat4ToU32(text);mutedColor=ImGui.colorConvertFloat4ToU32(muted);
        accentColor=ImGui.colorConvertFloat4ToU32(accent);headerColor=ImGui.colorConvertFloat4ToU32(hover);
        var light=bg.x*0.299+bg.y*0.587+bg.z*0.114>0.55;
        rgb(light?0x198038:0x73D991,statuses[0]);rgb(light?0x9E6600:0xF2C259,statuses[1]);
        rgb(light?0xB82424:0xFF8787,statuses[2]);rgb(light?0x145FB2:0x8CCBFF,statuses[3]);
        successColor=ImGui.colorConvertFloat4ToU32(statuses[0]);dangerColor=ImGui.colorConvertFloat4ToU32(statuses[2]);
    }
    public function status(kind:Int):ImVec4 return statuses[kind<0||kind>3?3:kind];
    public static function preset(c:Config,name:String):Void {
        c.theme=name;
        switch(name){
            case "Slate":c.background=0x171B20;c.surface=0x29313B;c.accent=0x6D9BAD;c.foreground=0xEDF1F5;
            case "Warm":c.background=0x211B18;c.surface=0x342A24;c.accent=0xBE914D;c.foreground=0xF1E9DD;
            default:c.background=0x101720;c.surface=0x1B2836;c.accent=0x4388BD;c.foreground=0xE7EEF6;
        }
    }
    public function push():Void {
        ImGui.pushStyleVar(ImGuiStyleVar.Alpha,1);
        ImGui.pushStyleColor(ImGuiCol.Text,text);ImGui.pushStyleColor(ImGuiCol.TextDisabled,muted);
        ImGui.pushStyleColor(ImGuiCol.WindowBg,bg);ImGui.pushStyleColor(ImGuiCol.PopupBg,title);
        ImGui.pushStyleColor(ImGuiCol.ChildBg,surface);ImGui.pushStyleColor(ImGuiCol.Border,border);
        ImGui.pushStyleColor(ImGuiCol.TitleBg,title);ImGui.pushStyleColor(ImGuiCol.TitleBgActive,title);
        ImGui.pushStyleColor(ImGuiCol.FrameBg,surface);ImGui.pushStyleColor(ImGuiCol.FrameBgHovered,hover);
        ImGui.pushStyleColor(ImGuiCol.FrameBgActive,accent);ImGui.pushStyleColor(ImGuiCol.Button,surface);
        ImGui.pushStyleColor(ImGuiCol.ButtonHovered,hover);ImGui.pushStyleColor(ImGuiCol.ButtonActive,accent);
        ImGui.pushStyleColor(ImGuiCol.Header,hover);ImGui.pushStyleColor(ImGuiCol.HeaderHovered,hover);
        ImGui.pushStyleColor(ImGuiCol.HeaderActive,accent);ImGui.pushStyleColor(ImGuiCol.CheckMark,text);
        ImGui.pushStyleColor(ImGuiCol.Tab,surface);ImGui.pushStyleColor(ImGuiCol.TabSelected,accent);
        ImGui.pushStyleColor(ImGuiCol.TabHovered,hover);ImGui.pushStyleColor(ImGuiCol.Separator,border);
        ImGui.pushStyleColor(ImGuiCol.SliderGrab,accent);ImGui.pushStyleColor(ImGuiCol.SliderGrabActive,hover);
        ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding,padding);ImGui.pushStyleVar(ImGuiStyleVar.ItemSpacing,spacing);
        ImGui.pushStyleVar(ImGuiStyleVar.FramePadding,frames);ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding,4);
        ImGui.pushStyleVar(ImGuiStyleVar.PopupRounding,6);ImGui.pushStyleVar(ImGuiStyleVar.WindowRounding,6);
        ImGui.pushStyleVar(ImGuiStyleVar.WindowBorderSize,1);
        ImGui.pushStyleVar(ImGuiStyleVar.WindowTitleAlign,titleAlign);ImGui.pushStyleVar(ImGuiStyleVar.FrameBorderSize,1);
    }
    public function pop():Void {ImGui.popStyleVar(10);ImGui.popStyleColor(24);}
}
