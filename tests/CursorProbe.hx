import simplelfg.InputController.CursorNative;
class CursorProbe {
    static function main():Void {
        // Inspect bindings only: never invoke any primitive, cursor operation or sound.
        var confinement=hl.Api.isPrimLoaded(CursorNative.confinement);
        var owner=hl.Api.isPrimLoaded(CursorNative.guard);
        var sound=hl.Api.isPrimLoaded(CursorNative.sound);
        var mode=Sys.args().length>0?Sys.args()[0]:"new";
        if(confinement!=(mode!="missing")||owner!=(mode=="new")||sound!=(mode=="new"))throw "SFCursor optional import availability mismatch";
        Sys.println("PASS optional SFCursor imports ("+mode+" helper); no primitives invoked");
    }
}
