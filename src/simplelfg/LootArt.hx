package simplelfg;

import imgui.ImGui;
import imgui.Structs.ImVec2;

class LootFrame {
    public var uv0=new ImVec2();public var uv1=new ImVec2();
    public function new(x:Float,y:Float,w:Float,h:Float,aw:Float,ah:Float){uv0.x=x/aw;uv0.y=y/ah;uv1.x=(x+w)/aw;uv1.y=(y+h)/ah;}
}
/** One embedded texture, loaded only by first-use observation. */
class LootArt {
    public var texture(default,null):hl.I64=0;public var ready(default,null):Bool=false;
    public var plateColor:Int=0;public var borderColor:Int=0;
    var attempted=false;var frames:Map<String,LootFrame>=new Map();var size=new ImVec2();
    var pos=new ImVec2();var corner=new ImVec2();
    public function new(){}
    public function observe():Void {
        if(attempted)return;attempted=true;
        try {
            var raw=haxe.Resource.getBytes("loot-icons");var png=new format.png.Reader(new haxe.io.BytesInput(raw)).read();var h=format.png.Tools.getHeader(png);
            var index=new LootAtlasIndex(haxe.Resource.getString("loot-icon-frames"),h.width,h.height);
            if(!index.valid)throw "Invalid atlas";
            for(id in index.frames.keys()){var f=index.frames.get(id);frames.set(id,new LootFrame(f.x,f.y,f.w,f.h,h.width,h.height));}
            var b=format.png.Tools.extract32(png);var rgba=haxe.io.Bytes.alloc(b.length);for(i in 0...Std.int(b.length/4)){var n=i*4;rgba.set(n,b.get(n+2));rgba.set(n+1,b.get(n+1));rgba.set(n+2,b.get(n));rgba.set(n+3,b.get(n+3));}
            texture=ImGui.registerTexture(rgba.getData(),h.width,h.height,h.width*4);ready=texture!=(0:hl.I64);
        }catch(_:Dynamic){frames.clear();ready=false;}
    }
    public function draw(id:String,pixels:Float):Void {
        var frame=frames.get(id);size.x=pixels;size.y=pixels;
        ImGui.getCursorScreenPos(pos);corner.x=pos.x+pixels;corner.y=pos.y+pixels;
        ImGui.ImDrawList_AddRectFilled(ImGui.getWindowDrawList(),pos,corner,plateColor,5);
        ImGui.ImDrawList_AddRect(ImGui.getWindowDrawList(),pos,corner,borderColor,5,1);
        if(!ready||frame==null){ImGui.button("?##missingLootArt",size);return;}
        ImGui.image(texture,size,frame.uv0,frame.uv1);
    }
}
