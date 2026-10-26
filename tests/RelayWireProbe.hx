import simplelfg.RelayWorkerTransport;
import simplelfg.RelayEventStream;
import simplelfg.CrossServerRelay;
import simplelfg.RelayTransport;

/** Loopback-only writes; no-argument mode performs only a certificate-verified public GET. */
class RelayWireProbe {
    static function main():Void {
        var args=Sys.args();var publicRead=args.length==0||args[0]=="public-read";
        var base=publicRead?CrossServerRelay.DEFAULT_ENDPOINT:"http://127.0.0.1:"+args[0];
        var transport=new RelayWorkerTransport(base);
        function perform(path:String,body:Null<String>=null,token:String=""):RelayResult {
            if(!transport.submit({generation:1,kind:"probe",path:path,body:body,token:token}))throw "Worker queue full.";
            var deadline=Sys.time()+20;
            while(Sys.time()<deadline){if(transport.hasResults()){var result=transport.drain()[0];if(result.error!="")throw result.error;return result;}Sys.sleep(.01);}
            throw "Fixture timed out.";
        }
        var read=perform("/api/lfg/listings");
        if(!Std.isOfType(haxe.Json.parse(read.body),Array))throw "Invalid listings.";
        if(publicRead){Sys.println("PASS certificate-verified public HTTPS GET");return;}
        var a:Dynamic=haxe.Json.parse(perform("/api/lfg/session",haxe.Json.stringify({host:"Fixture Hero",steam_id:""})).body);
        var b:Dynamic=haxe.Json.parse(perform("/api/lfg/session",haxe.Json.stringify({host:"Recipient",steam_id:""})).body);
        var stream=new RelayEventStream(base);stream.start(1,b.token);
        function waitEvent(kind:String):Void {
            var deadline=Sys.time()+5;
            while(Sys.time()<deadline){if(stream.hasResults())for(result in stream.drain()){
                if(result.kind==kind)return;if(result.kind=="event_closed")throw result.error;
            }Sys.sleep(.01);}
            throw "Missing native event: "+kind;
        }
        waitEvent("event_sync");
        var posted:Dynamic=haxe.Json.parse(perform("/api/lfg/post",haxe.Json.stringify({player_class:"Mage",host:"Fixture Hero",steam_id:"",activity:"Crabgantua's Gorge",undefined:3,note:"Normal / Café"}),a.token).body);
        if(posted.listing.player_class!="Mage")throw "Optional class was lost.";
        waitEvent("event_listings");
        perform("/api/lfg/chat",haxe.Json.stringify({recipient_id:b.session_id,message:"Native UTF-8 café 100% + hello"}),a.token);
        waitEvent("event_chat");
        var inbox:Dynamic=haxe.Json.parse(perform("/api/lfg/chat",null,b.token).body);
        if(inbox.messages.length!=1||inbox.messages[0].message!="Native UTF-8 café 100% + hello")throw "Private inbox mismatch.";
        var botId="";for(row in (cast haxe.Json.parse(read.body):Array<Dynamic>))if(row.is_test==true)botId=row.relay_session;
        if(botId=="")throw "Missing temporary responder fixture.";
        stream.start(1,a.token);waitEvent("event_sync");
        perform("/api/lfg/chat",haxe.Json.stringify({recipient_id:botId,message:"Native bot café test"}),a.token);waitEvent("event_chat");
        var echoed:Dynamic=haxe.Json.parse(perform("/api/lfg/chat",null,a.token).body);
        if(echoed.messages.length!=1||echoed.messages[0].sender_id!=botId||echoed.messages[0].message!="Test reply: Native bot café test")throw "Responder mismatch.";
        perform("/api/lfg/post",haxe.Json.stringify({kind:"LFG",host:"Fixture Hero",steam_id:"",activity:"Boss farm",undefined:0}),a.token);
        var before=Sys.time();stream.cancel();if(Sys.time()-before>.2)throw "Event cancellation blocked caller.";
        Sys.println("PASS native automatic sessions with blank Steam contacts, UTF-8 bearer POST, concurrent SSE listings/chat, private inbox, responder echo, solo LFG, nonblocking cancellation");
    }
}
