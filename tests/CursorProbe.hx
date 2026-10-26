import simplelfg.InputController.CursorNative;
class CursorProbe {
    static function main():Void {
        // Inspect bindings only: never invoke any primitive, cursor operation or sound.
        var confinement=hl.Api.isPrimLoaded(CursorNative.confinement);
        var owner=hl.Api.isPrimLoaded(CursorNative.guard);
        var sound=hl.Api.isPrimLoaded(CursorNative.sound);
        var policy=hl.Api.isPrimLoaded(CursorNative.policy);
        var mode=Sys.args().length>0?Sys.args()[0]:"new";
        if(confinement!=(mode!="missing")||owner!=(mode=="new"||mode=="previous")||sound!=(mode=="new"||mode=="previous"))throw "SFCursor optional import availability mismatch";
        if(policy!=(mode=="new"))throw "Shared input policy optional import mismatch";
        Sys.println("PASS optional SFCursor imports ("+mode+" helper); no primitives invoked");
    }
}
