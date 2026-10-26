package simplelfg;

import simplelfg.Types.Activity;
import imgui.ImGui;

@:build(hlx.runtime.Mod.build())
class ModEntry {
    // This fingerprint comes from independent static inspection, not the remote old corpus.
    public static inline var GAME_SHA="9f48618bbcc421458c852c298d5ebec9512bfae8a8381816e0e770803601f1ec";
    static var engine:Engine;
    static var native:NativeChat;
    static var panel:Panel;
    static var store:Store;
    static var lastService:Float=-1;
    static var lastFailure:Float=-1;
    static function main():Void {
        try {
            // One-time boot check before registering any game hook or renderer callback.
            var bytes=sys.io.File.getBytes("hlboot.dat");
            if(haxe.crypto.Sha256.make(bytes).toHex()!=GAME_SHA) {
                trace("SimpleLFG disabled: unsupported Farever build. See SimpleLFG compatibility.json.");return;
            }
            bytes=null;
        } catch(_:Dynamic) {trace("SimpleLFG disabled: cannot verify hlboot.dat.");return;}
        store=new Store();
        native=new NativeChat();
        Catalogue.load();
        engine=new Engine(store.load(),native,new Parser(Catalogue.items));
        engine.relayVisible=false;
        if(engine.config.migrated)engine.markDirty(Sys.time());
        if(store.error!="") engine.status=store.error;
        native.board=engine.board;
        native.install();
        ImGui.register(HlxRuntime.moduleName(),frame);
        trace("SimpleLFG 0.1.12-test loaded. Press F5 to open or close SimpleLFG.");
    }
    static function frame():Void {
        try {
            var now=Sys.time();
            engine.tick(now);
            var error=native.takeError();if(error!=null) engine.report("whisper",error,now);
            if(store.error!="") engine.status=store.error;
            if(panel==null) panel=new Panel(engine,native);
            panel.observe(now);
            if(engine.dirtyAt>=0 && now-engine.dirtyAt>=0.75 && now-lastService>=2) {
                lastService=now;
                if(store.save(engine.config)) engine.dirtyAt=-1;
                else engine.status=store.error;
            }
            panel.draw();
        } catch(e:Dynamic) {
            // Panel's callback-owned scopes unwind before this boundary.
            var time=Sys.time();
            if(lastFailure<0 || time-lastFailure>5) {lastFailure=time;trace("SimpleLFG frame failed: "+Std.string(e));}
        }
    }
}
