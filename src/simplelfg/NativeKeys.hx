package simplelfg;

/** Read-only look at Farever's own key bindings, so a chosen panel key can be checked for clashes. */
class NativeKeys {
    static function constant(name:String):String {
        if(name.length>=2&&name.charAt(0)=="F"&&name.charCodeAt(1)>=48&&name.charCodeAt(1)<=57)return name;
        if(StringTools.startsWith(name,"Keypad")){
            var rest=name.substr(6);
            return switch(rest){case "Decimal":"NUMPAD_DOT";case "Divide":"NUMPAD_DIV";case "Multiply":"NUMPAD_MULT";case "Subtract":"NUMPAD_SUB";case "Add":"NUMPAD_ADD";default:"NUMPAD_"+rest;}
        }
        return switch(name){
            case "Insert":"INSERT";case "Home":"HOME";case "End":"END";case "PageUp":"PGUP";case "PageDown":"PGDOWN";
            case "Pause":"PAUSE_BREAK";case "ScrollLock":"SCROLL_LOCK";case "GraveAccent":"QWERTY_TILDE";
            default:name.length==1&&name.charCodeAt(0)>=48&&name.charCodeAt(0)<=57?"NUMBER_"+name:name;
        }
    }
    /** Engine key code for a panel key name, or -1. Resolve once per change, not per frame. */
    public static function gameCode(name:String):Int {
        try {var value:Dynamic=HlxRuntime.resolveStaticField(HlxRuntime.resolveType("hxd.Key"),constant(name));if(Std.isOfType(value,Int))return value;}catch(_:Dynamic){}
        return -1;
    }
    /** Observation phase only. Returns the first action bound to the same key, or "" when free or unreadable. */
    public static function clash(name:String,mods:Int):String {
        var code=gameCode(name);if(code<0)return "";
        try {
            for(map in [lib.Input.userBinds,lib.Input.defaultBinds]){
                if(map==null)continue;var keys=map.keys();if(keys==null)continue;var seen=0;
                while(keys.hasNext()){
                    if(++seen>512)break;var id=Std.string(keys.next());
                    var list=lib.Input.getBindings(id);if(list==null||list.length>32)continue;
                    var raws:Array<Dynamic>=[];for(i in 0...list.length)raws.push(list.getDyn(i));
                    for(raw in raws){
                        if(raw==null)continue;
                        var c:Dynamic=HlxRuntime.resolveField(raw,"code");var m:Dynamic=HlxRuntime.resolveField(raw,"modifier");
                        var modified=m!=null&&Std.isOfType(m,Int)&&(m:Int)!=0;
                        if(Std.isOfType(c,Int)&&(c:Int)==code&&modified==(mods!=0))return id;
                    }
                }
            }
        }catch(_:Dynamic){}
        return "";
    }
}
