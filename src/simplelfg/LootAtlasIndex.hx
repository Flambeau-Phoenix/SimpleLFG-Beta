package simplelfg;

typedef LootAtlasRect={var x:Int;var y:Int;var w:Int;var h:Int;}
class LootAtlasIndex {
    public var valid(default,null):Bool=false;public var frames(default,null):Map<String,LootAtlasRect>=new Map();
    public function new(raw:String,width:Int,height:Int,?expected:Array<String>){
        try {
            var meta:Dynamic=haxe.Json.parse(raw);if(meta.width!=width||meta.height!=height||width<=0||height<=0||width>2048||height>2048)throw "Size";
            var ids=Reflect.fields(meta.frames);if(ids.length!=101)throw "Coverage";
            for(id in ids){var f:Dynamic=Reflect.field(meta.frames,id);for(key in ["x","y","w","h"]){var n:Dynamic=Reflect.field(f,key);if(!Std.isOfType(n,Int))throw "Coordinate";}
                if(f.x<0||f.y<0||f.w<=0||f.h<=0||f.x+f.w>width||f.y+f.h>height)throw "Bounds";
                if(expected!=null&&expected.indexOf(id)<0)throw "Unexpected item";frames.set(id,{x:f.x,y:f.y,w:f.w,h:f.h});
            }
            if(expected!=null&&expected.length!=ids.length)throw "Missing item";valid=true;
        }catch(_:Dynamic){frames.clear();valid=false;}
    }
}
