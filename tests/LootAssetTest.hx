import simplelfg.LootAtlasIndex;

class LootAssetTest {
    static var n=0;static function check(v:Bool,label:String):Void {n++;if(!v)throw label;}
    static function main():Void {
        var png=new format.png.Reader(new haxe.io.BytesInput(haxe.Resource.getBytes("loot-icons"))).read();var h=format.png.Tools.getHeader(png);var pixels=format.png.Tools.extract32(png);
        var meta=haxe.Resource.getString("loot-icon-frames");var loot:Dynamic=haxe.Json.parse(sys.io.File.getContent("assets/boss-loot.json"));var ids=[for(i in (cast loot.items:Array<Dynamic>))cast(i.id,String)];
        var index=new LootAtlasIndex(meta,h.width,h.height,ids);check(index.valid,"101 exact covered atlas IDs");
        for(id in ids){var f=index.frames.get(id);check(f!=null&&f.w==96&&f.h==96,"96px portrait "+id);var alpha=false;var nonempty=false;
            for(y in f.y...f.y+f.h)for(x in f.x...f.x+f.w){var a=pixels.get((y*h.width+x)*4+3);if(a<255)alpha=true;if(a>0)nonempty=true;}
            check(alpha&&nonempty,"visible portrait retains alpha "+id);
        }
        check(!new LootAtlasIndex("{bad",h.width,h.height).valid,"corrupt metadata returns fallback");
        check(!new LootAtlasIndex(meta,h.width+1,h.height).valid,"mismatched dimensions fallback");
        var bad:Dynamic=haxe.Json.parse(meta);Reflect.field(bad.frames,ids[0]).x=-1;check(!new LootAtlasIndex(haxe.Json.stringify(bad),h.width,h.height).valid,"invalid UV fallback");
        Reflect.deleteField(bad.frames,ids[0]);check(!new LootAtlasIndex(haxe.Json.stringify(bad),h.width,h.height).valid,"missing icon fallback");
        Sys.println("PASS "+n+" boss-only item atlas and corrupt-asset checks");
    }
}
