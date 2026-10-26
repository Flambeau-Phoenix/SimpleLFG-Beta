package simplelfg;

import simplelfg.Types.Draft;

class Confirmation {
    public var target(default,null):String="";
    public function new(){}
    public function clear():Void target="";
    public function press(id:String):Bool {if(target==id){clear();return true;}target=id;return false;}
}
class TemplateRow {
    public var draft:Draft;public var id:String;public var label:String;public var menuId:String;
    public function new(d:Draft,id:String){draft=d;this.id=id;menuId=id+".menu";label=StringTools.replace(d.kind+" - "+d.activity,"#","# ");}
}
/** Object identity is local configuration identity, never a live game pointer. */
class TemplateRows {
    var identities=new haxe.ds.ObjectMap<Draft,TemplateRow>();var next:Int=0;
    public var rows(default,null):Array<TemplateRow>=[];
    public function new(){}
    public function update(templates:Array<Draft>):Void {
        rows=[];var retained=new haxe.ds.ObjectMap<Draft,TemplateRow>();
        for(d in templates){var row=identities.get(d);if(row==null)row=new TemplateRow(d,"template_"+next++);retained.set(d,row);rows.push(row);}
        identities=retained;
    }
}
