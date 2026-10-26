import simplelfg.Config;
import simplelfg.Parser;
import simplelfg.Board;
import simplelfg.Alerts;
import simplelfg.SessionHistory;
import simplelfg.ChannelPolicy;
import simplelfg.TargetDefaults;
import simplelfg.Engine;
import simplelfg.Types;
import TestMain.FakeChat;

class OverhaulTest {
    static var n=0;
    static function check(value:Bool,label:String):Void {n++;if(!value)throw label;}
    static function event(text:String,at:Float=100,id:String="host",channel:String="All"):ChatEnvelope
        return {text:text,receivedAt:at,senderId:id,senderName:id,channel:channel};
    static function main():Void {
        recognition();history();geometry();migration();
        Sys.println("PASS "+n+" overhaul checks");
    }
    static function recognition():Void {
        var c=new Config();var p=new Parser(TargetDefaults.activities());
        check(!c.requireRecruitingContext&&c.monitoredChannels.length==6,"new capture defaults");
        check(TargetDefaults.bosses().length==14,"recognition covers released boss-flagged units");
        for(b in TargetDefaults.bosses()){
            var l=p.parse(event(b.name),c);
            check(l!=null&&!l.contextDetected&&l.matchedTargetIds.indexOf(b.targetId)>=0,"bare boss: "+b.name);
            l=p.parse(event("LFM "+b.name),c);
            check(l!=null&&l.contextDetected&&l.kind=="LFM","recruiting boss: "+b.name);
        }
        for(a in TargetDefaults.activities())for(alias in a.aliases){
            var l=p.parse(event(alias),c);
            check(l!=null&&l.matchedTargetIds.indexOf(a.id)>=0,"every alias has recognition coverage: "+alias);
            check(p.parse(event("LFM "+alias),c).contextDetected,"every alias accepts explicit context: "+alias);
        }
        var cdb:Dynamic=haxe.Json.parse(sys.io.File.getContent("evidence/current-data/data.cdb"));
        var sheet:Dynamic=null;for(s in (cast cdb.sheets:Array<Dynamic>))if(s.name=="unit")sheet=s;
        for(unit in (cast sheet.lines:Array<Dynamic>))if((Std.int(unit.flags)&16)!=0&&!TargetDefaults.unavailableTarget(unit.id)){
            var name:String=unit.texts.name;if(name=="???")name=unit.id;
            var tokens=~/[^a-z0-9'’]+/g.replace(name.toLowerCase()," ").split(" ");
            for(token in tokens)if(token!="")check(p.parse(event(token),c)!=null,"boss name word: "+token);
        }
        check(p.parse(event("???"),c)==null,"unlocalized placeholder never matches");
        check(p.parse(event("What are crab runs?"),c)!=null&&!p.parse(event("What are crab runs?"),c).contextDetected,"question retained as red mention");
        check(p.parse(event("crab drops good loot"),c)!=null&&!p.parse(event("crab drops good loot"),c).contextDetected,"discussion retained as red mention");
        check(p.parse(event("WTS crab"),c)==null,"exclusion always takes precedence");
        for(phrase in c.lfgWords){var l=p.parse(event(phrase+" Crab"),c);check(l!=null&&l.contextDetected&&l.kind=="LFG","solo phrase: "+phrase);}
        for(phrase in c.lfmWords){if(phrase=="lf#m")phrase="LF12M";var l=p.parse(event(phrase+" Crab"),c);check(l!=null&&l.contextDetected&&l.kind=="LFM","recruiting phrase: "+phrase);}
        c.requireRecruitingContext=true;
        check(p.parse(event("Crab"),c)==null,"context toggle rejects bare names");
        check(p.parse(event("Crab heroic runs"),c).contextDetected,"context toggle accepts runs");
        c.requireRecruitingContext=false;
        c.targetAliases.push({targetId:"fixture",name:"Second Crab",phrase:"crab"});p.prepare(c);
        var ambiguous=p.parse(event("crab"),c);
        check(ambiguous!=null&&ambiguous.matchedTargetIds.length==2,"ambiguous short alias retained");
        check(p.parse(event("Crabgantua"),c).matchedTargetIds.length==1,"specific alias resolves ambiguity");
        var board=new Board(p);board.enqueue(event("crab"));board.update(c,100);
        check(board.filtered("All","fixture","").length==1,"ambiguous candidate matches activity filter");
        check(board.filtered("LFM","all","").length==0,"red entry does not claim recruitment");
        c.requireRecruitingContext=true;board.update(c,100);check(board.filtered("All","all","").length==0&&!board.contains(ambiguous.key),"context filter immediately hides retained red matches");
        c.requireRecruitingContext=false;board.update(c,100);check(board.filtered("All","all","").length==1,"turning context filter off restores active matches");
        c.alertsEnabled=true;c.watchActivities=[ambiguous.matchedTargetIds[0]];
        check(!Alerts.matches(ambiguous,c),"red entry cannot produce group alerts");
        for(name in ChannelPolicy.names){var b=new Board(new Parser(TargetDefaults.activities()));b.enqueue(event("Crab",100,"host",name));b.update(c,100);check(b.entries.length==1&&b.entries[0].channel==name,"all channel route: "+name);}
    }
    static function history():Void {
        var c=new Config();var board=new Board(new Parser(TargetDefaults.activities()));
        board.enqueue(event("ordinary conversation"));board.enqueue(event("Crab",101));board.update(c,102);
        check(board.entries.length==1&&board.history.count==2,"ordinary messages enter history but not board");
        check(board.history.forSender("host")[0].text=="Crab","history newest first");
        board.update(c,405);check(board.entries.length==0&&board.history.count==2,"history outlives board expiry");
        board.update(c,1902);check(board.history.count==0,"thirty minute history expiry");
        var h=new SessionHistory();for(i in 0...55)h.add(event("message "+i,100+i),100+i);
        var recent=h.forSender("host");check(recent.length==50&&recent[49].text=="message 5"&&recent[0].text=="message 54","per sender limit evicts oldest");
        h.clear();for(i in 0...2100)h.add(event("message "+i,100+i/10,"sender"+i),100+i/10);
        check(h.count==2000&&h.forSender("sender0").length==0&&h.forSender("sender2099").length==1,"global history cap evicts oldest");
        h.add(event("senderless",400,""),400);check(h.count==2000,"senderless notices ignored");
        var invalid=event("bad");invalid.receivedAt=Math.NaN;h.add(invalid,400);check(h.count==2000,"invalid history timestamp ignored");
        c.monitoredChannels=["All"];board.enqueue(event("local conversation",2000,"host","Local"));board.update(c,2000);check(board.history.count==0,"disabled channel omitted from capture");
        var a=new FakeChat();var engine=new Engine(c,a,new Parser(TargetDefaults.activities()));engine.tick(100);
        engine.board.enqueue(event("ordinary conversation"));engine.tick(100);
        check(engine.board.history.count==1,"capture continues without an open UI");
        a.current.id="other-session";engine.tick(101);check(engine.board.history.count==0,"session change clears history");
        engine.board.enqueue(event("ordinary conversation",102));engine.tick(102);
        a.current.id="";a.current.available=false;engine.tick(103);check(engine.board.history.count==0,"logout clears history");
        check(c.encode().indexOf("ordinary conversation")<0&&c.encode().indexOf("senderId")<0,"history never serialized");
    }
    static function geometry():Void {
        for(width in [320.0,520.0,720.0,1140.0,1440.0,1920.0])for(scale in [0.85,1.0,1.5]){
            var l=new simplelfg.WorkspaceLayout();l.update(width,600,scale);
            check(l.leftWidth<=width&&l.rightX+l.rightWidth<=width+0.001,"workspace panes stay inside the canvas");
            check(!l.wide||l.leftWidth+12+l.rightWidth<=width+0.001,"docked inspector never overlaps the board");
        }
    }
    static function migration():Void {
        var old=Config.decode('{"version":3,"geometryVersion":1,"width":720,"height":480,"launcherArt":0,"launcherSize":80,"launcherRight":9999}');
        check(old.width==1180&&old.height==768,"one time enlargement");
        check(old.monitoredChannels.length==6&&!old.requireRecruitingContext,"legacy capture defaults updated");
        check(old.encode().indexOf("launcherArt")<0&&old.encode().indexOf("launcherSize")<0&&old.encode().indexOf("launcherRight")<0,"retired launcher preferences removed");
        old.width=1100;old.height=800;old.launcherEnabled=false;old.monitoredChannels=["Player"];old.requireRecruitingContext=true;
        var restored=Config.decode(old.encode());check(restored.width==1100&&restored.height==800&&!restored.migrated,"subsequent manual geometry retained");
        var tiny=Config.decode('{"geometryVersion":2,"width":700,"height":450}');check(tiny.width==1024&&tiny.height==768,"sizes below the 1024x768 minimum are raised");
        check(!restored.launcherEnabled&&restored.monitoredChannels.length==1&&restored.monitoredChannels[0]=="Player"&&restored.requireRecruitingContext,"channel context and button preferences roundtrip");
        var legacy:Dynamic=haxe.Json.parse(sys.io.File.getContent("assets/recognition-legacy.json"));
        var obj:Dynamic={version:3,lfgWords:legacy.lfgWords,lfmWords:legacy.lfmWords,contextWords:legacy.contextWords,
            targetAliases:[for(a in TargetDefaults.legacyAliases()){targetId:a.targetId,name:a.name,phrase:a.phrase}]};
        var upgraded=Config.decode(haxe.Json.stringify(obj));check(upgraded.lfgWords.length>legacy.lfgWords.length&&upgraded.targetAliases.length>obj.targetAliases.length,"untouched phrase and alias defaults expand");
        var custom=Config.decode('{"version":3,"lfgWords":[],"lfmWords":["squad"],"targetAliases":[]}');
        check(custom.lfgWords.length==0&&custom.lfmWords.length==1&&custom.targetAliases.length==0,"custom removals preserved");
        custom.mergeDefaults();check(custom.targetAliases.length>0&&custom.lfmWords.indexOf("squad")>=0,"explicit merge preserves custom phrases");
        var invalid=Config.decode('{"version":4,"monitoredChannels":["Unknown","All","All"],"requireRecruitingContext":"bad"}');
        check(invalid.monitoredChannels.length==1&&!invalid.requireRecruitingContext,"channel validation and context type validation");
    }
}
