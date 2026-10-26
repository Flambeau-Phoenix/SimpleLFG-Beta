import simplelfg.TextBuffer;

class NativeCoreTest {
    static var n=0;
    static function eq(a:String,b:String):Void {n++;if(a!=b) throw 'UTF-8 buffer mismatch: "$a" != "$b"';}
    static function main():Void {
        var b=new TextBuffer(8,"abc");eq(b.get(),"abc");
        b.set("100% ##");eq(b.get(),"100% ##");
        b.set("abcdefghijk");eq(b.get(),"abcdefg");
        b.set("été");eq(b.get(),"été");
        b.set("abcdefé");eq(b.get(),"abcdef");
        b.set("abc😀");eq(b.get(),"abc😀");
        b.set("abcd😀");eq(b.get(),"abcd");
        b.set("");eq(b.get(),"");
        b.set(null);eq(b.get(),"");
        Sys.println("PASS "+n+" native UTF-8 buffer checks");
    }
}
