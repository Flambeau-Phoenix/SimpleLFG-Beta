package simplelfg;

/** Optional imports preserve loadability with an older shared helper. */
class CursorNative {
    @:hlNative("?sfcursor","sync_confinement") public static function confinement(confined:Bool):Int return -9;
    @:hlNative("?sfcursor","mouse_guard_client") public static function guard(owner:hl.Bytes,enabled:Bool):Int return -9;
    @:hlNative("?sfcursor","notify_sound") public static function sound():Void {}
}
class InputController {
    var owner:hl.Bytes;
    var next:Float=0;
    var lastWanted:Bool=false;
    var checked:Bool=false;var hasConfinement:Bool=false;var hasGuard:Bool=false;var hasSound:Bool=false;
    public var status(default,null):String="SFCursor not checked";
    public var capabilities(default,null):String="";
    public function new(){owner=@:privateAccess "simplelfg".toUtf8();}
    function detect():Void {
        if(checked)return;checked=true;
        hasConfinement=hl.Api.isPrimLoaded(CursorNative.confinement);
        hasGuard=hl.Api.isPrimLoaded(CursorNative.guard);hasSound=hl.Api.isPrimLoaded(CursorNative.sound);
        capabilities="Confinement: "+(hasConfinement?"available":"unavailable")+" | Owner-aware guard: "+(hasGuard?"available":"unavailable")+" | Sound: "+(hasSound?"available":"unavailable");
    }
    public function observe(available:Bool,cursorFree:Bool,wanted:Bool,now:Float):Void {
        detect();
        var active=available&&cursorFree&&wanted;
        // Confinement must release on session/focus loss, even when the addon is closed.
        try {if(hasConfinement) CursorNative.confinement(available&&!cursorFree);} catch(_:Dynamic){}
        if(now<next && active==lastWanted)return;
        next=now+0.05;lastWanted=active;
        try {
            if(!hasGuard){status="Update SFCursor for click-through protection";return;}
            var code=CursorNative.guard(owner,active);
            status=code==1?"SFCursor protection active":(code==0?"SFCursor ready":"SFCursor could not enable protection");
        }catch(_:Dynamic){status="SFCursor protection unavailable";}
    }
    public function playSound():Void {try{detect();if(hasSound)CursorNative.sound();}catch(_:Dynamic){}}
}
