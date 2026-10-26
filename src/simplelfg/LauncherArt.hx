package simplelfg;

import imgui.ImGui;

class LauncherArt {
    public static inline var BUTTON=3;
    public static inline var WORDMARK=4;
    static var resources=[null,null,null,"logo3","simplelfg-logo"];
    public var textures(default,null):Array<hl.I64>=[0,0,0,0,0];
    public var widths(default,null):Array<Int>=[1,1,1,1,1];
    public var heights(default,null):Array<Int>=[1,1,1,1,1];
    var loaded:Bool=false;
    public function new(){}
    public function observe():Void {
        if(loaded)return;loaded=true;
        for(i in 3...5)try {
            var raw=haxe.Resource.getBytes(resources[i]);
            var data=new format.png.Reader(new haxe.io.BytesInput(raw)).read();
            var header=format.png.Tools.getHeader(data);
            if(header.width<=0||header.height<=0||header.width>512||header.height>512)continue;
            widths[i]=header.width;heights[i]=header.height;
            var b=format.png.Tools.extract32(data);var rgba=haxe.io.Bytes.alloc(b.length);
            for(p in 0...Std.int(b.length/4)){var n=p*4;rgba.set(n,b.get(n+2));rgba.set(n+1,b.get(n+1));rgba.set(n+2,b.get(n));rgba.set(n+3,b.get(n+3));}
            textures[i]=ImGui.registerTexture(rgba.getData(),header.width,header.height,header.width*4);
        }catch(_:Dynamic){}
    }
}
