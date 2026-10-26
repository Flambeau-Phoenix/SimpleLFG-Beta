import simplelfg.LootBrowser;
import simplelfg.LootBrowser.LootData;

class LootTest {
    static var n=0;
    static function ok(v:Bool,label:String):Void {n++;if(!v) throw "Loot test failed: "+label;}
    static function main():Void {
        var raw='{"schema":1,"sourceSha256":"fixture","difficulty":["Normal","Veteran","Heroic"],"bosses":[{"id":"boss","name":"Fixture Boss","family":"Test Family","level":1,"sources":[{"kind":"Boss-kill source","id":"base"},{"kind":"Heroic source","id":"heroic"}]},{"id":"missing","name":"Missing Boss","family":"Test","level":1,"sources":[{"kind":"Boss-kill source","id":"missingTable"}]}],"items":[{"id":"a","name":"Fixture Sword","type":"Weapon","rarity":"Rare","description":"A test description."},{"id":"b","name":"Heroic Shield","type":"Shield","rarity":"Epic","description":"Heroic test."}],"tables":[{"id":"base","weighted":true,"affinity":false,"flags":["Weights"],"rows":[{"item":"a","table":"","weight":7.5,"quantityMin":1,"quantityMax":2,"minDifficulty":0,"maxDifficulty":2,"notes":[]},{"item":"","table":"nested","weight":1.0,"quantityMin":1,"quantityMax":1,"minDifficulty":1,"maxDifficulty":2,"notes":["Conditional parent"]}]},{"id":"nested","weighted":false,"affinity":false,"flags":[],"rows":[{"item":"b","table":"","weight":0.1,"quantityMin":1,"quantityMax":1,"minDifficulty":1,"maxDifficulty":2,"notes":[]},{"item":"","table":"base","weight":1.0,"quantityMin":1,"quantityMax":1,"minDifficulty":0,"maxDifficulty":2,"notes":[]}]},{"id":"heroic","weighted":true,"affinity":true,"flags":["Weights","WithAffinity"],"rows":[{"item":"b","table":"","weight":2.0,"quantityMin":1,"quantityMax":1,"minDifficulty":2,"maxDifficulty":2,"notes":[]}]}]}';
        var model=new LootBrowser(raw);
        ok(model.error=="","valid fixture");
        model.filterBosses("family");ok(model.bosses.length==1,"boss family search");
        model.filterBosses("missing");ok(model.bosses.length==1,"boss name search");
        model.choose("boss",0);ok(model.lines.length==1,"normal excludes veteran nested and heroic sources");
        ok(model.lines[0].title=="Fixture Sword","item naming");
        ok(model.lines[0].detail.indexOf("weight 7.5")>=0,"authored weight preserved");
        ok(model.lines[0].detail.indexOf("%")<0,"no invented percentages");
        ok(model.lines[0].detail.indexOf("x1-2")>=0,"quantity range");
        model.choose("boss",1);ok(model.lines.length==3,"veteran nested row and bounded cycle notice");
        ok(model.lines[1].detail.indexOf("Conditional parent")>=0,"inherited condition note");
        ok(model.lines[2].title=="Cyclic loot reference","cycle detection");
        model.choose("boss",2);ok(model.lines.length==4,"heroic-specific pool included");
        ok(model.lines[3].detail.indexOf("Affinity-dependent")>=0,"affinity condition exposed");
        model.choose("boss",2,"sword");ok(model.lines.length==1,"item search");
        model.choose("missing",0);ok(model.lines.length==1 && model.lines[0].title=="Loot source unavailable","missing source explicit");
        model.choose("unknown",0);ok(model.selected==null && model.lines.length==0,"unknown selection");
        model.choose("boss",999);ok(model.difficulty==2,"difficulty clamp");
        ok(new LootBrowser("{bad").error!="","malformed data recovery");
        var malformed=new LootBrowser("{}");malformed.filterBosses("");malformed.choose("boss",0);
        ok(malformed.error!="" && malformed.lines.length==0,"partial malformed catalogue remains safe to observe");
        var root="assets/boss-loot.json";
        var real=new LootBrowser(sys.io.File.getContent(root));
        ok(real.error=="","real current catalogue parses");
        ok(real.data.bosses.length==14,"fourteen bosses with explicit boss-only sources");
        var tableIds=new Map<String,Bool>();
        for(t in real.data.tables) tableIds.set(t.id,true);
        for(b in real.data.bosses) {
            ok(b.sources.length>0,"each included boss has explicit source");
            for(s in b.sources) {ok(s.kind!="Regular source","regular loot excluded");ok(tableIds.exists(s.id),"boss source resolves");}
            for(d in 0...3) {real.choose(b.id,d);ok(real.lines.length<=512,"bounded boss rows");}
        }
        var items=new Map<String,Bool>();for(i in real.data.items) items.set(i.id,true);
        for(t in real.data.tables) for(e in t.rows) {
            if(e.item!="") ok(items.exists(e.item),"all referenced items resolve");
            if(e.table!="") ok(tableIds.exists(e.table),"all nested tables resolve");
        }
        Sys.println("PASS "+n+" boss-loot checks");
    }
}
