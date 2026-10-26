import simplelfg.Config;
import simplelfg.FareverContact;
import simplelfg.Parser;
import simplelfg.TargetDefaults;
import simplelfg.Engine;
import simplelfg.SocialService;
import simplelfg.RelayChatStore;
import simplelfg.CrossServerRelay;
import NetworkTest.MockRelay;
import TestMain.FakeChat;

class FakeSocial implements GameSocialAdapter {
    public var reads=0;public var scans=0;public var actions=0;
    public function new(){}
    public function socialSnapshot(includePeople:Bool):SocialSnapshot {
        reads++;if(includePeople)scans++;
        return {code:"ABCD-EFGH-JKLM",people:[],available:true};
    }
    public function socialAction(kind:String,uid:String,code:String):Null<String> {actions++;return null;}
}
class SocialTest {
    static var checks=0;
    static function ok(value:Bool,label:String):Void {checks++;if(!value)throw label;}
    static function main():Void {
        ok(FareverContact.format("abcd efgh-jklm")=="ABCD-EFGH-JKLM","normalize native code formatting");
        ok(!FareverContact.valid("123456")&&!FareverContact.valid("ABCD-EFGH-JKLM<"),"reject Steam code and invalid suffix");
        var tagged=FareverContact.attach("100% ready","ABCD-EFGH-JKLM");
        ok(FareverContact.extract(tagged)=="ABCD-EFGH-JKLM","explicit Farever contact tag");
        ok(FareverContact.extract("[Steam: 123456]")=="","Steam tag cannot become Farever contact");
        ok(FareverContact.attach(StringTools.lpad("x","x",240),"ABCD-EFGH-JKLM").length<=240,"explicit sharing respects message limit");
        var p=new Parser(TargetDefaults.activities());
        ok(p.parse({senderId:"a",senderName:"A",channel:"All",receivedAt:100,text:"[Farever: LFG0-AAAA-BBBB]"})==null,"contact text does not trigger recruiting parser");
        ok(Config.message("  100% ready\r\nNext\x00  ")=="100% ready\nNext","private multiline text retains line breaks and strips controls");
        var c=new Config();var fake=new FakeSocial();var social=new SocialService(fake);
        social.observe(c,"a|hero","a",true,1);social.observe(c,"a|hero","a",true,1.1);
        ok(fake.reads==1&&fake.scans==0,"hidden UI reads code cheaply without scanning people");
        social.visible=true;social.observe(c,"a|hero","a",true,6);social.observe(c,"a|hero","a",true,6.1);
        ok(fake.scans==1,"visible social polling at most once a second");
        c.fareverOwner="a";c.fareverCode="MNOP-QRST-UVWX";social.observe(c,"a|hero","a",true,6.2);
        ok(social.code==c.fareverCode,"account manual override takes precedence");
        social.observe(c,"b|hero","b",true,7);
        ok(social.code=="ABCD-EFGH-JKLM","account switch cannot reuse another manual code");
        var reload=Config.decode(c.encode());ok(reload.fareverCode==c.fareverCode&&reload.fareverOwner=="a"&&!reload.shareFareverPublic,"contact settings roundtrip privately");
        var peer=StringTools.lpad("a","a",32);var store=new RelayChatStore();
        store.remember(1,peer,"Peer","Secret\nSecond",true,100);store.remember(2,peer,"Peer","Incoming",false,100);
        ok(store.ownMessage(1)&&!store.ownMessage(2),"only outgoing lines expose deletion");
        store.tombstone(1,peer,"Peer",true,100);
        ok(!store.ownMessage(1)&&store.conversation(peer)[0].text=="Message deleted","deletion removes body after acknowledgement");
        store.remember(1,peer,"Peer","Late stale body",true,100);
        ok(store.conversation(peer)[0].text=="Message deleted","late message replay cannot resurrect deleted body");
        store.tombstone(3,peer,"Peer",false,100);ok(store.conversation(peer)[2].deleted==true,"offline recipient can receive tombstone before original message");
        var transport=new MockRelay();var relay=new CrossServerRelay(transport);var chat=new FakeChat();chat.current.playerName="Hero";
        c=new Config();var e=new Engine(c,chat,new Parser(TargetDefaults.activities()),relay);e.social=new SocialService(fake);
        e.tick(100);ok(transport.requests[0].kind=="capabilities"&&transport.requests.filter(r->r.kind=="session").length==0,"capability negotiation precedes session feature declaration");
        transport.finish(relay.generation,"capabilities",'{"features":["social-v1"]}');e.tick(101);
        var connects=transport.requests.filter(r->r.kind=="session");
        ok(connects.length==1&&haxe.Json.parse(connects[0].body).features[0]=="social-v1","new session explicitly advertises support");
        transport.finish(relay.generation,"session",haxe.Json.stringify({session_id:peer,token:peer+"."+StringTools.lpad("b","b",64)}));e.tick(102);
        var other=StringTools.lpad("c","c",32);
        e.relayMessages.remember(1,other,"Other","Secret",true,100);
        e.enqueue(e.action("deleteMessage","1"));e.tick(103);
        ok(e.deletePending&&e.relayMessages.conversation(other)[0].text=="Secret","local message remains until server acknowledgement");
        transport.finish(relay.generation,"deleteMessage",haxe.Json.stringify({status:"success",deleted:{id:1,sender_id:peer,recipient_id:other,recipient:"Other",timestamp:100,deleted:true}}));e.tick(104);
        ok(!e.deletePending&&e.relayMessages.conversation(other)[0].deleted==true,"valid owner acknowledgement applies tombstone");
        e.enqueue(e.action("addCode","ABCD-EFGH-JKLM"));chat.current.cursorFree=false;e.tick(105);
        ok(fake.actions==0,"camera transition cancels queued social actions");
        c.shareFareverPublic=true;c.fareverOwner="me";chat.current.playerId="new";chat.current.id="new|hero";e.tick(106);
        ok(!c.shareFareverPublic&&e.relayMessages.peers().length==0,"account switch revokes public consent and clears message history");
        var legacyTransport=new MockRelay();var legacy=new CrossServerRelay(legacyTransport);var old=new Engine(new Config(),new FakeChat(),new Parser(TargetDefaults.activities()),legacy);
        old.tick(100);legacyTransport.finish(legacy.generation,"capabilities","",404,"Relay HTTP 404");old.tick(101);
        ok(!legacy.socialSupported&&legacyTransport.requests.filter(r->r.kind=="session").length==1,"legacy server fallback keeps existing messaging usable");
        Sys.println("PASS "+checks+" social, consent, deletion and compatibility checks");
    }
}
