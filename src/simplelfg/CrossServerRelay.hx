package simplelfg;

import simplelfg.RelayTransport;

/** Existing 1.1 wire protocol; results are drained by the game-thread observation loop. */
class CrossServerRelay {
    public static final DEFAULT_ENDPOINT="https://webgameuniverse.com";
    public var generation(default,null):Int=0;
    var transport:RelayTransport;
    var events:RelayEventStream=null;
    public var sessionId(default,null):String="";
    var token:String="";
    public function new(?transport:RelayTransport){
        if(transport==null)events=new RelayEventStream(DEFAULT_ENDPOINT);
        this.transport=transport==null?new RelayWorkerTransport(DEFAULT_ENDPOINT):transport;
    }
    public function reset():Void {generation++;transport.cancel();stopEvents();sessionId="";token="";}
    public function suspend():Void {generation++;transport.cancel();stopEvents();}
    public function startEvents():Bool {if(events==null||sessionId=="")return false;try events.start(generation,token) catch(_:Dynamic)return false;return true;}
    public function stopEvents():Void {if(events!=null)events.cancel();}
    public function hasResults():Bool return transport.hasResults()||(events!=null&&events.hasResults());
    public function fetchListings():Bool return transport.submit({generation:generation,kind:"listings",path:"/api/lfg/listings",body:null});
    public function post(body:String):Bool return transport.submit({generation:generation,kind:"post",path:"/api/lfg/post",body:body,token:token});
    public function connect(host:String,steam:String):Bool {
        var body=haxe.Json.stringify({host:RelayProtocol.clean(host),steam_id:steam});
        return transport.submit({generation:generation,kind:"session",path:"/api/lfg/session",body:body});
    }
    public function acceptSession(raw:String):Bool {
        try {
            var data:Dynamic=haxe.Json.parse(raw);var id:Dynamic=Reflect.field(data,"session_id"),value:Dynamic=Reflect.field(data,"token");
            if(!Std.isOfType(id,String)||!Std.isOfType(value,String)||!~/^[0-9a-f]{32}$/.match(id)||!~/^[0-9a-f]{32}\.[0-9a-f]{64}$/.match(value)||!StringTools.startsWith(value,id+"."))return false;
            sessionId=id;token=value;return true;
        }catch(_:Dynamic){return false;}
    }
    public function inbox(after:Int):Bool return transport.submit({generation:generation,kind:"inbox",path:"/api/lfg/chat?after="+after,body:null,token:token});
    public function privacy(share:Bool):Bool {
        var body=haxe.Json.stringify({share_steam_public:share});
        return transport.submit({generation:generation,kind:"privacy",path:"/api/lfg/privacy",body:body,token:token});
    }
    public function send(recipient:String,message:String):Bool {
        if(sessionId=="")return false;
        var body=haxe.Json.stringify({recipient_id:recipient,message:message});
        return transport.submit({generation:generation,kind:"message",path:"/api/lfg/chat",body:body,token:token});
    }
    public function drain():Array<RelayResult> {
        var rows=transport.drain();if(events!=null&&events.hasResults())for(row in events.drain())rows.push(row);return rows;
    }
}
