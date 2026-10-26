import simplelfg.Types;
import simplelfg.Config;
import simplelfg.Parser;
import simplelfg.Board;
import simplelfg.Engine;
import simplelfg.Store;

class FakeChat implements GameChatAdapter {
    public var current:Session={id:"me|character1",playerId:"me",cursorFree:true,available:true};
    public var calls:Array<{text:String,channel:String,id:String,name:String}>=[];
    public var failure:Null<String>=null;
    public function new() {}
    public function session():Session return current;
    public function send(text:String,channel:String,id:String,name:String):Null<String> {
        if(failure!=null) return failure;
        calls.push({text:text,channel:channel,id:id,name:name});return null;
    }
}

class TestMain {
    static var checks=0;
    // Fixture names are deliberately synthetic and never shipped in the catalogue.
    static var catalogue:Array<Activity>=[{id:"test",name:"Test Cavern",aliases:["test cavern","tc"]},
        {id:"otherTest",name:"Test Summit",aliases:["test summit","ts"]}];
    static function ok(v:Bool,msg:String):Void {checks++;if(!v) throw "FAILED: "+msg;}
    static function eq(a:Dynamic,b:Dynamic,msg:String):Void ok(a==b,msg+" expected="+b+" got="+a);
    static function event(text:String,at:Float=100,id:String="host",channel:String="All"):ChatEnvelope
        return {text:text,receivedAt:at,senderId:id,senderName:"Host",channel:channel};
    static function main():Void {
        parsing();lifecycle();actions();settings();filesystem();
        Sys.println("PASS "+checks+" SimpleLFG checks");
    }
    static function parsing():Void {
        var strict=new Config();strict.requireRecruitingContext=true;var p=new Parser(catalogue,strict);
        var l=p.parse(event("[LFM] [Test Cavern] Need 1 Tank, 2 DPS (1/4)"));
        ok(l!=null,"standard recruiting");eq(l.kind,"LFM","kind");eq(l.activityId,"test","activity");
        eq(l.composition,"1/4","composition");
        for(text in ["LFG test cavern healer","looking for a group tc","Looking to join TC"])
            eq(p.parse(event(text)).kind,"LFG","solo phrase "+text);
        for(text in ["LFM TC","LF1M TC","lf2m test cavern","Looking for more TC","recruiting TC","Test Cavern needs a tank"])
            eq(p.parse(event(text)).kind,"LFM","group phrase "+text);
        for(text in ["tank","any healer tips?","WTS sword","the dps is good","what is tc?","blfgroup","lfmanythings","LFG and LFM TC","what does LFG mean?","WTS LFG TC boost","Do I need a healer for Test Cavern?","I need a guide for Test Cavern"])
            eq(p.parse(event(text)),null,"exclude unrelated or ambiguous "+text);
        eq(p.parse(event("TC need healer")).activityId,"test","activity+recruit");
        eq(p.parse(event("LF1M [Unfamiliar Ruins] tank")).target,"Unfamiliar Ruins","custom bracket");
        eq(p.parse(event("LFM unknown ruins need tank")).target,"unknown ruins","custom unbracketed");
        eq(p.parse(event("LFM test cavern" )).composition,"Size unspecified","unknown size");
        eq(p.parse(event("LFM tc 9/4")).composition,"Size unspecified","invalid composition");
        eq(p.parse(event("LFM tc 1/99")).composition,"Size unspecified","capacity cap");
        eq(p.parse(event("LFM TC")).key,p.parse(event("LFM test cavern need healer",101)).key,"alias dedupe");
        eq(p.parse(event("LFM tc \x00")),null,"NUL rejected");
        eq(p.parse(event("LFM tc",100,"")),null,"identity required");
        eq(p.parse(event("LFM "+StringTools.lpad("x","x",520))),null,"long text rejected");
        var nan=event("LFM TC");nan.receivedAt=Math.NaN;eq(p.parse(nan),null,"invalid time");
        var literal=p.parse(event("LFM TC 100% ##hello <script>"));
        ok(literal.text.indexOf("100% ##hello <script>")>=0,"retain literal content");
        ok(literal.uiId.indexOf("#")==-1,"UI identity contains no label markup");
        ok(p.parse(event("LFM [遺跡一]")).key!=p.parse(event("LFM [遺跡二]")).key,"distinct non-English custom targets");
        var d=new Draft();d.activity="TC";d.capacity=4;d.members=1;
        eq(Parser.preview(d),"[LFM] [TC] - Normal (1/4)","post preview");
        d.kind="LFG";eq(Parser.preview(d),"[LFG] [TC] - Normal","solo preview excludes slots");
        d.note="line1\nline2\x00";ok(Parser.preview(d).indexOf("\n")==-1,"single-line outbound");
        d.activity="";eq(Parser.preview(d),"Choose or enter an activity.","empty preview");
    }
    static function lifecycle():Void {
        var c=new Config();c.monitoredChannels=["All"];var b=new Board(new Parser(catalogue));
        b.enqueue(event("LFM tc"));b.enqueue(event("LFM test cavern need tank",101));b.update(c,102);
        eq(b.entries.length,1,"duplicate merged");eq(b.entries[0].seen,101,"age refreshed");
        b.enqueue(event("LFG tc",102));b.enqueue(event("LFM ts",102));b.update(c,103);eq(b.entries.length,3,"different intent and target separate");
        b.enqueue(event("LFM tc",104,"host","Player"));b.enqueue(event("LFM tc",104,"local","Local"));b.update(c,105);
        eq(b.entries.length,3,"excluded channels");c.monitoredChannels.push("Local");
        b.enqueue(event("LFM tc",106,"local","Local"));b.update(c,107);eq(b.entries.length,4,"local opt-in");
        eq(b.filtered("LFG","all","").length,1,"intent filter");eq(b.filtered("All","otherTest","").length,1,"activity filter");
        eq(b.filtered("All","all","tank").length,1,"text search");eq(b.filtered("All","all","nomatch").length,0,"no matches");
        var key=b.entries[0].key;b.hide(key);ok(!b.contains(key),"hidden unavailable");
        b.enqueue(event("LFM tc need dps",110));b.update(c,111);ok(!b.contains(key),"hidden repost remains hidden");
        b.ignore("local","Local",c,112);eq(b.filtered("All","all","Local").length,0,"ignore clears feed");
        b.enqueue(event("LFM tc",113,"local","Local"));b.update(c,114);ok(!b.contains("local\x1fLFM\x1ftest cavern"),"ignore new message");
        b.update(c,407);eq(b.entries.length,0,"expiry");
        b.enqueue(event("LFM tc",408));b.update(c,408);ok(b.contains(key),"hidden lease expired");
        b.clear();eq(b.entries.length,0,"clear");
        for(i in 0...300) b.enqueue(event("LFM tc",500,"host"+i));
        eq(b.dropped,44,"queue bound drops oldest");for(i in 0...9) b.update(c,501);
        eq(b.entries.length,200,"listing cap");eq(b.entries[0].senderId,"host100","oldest eviction");
        b.clear();b.enqueue(event("LFM tc",10));b.update(c,1000);eq(b.entries.length,0,"stale queue discarded");
        b.ignore("x","X",c,1000,true);ok(b.ignored("x",c,1e10),"permanent ignore");
    }
    static function actions():Void {
        var c=new Config();c.draft.activity="TC";c.reminder=true;
        var a=new FakeChat();var e=new Engine(c,a,new Parser(catalogue));e.tick(100);
        e.enqueue(e.action("post",e.preview));eq(a.calls.length,0,"deferred send");e.tick(101);
        eq(a.calls.length,1,"manual post");eq(e.cooldown,60,"cooldown starts");
        e.enqueue(e.action("post",e.preview));e.tick(102);eq(a.calls.length,1,"cooldown enforced");
        e.tick(161);ok(e.reminderReady,"reminder ready");eq(a.calls.length,1,"reminder never sends");
        a.failure="Denied";e.enqueue(e.action("post",e.preview));e.tick(162);eq(e.status,"Denied","send failure surfaced");
        a.failure=null;e.enqueue(e.action("post",e.preview));e.tick(163);eq(a.calls.length,2,"failure does not consume cooldown");
        e.board.enqueue(event("LFM TC",164));e.tick(164);var l=e.board.entries[0];
        e.enqueue(e.action("whisper","Hi","Player",l));e.tick(165);eq(a.calls.length,3,"whisper sent");eq(a.calls[2].id,"host","identity from envelope");
        e.enqueue(e.action("whisper","Again","Player",l));e.tick(165.5);eq(a.calls.length,3,"whisper double-click throttle");
        e.enqueue(e.action("whisper",StringTools.lpad("x","x",241),"Player",l));e.tick(167.5);eq(a.calls.length,3,"long whisper rejected without silent truncation");
        e.enqueue(e.action("whisper","Hi","Player",l));e.board.hide(l.key);e.tick(168);eq(a.calls.length,3,"hidden target unavailable");
        a.current.cursorFree=false;e.enqueue(e.action("post",e.preview));e.tick(230);eq(a.calls.length,3,"camera cancels action");
        a.current.cursorFree=true;e.enqueue(e.action("post",e.preview));a.current.id="newCharacter";e.tick(231);
        ok(e.sessionChanged,"mutable adapter snapshot identity change detected");eq(a.calls.length,3,"old session action cleared");
        eq(e.board.entries.length,0,"character change clears listings");ok(!e.reminderReady,"character clears reminders");eq(c.draft.activity,"TC","draft survives");
        for(i in 0...5) e.saveTemplate(232);eq(c.templates.length,5,"five templates");e.saveTemplate(233);eq(c.templates.length,5,"template cap");
        c.draft.activity="Changed";eq(c.templates[0].activity,"TC","templates independent");
        var accepted=0;for(i in 0...20) if(e.enqueue(e.action("post",e.preview))) accepted++;
        eq(accepted,16,"action queue bounded");a.current.id="";a.current.available=false;e.tick(234);eq(a.calls.length,3,"logout clears queue");
        ok(!e.state.available,"unavailable snapshot");
        c.draft.activity="";a.current.id="me";a.current.available=true;e.tick(235);
        e.enqueue(e.action("post","bad"));e.tick(236);eq(a.calls.length,3,"empty activity rejected");
    }
    static function settings():Void {
        for(raw in ["oops","null","[]","\"string\"","true","42"]) {
            var c=Config.decode(raw);eq(c.hotkey,5,"recover defaults "+raw);eq(c.expirySeconds,300,"expiry default "+raw);
        }
        var c=Config.decode('{"geometryVersion":1,"hotkey":99,"expirySeconds":-2,"textScale":99,"monitorAll":"bad","width":1,"draft":{"activity":"A\\nB","capacity":4,"members":8},"ignored":[{"id":"x","until":0}],"templates":[{}]}');
        eq(c.hotkey,5,"fixed F5 migration");eq(c.expirySeconds,60,"expiry clamp");eq(c.textScale,1.5,"scale clamp");eq(c.monitoredChannels.length,6,"all channel defaults");
        eq(c.width,1180,"migration enlarges legacy width");eq(c.draft.members,3,"party members capped at three");eq(c.draft.activity,"A B","draft newline sanitized");
        eq(c.ignored.length,1,"ignore loaded");eq(c.templates.length,1,"template loaded");
        var d=Config.decode(c.encode());eq(d.hotkey,c.hotkey,"roundtrip key");eq(d.draft.activity,c.draft.activity,"roundtrip draft");
        eq(d.ignored[0].id,"x","roundtrip ignore");ok(d.encode().indexOf("senderId")==-1,"no chat history persisted");
        c=Config.decode('{"hotkey":"F8","draft":{"members":"oops"},"ignored":"wrong","templates":{}}');
        eq(c.hotkey,5,"wrong numeric type");eq(c.draft.members,0,"wrong draft type");eq(c.ignored.length,0,"wrong ignored type");
        c=Config.decode('{"draft":{"capacity":40,"members":39},"templates":[{"capacity":2,"members":3},{"capacity":0,"members":4}]}');
        eq(c.draft.capacity,4,"legacy capacity capped at four");eq(c.draft.members,3,"legacy members capped at three");
        eq(c.templates[0].members,1,"smaller template capacity keeps a recruiting slot open");
        eq(c.templates[1].capacity,4,"legacy unspecified capacity defaults to four");eq(c.templates[1].members,3,"members stay below capacity");
        eq(new Draft().capacity,4,"new draft defaults to capacity four");
    }
    static function filesystem():Void {
        var root="build/test-settings";
        if(!sys.FileSystem.exists(root)) sys.FileSystem.createDirectory(root);
        var path=root+"/config.json";
        var s=new Store(path);var c=new Config();c.draft.activity="Test";
        ok(s.save(c),"first save");c.draft.activity="Updated";ok(s.save(c),"replace save");
        eq(s.load().draft.activity,"Updated","disk roundtrip");
        sys.io.File.saveContent(path,"{bad");eq(s.load().draft.activity,"","malformed fallback");
        eq(sys.io.File.getContent(path+".invalid"),"{bad","malformed original preserved");
        ok(s.save(c),"save after recovery");eq(s.load().draft.activity,"Updated","recovery persisted");
        sys.FileSystem.deleteFile(path);eq(s.load().draft.activity,"","interrupted replacement recovers prior malformed save as defaults");
        ok(s.save(c),"save after interrupted replacement recovery");
        sys.FileSystem.deleteFile(path);eq(s.load().draft.activity,"","backup still reflects prior save until another replacement");
        ok(s.save(c),"restore valid settings");ok(s.save(c),"create valid backup");
        sys.FileSystem.deleteFile(path);eq(s.load().draft.activity,"Updated","interrupted replacement recovers valid backup");
    }
}
