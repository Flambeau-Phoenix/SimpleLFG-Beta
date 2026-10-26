class AssetTest {
    static function main():Void {
        var checks=0;
        for(name in ["logo3"]){
            var bytes=haxe.Resource.getBytes(name);
            var png=new format.png.Reader(new haxe.io.BytesInput(bytes)).read();var h=format.png.Tools.getHeader(png);
            var bgra=format.png.Tools.extract32(png);
            if(h.width<=0||h.height<=0||h.width>512||h.height>512||bgra.length!=h.width*h.height*4)throw "Invalid launcher PNG "+name;
            var transparent=false;for(i in 0...Std.int(bgra.length/4))if(bgra.get(i*4+3)<255){transparent=true;break;}
            if(!transparent)throw "Launcher image lost transparency: "+name;
            checks++;Sys.println(name+": "+h.width+"x"+h.height+", RGBA+alpha decoded");
        }
        Sys.println("PASS "+checks+" Chat button artwork checks");
    }
}
