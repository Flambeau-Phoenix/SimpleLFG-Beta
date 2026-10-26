package simplelfg;

import imgui.ImGui;

/** Clipboard work runs at observation and is cancelled when the session closes. */
class UiActionQueue {
    static var queue:Array<{copy:String,target:TextBuffer,clear:Bool}>=[];
    static var session="";
    public static function reset():Void queue.resize(0);
    public static function copy(text:String):Void {if(queue.length<16)queue.push({copy:text,target:null,clear:false});}
    public static function paste(target:TextBuffer):Void {if(queue.length<16)queue.push({copy:null,target:target,clear:false});}
    public static function clear(target:TextBuffer):Void {if(queue.length<16)queue.push({copy:null,target:target,clear:true});}
    public static function observe(id:String,active:Bool):Void {
        if(session!=id||!active){reset();session=id;return;}
        while(queue.length>0){var work=queue.shift();try {
            if(work.target==null)ImGui.setClipboardText(work.copy);
            else {var bytes=work.clear?null:ImGui.getClipboardText();work.target.edit(bytes==null?"":@:privateAccess String.fromUTF8(bytes));}
        }catch(_:Dynamic){}}
    }
}
