import simplelfg.Types;
import simplelfg.Config;
import simplelfg.Parser;
import simplelfg.Board;
import simplelfg.Alerts;
import simplelfg.Engine;
import simplelfg.SteamContact;
import simplelfg.RelayProtocol;
import simplelfg.CrossServerRelay;
import simplelfg.RelayTransport;
import simplelfg.RelayHttpReader;
import simplelfg.RelayEventReader;
import TestMain.FakeChat;

class MockRelay implements RelayTransport {
    public var requests:Array<RelayRequest>=[];
    public var ready:Array<RelayResult>=[];
    public var accept=true;
    public function new(){}
    public function submit(r:RelayRequest):Bool {if(!accept)return false;requests.push(r);return true;}
    public function drain():Array<RelayResult> {var rows=ready;ready=[];return rows;}
    public function cancel():Void {requests=[];ready=[];}
    public function hasResults():Bool return ready.length>0;
    public function finish(generation:Int,kind:String,body:String,status:Int=200,error:String=""):Void ready.push({generation:generation,kind:kind,body:body,status:status,error:error});
}
class NetworkTest {
    static var n=0;
    static function ok(value:Bool,message:String):Void {n++;if(!value)throw message;}
    static function rejected(f:Void->Void,message:String):Void {var failed=false;try f() catch(_:Dynamic)failed=true;ok(failed,message);}
    static function row(time:Float=100,host:String="Other Hero",note:String="Normal"):Dynamic return {id:"server-id",host:host,relay_session:"0123456789abcdef0123456789abcdef",steam_id:"76561198012345678",activity:"Crabgantua's Gorge",warriors:0,mages:0,priests:0,rogues:0,undefined:3,note:note,timestamp:time};
    static function raw(?value:Dynamic):String return haxe.Json.stringify([value==null?row():value]);
    static function main():Void {
        protocol();snapshots();lifecycle();http();events();contacts();
        Sys.println("PASS "+n+" relay integration checks (no live network)");
    }
    static function protocol():Void {
        var c=new Config();c.relayEnabled=true;c.steamId="123456";c.draft.activity="Crabgantua's Gorge";c.draft.capacity=4;c.draft.members=1;c.draft.note="Hi!";
        ok(RelayProtocol.postError(c,c.draft,"Test Hero")=="","valid relay payload");
        var body=RelayProtocol.body(c,c.draft,"Test Hero");var data:Dynamic=haxe.Json.parse(body);
        ok(data.host=="Test Hero"&&data.host!="internal-uid"&&data.undefined==3,"wire uses display name and open slots");
        ok(data.activity=="Crabgantua's Gorge"&&data.note=="Normal / Hi!","preview preserves legitimate punctuation");
        ok(RelayProtocol.preview(c,c.draft,"Test Hero").indexOf("Open slots: 3")>=0,"open slots included in review");
        c.draft.note=StringTools.lpad("x","x",65);ok(RelayProtocol.postError(c,c.draft,"Test Hero")!="","oversized note rejected without truncation");
        c.draft.note="";c.draft.capacity=5;ok(RelayProtocol.postError(c,c.draft,"Test Hero")!="","over-four party rejected");
        c.draft.capacity=4;c.draft.kind="LFG";ok(RelayProtocol.postError(c,c.draft,"Test Hero")==""&&haxe.Json.parse(RelayProtocol.body(c,c.draft,"Test Hero")).undefined==0,"solo relay listing ignores retained recruiting capacity");
        c.draft.kind="LFM";c.steamId="steam://bad";ok(RelayProtocol.postError(c,c.draft,"Test Hero")!="","invalid contact rejected");
        var relay=new CrossServerRelay(new MockRelay());
        ok(relay.connect("Test Hero","123456"),"session opens without environment or shared secret");
        var rows=RelayProtocol.listings(raw(),100,"Me","111");
        ok(rows.length==1&&rows[0].isRemote&&rows[0].expiresAt==1000,"remote fifteen-minute lease");
        ok(rows[0].activityId=="R1_POI_Nepsid_Boss"&&rows[0].matchedTargetIds.length==1,"server-sanitized activity maps to local filter");
        var own=RelayProtocol.listings(raw(),100,"Other Hero","76561198012345678","0123456789abcdef0123456789abcdef");ok(own.length==1&&own[0].isOwn,"own public listing visible for verification");
        var cfg=new Config();cfg.watchActivities=[rows[0].activityId];ok(!Alerts.matches(own[0],cfg),"own listing cannot alert");
        ok(RelayProtocol.listings(raw(row(-900)),100,"Me","").length==0,"stale remote data rejected");
        ok(RelayProtocol.listings(raw(row(9999)),100,"Me","").length==0,"future timestamps rejected");
        for(field in ["id","host","steam_id","activity","note","timestamp","warriors","mages","priests","rogues","undefined"]){var v=row();Reflect.deleteField(v,field);ok(RelayProtocol.listings(raw(v),100,"Me","").length==0,"missing field rejected: "+field);}
        var v=row();v.undefined=5;ok(RelayProtocol.listings(raw(v),100,"Me","").length==0,"untrusted slots validated");
        v=row();v.warriors=2;ok(RelayProtocol.listings(raw(v),100,"Me","").length==0,"untrusted composition sum validated");
        rejected(function(){RelayProtocol.listings("{}",100,"Me","");},"invalid root response rejected");
        rejected(function(){RelayProtocol.listings("not-json",100,"Me","");},"malformed JSON rejected");
    }
    static function snapshots():Void {
        var c=new Config();var b=new Board(new Parser(simplelfg.TargetDefaults.activities()));
        b.mergeRemote(RelayProtocol.listings(raw(),100,"Me",""),c,100);var key=b.entries[0].key;
        b.mergeRemote(RelayProtocol.listings(raw(row(200,"Other Hero","Updated")),200,"Me",""),c,200);
        ok(b.entries.length==1&&b.entries[0].key==key&&b.entries[0].text.indexOf("Updated")>=0,"reposts refresh stable listing rather than duplicate");
        b.hide(key);b.mergeRemote([],c,201);b.mergeRemote(RelayProtocol.listings(raw(row(202)),202,"Me",""),c,202);ok(!b.contains(key),"hidden lease survives absent/reappearing snapshots");
        b.clear();b.mergeRemote(RelayProtocol.listings(raw(),100,"Me",""),c,100);b.update(c,500);ok(b.entries.length==1,"local five-minute expiry does not expire remote fifteen-minute listing");
        b.update(c,1000);ok(b.entries.length==0,"remote listing expires exactly at server lease");
        b.mergeRemote(RelayProtocol.listings(raw(row(1100)),1100,"Me",""),c,1100);b.ignore(b.entries[0].senderId,"Other",c,1101);
        b.mergeRemote(RelayProtocol.listings(raw(row(1102)),1102,"Me",""),c,1102);ok(b.entries.length==0,"ignore applies to future remote snapshots");
    }
    static function session():String return haxe.Json.stringify({session_id:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",token:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa."+StringTools.lpad("b","b",64),expires_in:1800});
    static function lifecycle():Void {
        var m=new MockRelay();var relay=new CrossServerRelay(m);var a=new FakeChat();a.current.playerName="Test Hero";
        var c=new Config();c.relayEnabled=false;c.steamId="123456";var e=new Engine(c,a,new Parser(simplelfg.TargetDefaults.activities()),relay);e.tick(100);
        ok(m.requests.length==0,"disabled relay has no network traffic");
        c.draft.activity="Crabgantua's Gorge";e.markDirty(100);e.tick(100);e.enqueue(e.action("post",e.preview,"All"));e.tick(100);
        ok(a.calls.length==1&&m.requests.length==0,"local post never silently uploaded even with Steam code");
        c.relayEnabled=true;e.markDirty(101);e.tick(101);ok(m.requests.length==2&&m.requests[0].kind=="session"&&m.requests[1].kind=="listings","enabling triggers single listing poll");
        var gen=relay.generation;m.finish(gen,"session",session());m.finish(gen,"listings",raw(row(101)));ok(e.board.entries.length==0,"worker completions cannot mutate board before tick");
        e.tick(101);ok(e.board.entries.length==1,"observation loop applies completion");
        var count=m.requests.length;e.tick(102);e.tick(115);ok(m.requests.filter(function(r)return r.kind=="listings").length==1,"listing poll rate limited to fifteen-second fallback cadence");
        e.tick(116);ok(m.requests.filter(function(r)return r.kind=="listings").length==2,"next poll scheduled once");
        var stale=relay.generation;a.current.id="other-character";e.tick(132);m.finish(stale,"listings",raw(row(132)));e.tick(133);m.finish(relay.generation,"session",session());e.tick(134);
        ok(e.board.entries.length==0,"late old-character response ignored");
        c.draft.channel="Relay";c.draft.capacity=4;c.draft.members=1;c.draft.note="Ready";e.markDirty(200);e.tick(200);
        e.enqueue(e.action("post",e.preview,"Relay"));e.tick(200);ok(e.relayPostPending,"relay post enters pending state");
        var post=m.requests[m.requests.length-1];ok(post.kind=="post"&&haxe.Json.parse(post.body).host=="Test Hero","correct endpoint payload and display name");
        ok(e.postFeedback.indexOf("published")<0,"request submission does not claim publication");
        m.finish(relay.generation,"post",'{"status":"success","listing":{"id":"ok"}}',201);e.tick(201);
        ok(!e.relayPostPending&&e.cooldown==60&&e.postFeedback.indexOf("published")>=0,"success requires server acknowledgement");
        e.enqueue(e.action("post",e.preview,"Relay"));var before=m.requests.length;e.tick(202);ok(m.requests.length==before,"acknowledged post enforces cooldown");
        e.tick(262);e.enqueue(e.action("post",e.preview,"Relay"));e.tick(262);m.finish(relay.generation,"post","",403,"Relay HTTP 403 (signature rejected)");e.tick(263);
        ok(!e.relayPostPending&&e.postFeedback.indexOf("403")>=0,"signed post failure reaches UI");
        c.relayEnabled=false;e.markDirty(264);e.tick(264);ok(e.board.entries.length==0,"disable clears remote entries");
        var restored=Config.decode(c.encode());ok(!restored.relayEnabled&&restored.steamId=="123456"&&restored.draft.channel=="Relay","network preferences and destination roundtrip");
        c.relayEnabled=true;e.markDirty(300);e.tick(300);m.finish(relay.generation,"session",session());m.finish(relay.generation,"listings",raw(row(300)));e.tick(300);
        var remote=e.board.entries[0];before=m.requests.length;
        e.enqueue(e.action("whisper","Do not send this","Player",remote));e.tick(301);
        ok(m.requests.length==before&&a.calls.length==1&&e.requestedRelayPeer!="","remote whisper opens a private composer without sending");
        e.enqueue(e.action("post",e.preview,"Relay"));e.tick(302);m.finish(relay.generation,"post",'{"status":"success","listing":{}}',201);e.tick(303);
        ok(e.postFeedback.indexOf("invalid")>=0&&!e.relayPostPending,"malformed acknowledgement cannot claim publication");
        m.accept=false;e.enqueue(e.action("post",e.preview,"Relay"));e.tick(304);
        ok(!e.relayPostPending&&e.postFeedback.indexOf("busy")>=0,"full worker queue reports failure without hanging pending state");
    }
    static function http():Void {
        function read(raw:String):String return RelayHttpReader.read(new haxe.io.BytesInput(haxe.io.Bytes.ofString(raw))).body;
        ok(read("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\n[]")=="[]","content-length response");
        ok(read("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n2\r\n[]\r\n0\r\n\r\n")=="[]","chunked response");
        ok(read("HTTP/1.1 200 OK\r\n\r\n[]")=="[]","connection-close response");
        rejected(function(){read("HTTP/1.1 200 OK\r\n");},"partial header EOF terminates");
        rejected(function(){read("HTTP/1.1 200 OK\r\nContent-Length: 999999\r\n\r\n");},"oversized response rejected before allocation");
        rejected(function(){read("HTTP/1.1 200 OK\r\nContent-Length: 2\r\nTransfer-Encoding: chunked\r\n\r\n");},"conflicting framing rejected");
        rejected(function(){read("HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\n[]");},"truncated body rejected");
        rejected(function(){read("garbage\r\n\r\n");},"malformed status rejected");
    }
    static function contacts():Void {
        ok(SteamContact.valid("76561198012345678")&&!SteamContact.valid("steam://bad"),"numeric contact validation");
        var parser=new Parser(simplelfg.TargetDefaults.activities());var c=new Config();
        var e:ChatEnvelope={senderId:"uid",senderName:"Host",channel:"All",receivedAt:100,text:"LFM Unknown Vault [Steam: 123456]"};
        var l=parser.parse(e,c);ok(l.target=="Unknown Vault"&&l.steamId=="123456","Steam tag excluded from custom target");
        e.text="LFM [Steamworks] [Steam: 123456]";ok(parser.parse(e,c).target=="Steamworks","Steam-named target is not discarded");
        var attached=SteamContact.attach("Hello","123456",240);ok(SteamContact.attach(attached,"123456",240)==attached,"attachment does not duplicate");
        ok(SteamContact.attach("Hello","123456",10)=="Hello","attachment never silently truncates");
    }
    static function events():Void {
        var packets="event: listings\ndata: {}\n\n: heartbeat\n\nevent: chat\ndata: {}\n\n";
        var stream="HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nTransfer-Encoding: chunked\r\n\r\n";
        for(part in packets.split(""))stream+=StringTools.hex(haxe.io.Bytes.ofString(part).length)+"\r\n"+part+"\r\n";
        stream+="0\r\n\r\n";
        var reader=new RelayEventReader(new haxe.io.BytesInput(haxe.io.Bytes.ofString(stream)));reader.headers();var received:Array<String>=[];
        try reader.listen(function(kind){received.push(kind);},function(){return true;})catch(_:haxe.io.Eof){};
        ok(received.join(",")=="listings,chat","SSE frames survive chunk boundaries and ignore heartbeat");
        rejected(function(){var r=new RelayEventReader(new haxe.io.BytesInput(haxe.io.Bytes.ofString("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n")));r.headers();},"SSE requires correct media type");
        var retry=RelayHttpReader.read(new haxe.io.BytesInput(haxe.io.Bytes.ofString("HTTP/1.1 429 Too Many Requests\r\nRetry-After: 42\r\nContent-Length: 0\r\n\r\n")));
        ok(retry.retryAfter==42,"server cooldown survives HTTP transport");
        var m=new MockRelay();var a=new FakeChat();a.current.playerName="Hero";var c=new Config();c.steamId="1";
        var e=new Engine(c,a,new Parser(simplelfg.TargetDefaults.activities()),new CrossServerRelay(m));e.relayVisible=false;e.tick(1);
        ok(m.requests.length==0,"closed window performs no network requests");
        e.relayVisible=true;e.tick(2);ok(m.requests.length==2,"opening window starts snapshot and session");
        m.finish(e.relay.generation,"session",session());e.tick(2);m.finish(e.relay.generation,"event_open","");e.tick(2);
        var count=m.requests.length;e.tick(30);e.tick(45);ok(m.requests.length==count,"healthy SSE suppresses idle polling");
        m.finish(e.relay.generation,"event_listings","");e.tick(45);ok(m.requests.length==count,"in-flight listing request prevents overlap");
        m.finish(e.relay.generation,"listings","[]");e.tick(45);m.finish(e.relay.generation,"event_listings","");e.tick(45);
        ok(m.requests[m.requests.length-1].kind=="listings","SSE change triggers a snapshot without periodic polling");
        m.finish(e.relay.generation,"event_listings","");e.tick(45);var before=m.requests.length;m.finish(e.relay.generation,"listings","[]");e.tick(45);ok(m.requests.length==before+1,"event during in-flight refresh triggers a follow-up snapshot");
        e.relayVisible=false;e.tick(46);count=m.requests.length;e.tick(100);ok(m.requests.length==count,"closing window cancels stream and polling");
        ok(e.relay.sessionId!="","closing window retains private session credential in memory");
        e.relayVisible=true;e.tick(101);ok(m.requests.filter(function(r)return r.kind=="session").length==0,"reopening reuses its session instead of exhausting bootstrap quota");
    }
}
