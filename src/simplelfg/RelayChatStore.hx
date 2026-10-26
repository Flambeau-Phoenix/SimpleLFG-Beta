package simplelfg;

typedef RelayChatLine={var id:Int;var peer:String;var name:String;var text:String;var outgoing:Bool;var time:Float;}
typedef RelayPeer={var id:String;var name:String;}

/** Session-only messages, never written into settings or captured from native chat. */
class RelayChatStore {
    public var revision(default,null)=0;
    public var unread(default,null)=0;
    var lines:Array<RelayChatLine>=[];
    public function new(){}
    public function clear():Void {lines=[];unread=0;revision++;}
    public function read():Void {if(unread>0){unread=0;revision++;}}
    public function remember(id:Int,peer:String,name:String,text:String,outgoing:Bool,time:Float):Void {
        if(id<=0||!~/^[0-9a-f]{32}$/.match(peer)||text==null||text.length>240||name==null||name.length>24||!Math.isFinite(time))return;
        for(line in lines)if(line.id==id)return;
        lines.push({id:id,peer:peer,name:Config.clean(name,24),text:Config.clean(text,240),outgoing:outgoing,time:time});
        if(!outgoing)unread++;
        while(lines.length>500)lines.shift();revision++;
    }
    public function peers():Array<RelayPeer> {
        var result:Array<RelayPeer>=[];var seen:Map<String,Bool>=[];
        var i=lines.length;while(i>0){var line=lines[--i];if(!seen.exists(line.peer)){seen.set(line.peer,true);result.push({id:line.peer,name:line.name});}}
        return result;
    }
    public function conversation(peer:String):Array<RelayChatLine> return [for(line in lines)if(line.peer==peer)line];
    public function contactsFor(peer:String):Array<SteamContactLookup.SteamContactMatch> {
        return SteamContactLookup.find([for(line in lines)if(line.peer==peer&&!line.outgoing)line.text]);
    }
    public function expire(now:Float):Void {var n=lines.length;lines=[for(line in lines)if(now-line.time<1800)line];if(lines.length!=n)revision++;}
}
