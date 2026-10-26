package simplelfg;

import imgui.ImGui;
import imgui.Structs.ImVec2;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Enums.ImGuiStyleVar;

class Launcher {
    var engine:Engine;var art:LauncherArt;
    var pos=new ImVec2();var size=new ImVec2();var localPos=new ImVec2();var imagePos=new ImVec2();
    var imageSize=new ImVec2();var padding=new ImVec2(0,0);var uv0=new ImVec2(0,0);var uv1=new ImVec2(1,1);
    var tinyMinimum=new ImVec2(1,1);
    var badge:String="";
    var width:Float=1920;var height:Float=1080;var now:Float=0;
    public function new(engine:Engine,?art:LauncherArt){this.engine=engine;this.art=art==null?new LauncherArt():art;}
    public function observe(time:Float,w:Float,h:Float):Void {now=time;width=w;height=h;art.observe();badge=engine.alerts.unread>0?"New: "+engine.alerts.unread:"";}
    public function draw():Bool {
        var c=engine.config;if(!c.launcherEnabled||!engine.state.available)return false;
        pos.x=Geometry.launcherX(c,width);pos.y=Geometry.launcherY(c,height);size.x=44;size.y=44;
        ImGui.setNextWindowPos(pos);ImGui.setNextWindowSize(size);
        ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding,padding);
        ImGui.pushStyleVar(ImGuiStyleVar.WindowMinSize,tinyMinimum);
        ImGui.pushStyleVar(ImGuiStyleVar.WindowBorderSize,0);
        var flags=ImGuiWindowFlags.NoTitleBar|ImGuiWindowFlags.NoResize|ImGuiWindowFlags.NoMove|ImGuiWindowFlags.NoSavedSettings|ImGuiWindowFlags.NoScrollbar|ImGuiWindowFlags.NoFocusOnAppearing;
        if(!engine.state.cursorFree)flags|=ImGuiWindowFlags.NoInputs;
        var shown=ImGui.begin("##SimpleLFG.Launcher",null,flags);var error:Dynamic=null;var clicked=false;
        try if(shown){
            ImGui.getCursorPos(localPos);
            clicked=ImGui.invisibleButton("##openLfg",size);
            var ratio=Geometry.fitScale(art.widths[3],art.heights[3],44-8);
            imageSize.x=art.widths[3]*ratio;imageSize.y=art.heights[3]*ratio;
            imagePos.x=localPos.x+(44-imageSize.x)/2;imagePos.y=localPos.y+(44-imageSize.y)/2;
            ImGui.setCursorPos(imagePos);
            if(art.textures[3]!=(0:hl.I64))ImGui.image(art.textures[3],imageSize,uv0,uv1);else ImGui.text("LFG");

        }catch(e:Dynamic)error=e;
        ImGui.end();ImGui.popStyleVar(3);
        if(error!=null)throw error;
        if(engine.alerts.unread>0){
            pos.x=Geometry.clamp(pos.x,0,width-90);pos.y=Math.max(0,pos.y-32);size.x=90;size.y=32;ImGui.setNextWindowPos(pos);ImGui.setNextWindowSize(size);
            ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding,padding);
            ImGui.pushStyleVar(ImGuiStyleVar.WindowMinSize,tinyMinimum);
            var b=ImGui.begin("##SimpleLFG.Badge",null,flags|ImGuiWindowFlags.NoInputs);if(b)ImGui.textUnformatted(badge);ImGui.end();
            ImGui.popStyleVar(2);
        }
        return clicked;
    }
}
