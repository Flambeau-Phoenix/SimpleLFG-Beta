package simplelfg;

import simplelfg.Types;

/** Pure wire validation for the existing deployed 1.1 relay. No network or game reads. */
class RelayProtocol {
    public static inline var TTL=900;
    public static inline var MAX_RESPONSE=262144;
    public static function clean(value:String):String return Config.clean(value,512);
    public static function postError(c:Config,d:Draft,host:String):String {
        if(!c.relayEnabled)return "Enable cross-server listings in General first.";
        if(host==null||clean(host)==""||clean(host).length>24)return "Your character name must fit the relay's 24-character limit.";
        if(c.steamId!=""&&!SteamContact.valid(c.steamId))return "Use a numeric Steam ID / Friend Code, or leave it blank.";
        if(clean(d.activity)==""||clean(d.activity).length>32)return "Cross-server activity must be 1-32 characters.";
        if(d.kind=="LFM"&&(d.capacity>4||d.members>d.capacity))return "Cross-server parties support at most 4 players.";
        if(publicNote(c,d).length>64)return "Cross-server note (including difficulty / Bonus Runs) must fit 64 characters.";
        return "";
    }
    public static function note(d:Draft):String {
        var value=Config.difficulty(d.difficulty)+(d.bonusRuns?" / Bonus Runs":"");
        return clean(value+(d.note==""?"":" / "+d.note));
    }
    public static function body(c:Config,d:Draft,host:String):String {
        return haxe.Json.stringify({kind:d.kind,player_class:Config.playerClass(d.playerClass),host:clean(host),steam_id:c.steamId,activity:clean(d.activity),warriors:0,mages:0,priests:0,rogues:0,
            undefined:d.kind=="LFM"&&d.capacity>0?Std.int(Math.max(0,d.capacity-d.members)):0,note:publicNote(c,d),share_steam_public:c.shareSteamPublic});
    }
    static function publicNote(c:Config,d:Draft):String return c.shareSteamPublic||c.steamId==""?note(d):StringTools.replace(note(d),c.steamId,"[private]");
    public static function preview(c:Config,d:Draft,host:String):String {
        var error=postError(c,d,host);if(error!="")return error;
        return "Public cross-server "+d.kind+" listing: "+clean(host)+" | "+clean(d.activity)+(Config.playerClass(d.playerClass)==""?"":" | Class: "+d.playerClass)+" | "+publicNote(c,d)+" | "+(d.kind=="LFG"?"Solo player looking for a group":"Open slots: "+(d.capacity>0?Std.int(Math.max(0,d.capacity-d.members)):0))+" | Steam: "+(c.shareSteamPublic?c.steamId:"Private (share in messages)");
    }
    static function string(value:Dynamic,key:String,max:Int):Null<String> {
        var v:Dynamic=Reflect.field(value,key);
        if(!Std.isOfType(v,String))return null;
        var s:String=v;if(s.length>max||s.indexOf("\x00")>=0)return null;
        return Config.clean(s,max);
    }
    static function slots(value:Dynamic,key:String):Int {
        var v:Dynamic=Reflect.field(value,key);if(!Std.isOfType(v,Int))return -1;
        var n:Int=v;return n>=0&&n<=4?n:-1;
    }
    public static function listings(raw:String,now:Float,ownHost:String,ownSteam:String,ownSession:String=""):Array<Listing> {
        if(raw==null||raw.length>MAX_RESPONSE)throw "Relay response exceeds its size limit.";
        var parsed:Dynamic=haxe.Json.parse(raw);if(!Std.isOfType(parsed,Array))throw "Relay returned an invalid listings response.";
        var values:Array<Dynamic>=cast parsed;if(values.length>Board.LIMIT)values=values.slice(0,Board.LIMIT);
        var result:Array<Listing>=[];var ids:Map<String,Bool>=new Map();
        for(v in values){
            if(v==null||!Reflect.isObject(v)||Std.isOfType(v,Array))continue;
            var id=string(v,"id",128);var host=string(v,"host",24);var steam=string(v,"steam_id",32);var activity=string(v,"activity",32);var note=string(v,"note",64);
            if(id==null||id==""||host==null||host==""||steam==null||(steam!=""&&!SteamContact.valid(steam))||activity==null||activity==""||note==null)continue;
            var stamp:Dynamic=Reflect.field(v,"timestamp");if(!(Std.isOfType(stamp,Float)||Std.isOfType(stamp,Int)))continue;
            var seen:Float=stamp;if(!Math.isFinite(seen)||now-seen>=TTL||seen>now+60)continue;
            var w=slots(v,"warriors"),m=slots(v,"mages"),p=slots(v,"priests"),r=slots(v,"rogues"),u=slots(v,"undefined");
            if(w<0||m<0||p<0||r<0||u<0||w+m+p+r+u>4)continue;
            var address=string(v,"relay_session",32);if(address==null||!~/^[0-9a-f]{32}$/.match(address))address="";
            var identity=address!=""?address:id;var key="remote_"+haxe.crypto.Sha256.encode(identity).substr(0,24);
            if(ids.exists(key))continue;ids.set(key,true);
            var kind:Dynamic=Reflect.field(v,"kind");if(kind==null)kind="LFM";if(kind!="LFG"&&kind!="LFM")continue;
            var pc:Dynamic=Reflect.field(v,"player_class");if(pc==null)pc="";if(!Std.isOfType(pc,String)||(pc!=""&&Config.playerClass(pc)==""))continue;
            if(kind=="LFG"&&w+m+p+r+u!=0)continue;
            var l=new Listing();l.key=key;l.uiId=haxe.crypto.Sha256.encode(key).substr(0,24);l.isRemote=true;
            l.relaySessionId=address;
            l.playerClass=pc;
            l.isOwn=(ownSession!=""&&address==ownSession);
            l.senderId="relay_"+haxe.crypto.Sha256.encode(identity).substr(0,24);l.senderName=host;l.steamId=steam;l.kind=kind;l.isTest=Reflect.field(v,"is_test")==true;
            l.activityId="other";l.target=activity;l.activity=activity;
            for(a in TargetDefaults.activities())if(clean(a.name).toLowerCase()==activity.toLowerCase()){l.activityId=a.id;l.matchedTargetIds=[a.id];l.target=a.name;break;}
            l.composition=kind=="LFG"?"Solo player looking for a group":(w+m+p+r+u)+" advertised open slots";l.channel="Relay";l.contextDetected=true;l.seen=Math.min(seen,now);
            l.expiresAt=seen+TTL;l.text="[Cross-server] "+activity+(pc==""?"":" - Class: "+pc)+(note==""?"":" - "+note)+(steam==""?" [Steam code private]":" [Steam: "+steam+"]");result.push(l);
        }
        return result;
    }
}
