package simplelfg;

/** Optional imports preserve loadability with an older shared helper. */
class CursorNative {
    @:hlNative("?sfcursor","sync_confinement") public static function confinement(confined:Bool):Int return -9;
    @:hlNative("?sfcursor","mouse_guard_client") public static function guard(owner:hl.Bytes,enabled:Bool):Int return -9;
    @:hlNative("?sfcursor","notify_sound") public static function sound():Void {}
    @:hlNative("?sfcursor","input_policy_client") public static function policy(owner:hl.Bytes,available:Bool,cursorFree:Bool,interactive:Bool):Int return -9;
}
class InputController {
    var owner:hl.Bytes;
    var next:Float=0;
    var lastWanted:Bool=false;
    var hasPolicy=false;var available=false;var free=false;
    var checked:Bool=false;var hasConfinement:Bool=false;var hasGuard:Bool=false;var hasSound:Bool=false;
    public var status(default,null):String="SFCursor not checked";
    public var capabilities(default,null):String="";
    public function new(){owner=@:privateAccess "simplelfg".toUtf8();}
    function detect():Void {
        if(checked)return;checked=true;
        hasConfinement=hl.Api.isPrimLoaded(CursorNative.confinement);
        hasGuard=hl.Api.isPrimLoaded(CursorNative.guard);hasSound=hl.Api.isPrimLoaded(CursorNative.sound);
        hasPolicy=hl.Api.isPrimLoaded(CursorNative.policy);
        capabilities="Confinement: "+(hasConfinement?"available":"unavailable")+" | Owner-aware guard: "+(hasGuard?"available":"unavailable")+" | Sound: "+(hasSound?"available":"unavailable");
    }
    public function observe(available:Bool,cursorFree:Bool,wanted:Bool,now:Float):Void {
        detect();
        this.available=available;free=cursorFree;
        var active=available&&cursorFree&&wanted;
        if(now<next && active==lastWanted)return;
        next=now+0.05;lastWanted=active;
        try {
            if(!hasGuard){status="Update SFCursor for click-through protection";return;}
            var code=CursorNative.guard(owner,active);
            status=code==1?"SFCursor protection active":(code==0?"SFCursor ready":"SFCursor could not enable protection");
        }catch(_:Dynamic){status="SFCursor protection unavailable";}
    }
    public function playSound():Void {try{detect();if(hasSound)CursorNative.sound();}catch(_:Dynamic){}}
    /** Called after all windows; native policy owns the shared IO mutation. */
    public function finishFrame(interactive:Bool):Void {
        try {detect();if(hasPolicy)CursorNative.policy(owner,available,free,interactive);}catch(_:Dynamic){}
        try {if(hasConfinement)CursorNative.confinement(available&&!free);}catch(_:Dynamic){}
    }
}
