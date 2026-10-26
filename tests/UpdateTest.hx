import simplelfg.Config;
import simplelfg.Parser;
import simplelfg.TargetDefaults;
import simplelfg.Types;
import simplelfg.Alerts;
import simplelfg.Board;
import simplelfg.SortPolicy;

class UpdateTest {
    static var n=0;
    static function check(v:Bool,label:String):Void {n++;if(!v)throw label;}
    static function event(text:String):ChatEnvelope return {senderId:"host",senderName:"Host",text:text,channel:"All",receivedAt:100};
    static function main():Void {
        var c=new Config();c.requireRecruitingContext=true;var p=new Parser(TargetDefaults.activities());
        var crab=p.parse(event("Crab heroic runs"),c);check(crab!=null&&crab.kind=="LFM"&&crab.target=="Crabgantua's Gorge","context run recognized and canonical");
        check(p.parse(event("LFM Crab Heroic PST for invite."),c).key==crab.key,"screenshot message uses canonical target");
        check(p.parse(event("LFG crab runs"),c).kind=="LFG","solo intent wins broad run terms");
        check(p.parse(event("LFG and LFM crab"),c)==null,"contradictory explicit intent");
        for(text in ["Crabgantua","boss","runs","crab boss is hard","crab drops good loot","Crab boss has mechanics","What are crab runs?","crab runs yesterday","WTS crab runs"])
            check(p.parse(event(text),c)==null,"exclude chatter: "+text);
        var data:Dynamic=haxe.Json.parse(sys.io.File.getContent("assets/boss-loot.json"));
        for(b in (cast data.bosses:Array<Dynamic>)){check(p.parse(event(b.name+" runs"),c)!=null,"covered boss recognition "+b.name);}
        for(a in TargetDefaults.activities())for(alias in a.aliases)check(p.parse(event("LFM "+alias),c)!=null,"alias recognized: "+alias);
        check(p.parse(event("LFM rh"),c).target=="Robin Hoof","abbreviation");
        c.targetAliases.push({targetId:"other",name:"Ambiguous",phrase:"crab"});p.prepare(c);check(p.parse(event("LFM crab"),c).matchedTargetIds.length==2,"ambiguous short alias retained");c.targetAliases.pop();
        c.targetAliases=[for(a in c.targetAliases)if(a.phrase.toLowerCase()!="crab")a];p.prepare(c);check(p.parse(event("crab runs"),c)==null,"removed alias stops contextual recognition");
        c.mergeDefaults();p.prepare(c);check(p.parse(event("crab runs"),c)!=null,"explicit merge restores defaults");
        c.contextWords=[];check(p.parse(event("crab runs"),c)==null,"context phrases authoritative");
        c.excludedWords=["heroic"];check(p.parse(event("LFM crab heroic"),c)==null,"exclusion wins");
        var board=new Board(new Parser(TargetDefaults.activities()));c=new Config();board.enqueue(event("LFM Crab"));board.enqueue(event("LFM Crabgantua"));board.update(c,100);check(board.entries.length==1,"nicknames merge");
        var alerts=new Alerts();c.alertsEnabled=true;c.watchActivities=[board.entries[0].activityId];alerts.update(board,c,"me",100);check(alerts.unread==1,"canonical watch matches");
        c.watchActivities=["custom:crab"];check(Alerts.matches(board.entries[0],c),"custom nickname watch matches canonical target");
        var legacy=Config.decode('{"version":2,"width":960,"height":640,"draft":{"activity":"Crab","roles":"healer","tanks":1,"healers":1,"dps":2,"note":"My own healer note","bonusRuns":true},"templates":[{"activity":"Crab","roles":"Tank","bonusRuns":true}]}');
        check(legacy.width==1180&&legacy.height==768&&legacy.migrated,"one time enlargement");var restored=Config.decode(legacy.encode());check(restored.width==1180&&restored.height==768&&!restored.migrated,"geometry migration persists once");
        check(legacy.draft.note=="My own healer note"&&legacy.templates[0].bonusRuns,"legacy notes and templates preserved");
        check(legacy.encode().indexOf('"roles"')<0&&legacy.encode().indexOf('"tanks"')<0,"role fields removed from saves");
        check(Parser.preview(legacy.draft).indexOf("Bonus Runs")>=0&&Parser.preview(legacy.draft).indexOf("Need")<0,"legacy role counts absent from outgoing post");
        var defaults=Config.decode('{"version":2,"lfgWords":["lfg","looking for group","looking for a group","looking to join"],"lfmWords":["lfm","lf#m","looking for more","recruiting","need","needs","seeking","join us","looking for"]}');check(defaults.lfgWords.length>4&&defaults.lfmWords.length>9,"untouched old defaults expanded");
        var custom=Config.decode('{"version":2,"lfgWords":[],"lfmWords":["squad"]}');check(custom.lfgWords.length==0&&custom.lfmWords.length==1,"custom removals preserved");custom.mergeDefaults();check(custom.lfgWords.length>0&&custom.lfmWords.indexOf("squad")>=0,"merge retains custom phrase");
        check(new Config().width==1180&&new Config().height==768,"new geometry default");
        var a=p.parse(event("LFM Crab"),new Config());var b=p.parse(event("LFM Ratsar"),new Config());a.senderName="Z";b.senderName="A";a.seen=110;b.seen=100;
        check(SortPolicy.listing(a,b,2,true)<0,"newest first default");check(SortPolicy.listing(a,b,1,true)>0,"player sort");check(SortPolicy.listing(a,b,0,true)<0,"target sort");
        var first:simplelfg.LootBrowser.LootLine={title:"Axe",description:"",detail:"",itemId:"a",key:"a",iconKey:"a",rarity:"Rare",itemType:"Weapon"};
        var next:simplelfg.LootBrowser.LootLine={title:"Shield",description:"",detail:"",itemId:"b",key:"b",iconKey:"b",rarity:"Epic",itemType:"Shield"};
        check(SortPolicy.loot(first,next,0,true)<0&&SortPolicy.loot(first,next,0,false)>0,"loot name sort in both directions");
        check(SortPolicy.loot(first,next,1,true)>0&&SortPolicy.loot(first,next,2,true)>0,"loot rarity and type sort");
        var grown=Config.decode('{"version":2,"width":1600,"height":1000}');check(grown.width==1600&&grown.height==1000,"larger legacy dimensions preserved without compounding");
        check(!Reflect.hasField(legacy.draft,"roles")&&!Reflect.hasField(legacy.draft,"tanks"),"role fields absent from draft object");
        Sys.println("PASS "+n+" recognition, migration, role-removal and sorting checks");
    }
}
