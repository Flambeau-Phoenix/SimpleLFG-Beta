package simplelfg;

typedef LootSource = {var kind:String; var id:String;}
typedef LootBoss = {var id:String; var name:String; var level:Int; var family:String; var sources:Array<LootSource>;}
typedef LootEntry = {
    var item:String; var table:String; var weight:Float;
    var quantityMin:Int; var quantityMax:Int;
    var minDifficulty:Int; var maxDifficulty:Int; var notes:Array<String>;
}
typedef LootTable = {var id:String; var weighted:Bool; var affinity:Bool; var flags:Array<String>; var rows:Array<LootEntry>;}
typedef LootItem = {var id:String; var name:String; var type:String; var rarity:String; var description:String;}
typedef LootData = {
    var schema:Int; var sourceSha256:String; var difficulty:Array<String>;
    var bosses:Array<LootBoss>; var tables:Array<LootTable>; var items:Array<LootItem>;
}
typedef LootLine = {var title:String; var description:String; var detail:String; var itemId:String; var key:String; var iconKey:String; var rarity:String; var itemType:String;}

/** Native-free static-data model. Cache rebuilds happen in observation, never drawing. */
class LootBrowser {
    public var data(default,null):LootData;
    public var bosses(default,null):Array<LootBoss>=[];
    public var lines(default,null):Array<LootLine>=[];
    public var selected(default,null):LootBoss=null;
    public var summary(default,null):String="Select a boss to inspect its linked loot sources.";
    public var error(default,null):String="";
    public var difficulty(default,null):Int=0;
    var tables:Map<String,LootTable>=[];
    var items:Map<String,LootItem>=[];
    var visitedNodes:Int=0;
    public function new(raw:String) {
        try {
            data=haxe.Json.parse(raw);
            if(data.schema!=1 || data.bosses==null || data.tables==null || data.items==null) throw "Invalid loot catalogue";
            for(t in data.tables) tables.set(t.id,t);
            for(i in data.items) items.set(i.id,i);
            filterBosses("");
        } catch(_:Dynamic) {data=null;error="Boss loot catalogue unavailable.";}
    }
    public function filterBosses(query:String):Void {
        if(data==null) return;
        var q=StringTools.trim(query).toLowerCase();
        bosses=[for(b in data.bosses) if(q=="" || (b.name+" "+b.id+" "+b.family).toLowerCase().indexOf(q)>=0) b];
    }
    public function choose(id:String,diff:Int,itemQuery:String=""):Void {
        if(data==null) return;
        selected=null;for(b in data.bosses) if(b.id==id) {selected=b;break;}
        difficulty=diff<0?0:(diff>2?2:diff);lines=[];visitedNodes=0;
        if(selected==null) {summary="Select a boss to inspect its linked loot sources.";return;}
        var q=StringTools.trim(itemQuery).toLowerCase();
        var sourceCount=0;
        for(s in selected.sources) {
            if(s.kind=="Heroic source" && difficulty!=2) continue;
            sourceCount++;
            expand(s.id,s.kind,[],[],q);
        }
        summary=selected.name+" | "+data.difficulty[difficulty]+" | "+lines.length+" matching item/source lines";
        if(sourceCount==0) summary="No direct loot table is linked for this boss/difficulty in data.cdb.";
    }
    function add(title:String,detail:String,description:String,item:String,key:String,query:String):Void {
        if(lines.length>=512) return;
        if(query!="" && (title+" "+detail+" "+description+" "+item).toLowerCase().indexOf(query)<0) return;
        var info=items.get(item);
        lines.push({title:title,detail:detail,description:description,itemId:item,key:key,iconKey:item,rarity:info==null?"":info.rarity,itemType:info==null?"":info.type});
    }
    function expand(id:String,source:String,path:Array<String>,conditions:Array<String>,query:String):Void {
        if(++visitedNodes>2048 || path.length>=12) {
            add("Nested loot traversal limit",source+" / "+id,"Source nesting was capped; no further items are inferred.","",id,query);return;
        }
        if(path.indexOf(id)>=0) {add("Cyclic loot reference",source+" / "+id,"This source refers back to an earlier table.","",id,query);return;}
        var table=tables.get(id);
        if(table==null) {add("Loot source unavailable",source+" / "+id,"The referenced table is absent from the catalogue.","",id,query);return;}
        var next=path.copy();next.push(id);
        var tableMode=table.weighted?"weight":"authored probability";
        var rowIndex=0;
        for(row in table.rows) {
            var index=rowIndex++;
            if(difficulty<row.minDifficulty || difficulty>row.maxDifficulty) continue;
            var notes=conditions.copy();
            notes.push(id+" "+tableMode+" "+Std.string(row.weight));
            if(table.affinity) notes.push("Affinity-dependent source");
            for(flag in table.flags) if(flag!="Weights" && flag!="WithAffinity") notes.push(flag);
            if(row.minDifficulty>0 || row.maxDifficulty<2) notes.push("Difficulty gate: "+data.difficulty[row.minDifficulty]+"-"+data.difficulty[row.maxDifficulty]);
            for(note in row.notes) notes.push(note);
            if(row.table!="") expand(row.table,source,next,notes,query);
            else if(row.item!="") {
                var item=items.get(row.item);
                var title=item==null?row.item+" (item record unavailable)":item.name;
                var detail=source+" | "+(item==null?"":item.rarity+" / "+item.type+" | ");
                detail+="x"+row.quantityMin+(row.quantityMax!=row.quantityMin?"-"+row.quantityMax:"");
                detail+=" | "+notes.join(" | ");
                add(title,detail,item==null?"":item.description,row.item,source+"/"+next.join("/")+"/"+index,query);
            }
        }
    }
}
