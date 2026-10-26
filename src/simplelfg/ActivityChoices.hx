package simplelfg;

import simplelfg.Types.Activity;

class ActivityChoice {
    public var activity:Activity;public var id:String;
    public function new(a:Activity){activity=a;id="activity_"+a.id;}
}
/** Queries and ID strings are prepared in observation, not in the draw loop. */
class ActivityChoices {
    public var search=new TextBuffer(128);
    public var rows(default,null):Array<ActivityChoice>=[];
    var all:Array<ActivityChoice>=[];var pending:Bool=true;
    public function new(){for(a in Catalogue.items)all.push(new ActivityChoice(a));}
    public function changed():Void pending=true;
    public function observe():Void {
        if(!pending)return;pending=false;
        var terms=SearchTerms.parse(search.get());
        rows=[for(row in all)if(terms.length==0||matchesActivity(row.activity,terms))row];
    }
    static function matchesActivity(a:Activity, terms:Array<String>):Bool {
        return SearchTerms.matches([a.name].concat(a.aliases),terms);
    }
}
