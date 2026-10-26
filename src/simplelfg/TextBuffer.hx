package simplelfg;

/** Retained UTF-8, NUL-terminated native ImGui input buffer. */
class TextBuffer {
    public var bytes(default,null):hl.Bytes;
    public var size(default,null):Int;
    var edited=false;
    public function edit(value:String):Void {set(value);edited=true;}
    public function takeEdit():Bool {var value=edited;edited=false;return value;}
    public function new(size:Int,value:String="") {this.size=size;bytes=new hl.Bytes(size);set(value);}
    public function set(value:String):Void {
        var b=haxe.io.Bytes.ofString(value==null?"":value);
        var n=Std.int(Math.min(size-1,b.length));
        // Back up from a partial UTF-8 sequence at the boundary.
        if(n<b.length) while(n>0 && (b.get(n)&0xC0)==0x80) n--;
        bytes.fill(0,size,0);bytes.blit(0,b.getData(),0,n);
    }
    public function get():String {
        var n=0;while(n<size && bytes.getUI8(n)!=0) n++;
        return @:privateAccess String.fromUTF8(bytes);
    }
}
