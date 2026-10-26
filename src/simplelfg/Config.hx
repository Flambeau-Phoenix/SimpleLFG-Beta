package simplelfg;

import simplelfg.Types.Draft;
import simplelfg.Types.IgnoreRule;
import simplelfg.Types.TargetAlias;

class Config {
    public var version:Int = 4;
    public var geometryVersion:Int = 2;
    @:transient public var migrated:Bool=false;
    public var hotkey:Int = 5;
    public var monitoredChannels:Array<String> = ChannelPolicy.names.copy();
    public var requireRecruitingContext:Bool = false;
    public var expirySeconds:Int = 300;
    public var textScale:Float = 1.0;
    public var highContrast:Bool = false;
    public var reminder:Bool = false;
    public var draft:Draft = new Draft();
    public var templates:Array<Draft> = [];
    public var ignored:Array<IgnoreRule> = [];
    public var width:Float = 1440;
    public var height:Float = 900;
    public var windowX:Float = -1;
    public var windowY:Float = -1;
    public var theme:String = "Midnight";
    public var accent:Int = 0x4388BD;
    public var background:Int = 0x101720;
    public var surface:Int = 0x1B2836;
    public var foreground:Int = 0xE7EEF6;
    public var opacity:Float = 1;
    public var launcherEnabled:Bool = true;
    public var lfgWords:Array<String> = ["lfg","looking for group","looking for a group","looking to join","need a group","seeking a group","any groups","lf party","looking for party","looking for a party","inv me","invite me","lfp","lft","lf group","lf grp","lf team","lf raid","looking for team","looking for a team","looking for raid","need party","need group","need team","seeking group","seeking party","invite pls","inv pls","invite please","inv please","can join","available for group"];
    public var lfmWords:Array<String> = ["lfm","lf#m","looking for more","recruiting","need","needs","seeking","join us","looking for","forming","starting a group","group forming","pst for invite","pm for invite","whisper for invite","spots open","slots open","need more","come join","anyone up for","anyone for","lf more","lf members","lf players","looking for members","looking for players","looking for tank","looking for healer","looking for dps","need tank","need healer","need dps","need people","need players","need members","open spot","open spots","last spot","last slot","group up","party forming","pst","pm","dm","whisper","inv","invite"];
    public var contextWords:Array<String> = ContextDefaults.merge(["run","runs","running","boss","bosses","farm","farming","clear","clears","dungeon","dungeons","bonus run","bonus runs","glory run","glory runs","heroic run","heroic runs","veteran run","veteran runs","normal run","normal runs","norm","vet","hc","hm","nm","heroic","veteran","normal","dung","dgn","farm run","farm runs","lf run","lf runs"]);
    public var contextWordsVersion:Int=1;
    public var targetAliases:Array<TargetAlias> = TargetDefaults.aliases();
    public var excludedWords:Array<String> = ["wts","wtb","selling","buying"];
    public var alertsEnabled:Bool = false;
    public var alertSound:Bool = false;
    public var watchActivities:Array<String> = [];
    public var steamId:String = "";
    public var relayEnabled:Bool=true;
    public var networkVersion:Int=3;
    public var shareSteamPublic:Bool=false;
    public var steamPrivacyVersion:Int=1;
    public function new() {}

    public static function str(o:Dynamic, name:String, max:Int, fallback:String=""):String {
        if (o == null || !Reflect.isObject(o)) return fallback;
        var v:Dynamic = Reflect.field(o, name);
        if (!Std.isOfType(v, String)) return fallback;
        return clean(cast v, max);
    }
    public static function clean(s:String, max:Int):String {
        if (s == null) return "";
        s = ~/\s+/g.replace(s, " ");
        // Strip control characters, including NUL; never inject a new chat line.
        s = ~/[\x00-\x1f\x7f]/g.replace(s, "");
        return StringTools.trim(s).substr(0,max);
    }
    static function number(o:Dynamic, name:String, fallback:Float, min:Float, max:Float):Float {
        var v:Dynamic = o == null ? null : Reflect.field(o,name);
        if (!(Std.isOfType(v,Int) || Std.isOfType(v,Float))) return fallback;
        var f:Float = v;
        return Math.isFinite(f) ? Math.max(min,Math.min(max,f)) : fallback;
    }
    static function flag(o:Dynamic,name:String, fallback:Bool):Bool {
        var v:Dynamic=o == null ? null : Reflect.field(o,name);
        return Std.isOfType(v,Bool) ? v : fallback;
    }
    public static function readDraft(o:Dynamic):Draft {
        var d=new Draft();
        if (o==null || !Reflect.isObject(o)) return d;
        d.kind = str(o,"kind",3)=="LFG" ? "LFG" : "LFM";
        d.bonusRuns=flag(o,"bonusRuns",false);
        d.activity=str(o,"activity",80); d.difficulty=difficulty(str(o,"difficulty",32));
        d.note=str(o,"note",160);
        d.playerClass=playerClass(str(o,"playerClass",16));
        var channel=str(o,"channel",8);d.channel=channel=="Relay"?"Relay":(channel=="Local"?"Local":"All");
        d.capacity=Std.int(number(o,"capacity",4,0,4));
        if(d.capacity==0)d.capacity=4;
        d.members=Std.int(number(o,"members",0,0,Math.min(3,d.capacity-1)));
        return d;
    }
    public static function decode(text:String):Config {
        var c=new Config();
        var o:Dynamic;
        try o=haxe.Json.parse(text) catch (_:Dynamic) return c;
        if (o==null || !Reflect.isObject(o) || Std.isOfType(o,Array) || Std.isOfType(o,String)) return c;
        c.hotkey=5;
        if(number(o,"hotkey",5,1,12)!=5)c.migrated=true;
        c.steamId=str(o,"steamId",32,"");c.relayEnabled=number(o,"networkVersion",0,0,3)<3?true:flag(o,"relayEnabled",true);
        if(number(o,"networkVersion",0,0,3)<3)c.migrated=true;
        c.shareSteamPublic=flag(o,"shareSteamPublic",false);
        if(number(o,"steamPrivacyVersion",0,0,1)<1){c.shareSteamPublic=false;c.migrated=true;}
        c.monitoredChannels=number(o,"version",0,0,4)<4?ChannelPolicy.names.copy():[for(v in words(Reflect.field(o,"monitoredChannels"),ChannelPolicy.names,32,6))if(ChannelPolicy.known(v))v];
        c.requireRecruitingContext=flag(o,"requireRecruitingContext",false);
        c.expirySeconds=Std.int(number(o,"expirySeconds",300,60,1800));
        c.textScale=number(o,"textScale",1,0.85,1.5);
        c.highContrast=flag(o,"highContrast",false); c.reminder=flag(o,"reminder",false);
        c.width=number(o,"width",1440,520,32768); c.height=number(o,"height",900,360,32768);
        if(number(o,"geometryVersion",0,0,2)<2){
            c.width=Math.max(1440,c.width);c.height=Math.max(900,c.height);c.migrated=true;
        }
        c.windowX=number(o,"windowX",-1,-1,32000);c.windowY=number(o,"windowY",-1,-1,32000);
        c.theme=str(o,"theme",24,"Midnight");
        if(["Midnight","Slate","Warm","Custom"].indexOf(c.theme)<0)c.theme="Midnight";
        c.accent=Std.int(number(o,"accent",c.accent,0,0xFFFFFF));
        c.background=Std.int(number(o,"background",c.background,0,0xFFFFFF));
        c.surface=Std.int(number(o,"surface",c.surface,0,0xFFFFFF));
        c.foreground=Std.int(number(o,"foreground",c.foreground,0,0xFFFFFF));
        c.opacity=number(o,"opacity",1,0.65,1);
        c.launcherEnabled=flag(o,"launcherEnabled",true);
        c.lfgWords=words(Reflect.field(o,"lfgWords"),c.lfgWords);
        c.lfmWords=words(Reflect.field(o,"lfmWords"),c.lfmWords);
        c.excludedWords=words(Reflect.field(o,"excludedWords"),c.excludedWords);
        c.contextWords=words(Reflect.field(o,"contextWords"),c.contextWords);
        if(number(o,"version",0,0,3)<3){
            var oldSolo=["lfg","looking for group","looking for a group","looking to join"];
            var oldMore=["lfm","lf#m","looking for more","recruiting","need","needs","seeking","join us","looking for"];
            if(sameWords(c.lfgWords,oldSolo))c.lfgWords=new Config().lfgWords;
            if(sameWords(c.lfmWords,oldMore))c.lfmWords=new Config().lfmWords;
            c.migrated=true;
        }
        var aliases:Dynamic=Reflect.field(o,"targetAliases");
        if(Std.isOfType(aliases,Array)){
            c.targetAliases=[];var entries:Array<Dynamic>=cast aliases;
            var seen:Map<String,Bool>=new Map();for(v in entries.slice(0,512)) {var id=str(v,"targetId",128);var name=str(v,"name",80);var phrase=str(v,"phrase",80);var key=id+"\x1f"+phrase.toLowerCase();if(id!=""&&name!=""&&phrase!=""&&!seen.exists(key)){seen.set(key,true);c.targetAliases.push({targetId:id,name:name,phrase:phrase});}}
        }
        if(number(o,"version",0,0,4)<4){
            var expanded=new Config();
            if(sameWords(c.lfgWords,TargetDefaults.legacy_lfgWords()))c.lfgWords=expanded.lfgWords;
            if(sameWords(c.lfmWords,TargetDefaults.legacy_lfmWords()))c.lfmWords=expanded.lfmWords;
            if(sameWords(c.contextWords,TargetDefaults.legacy_contextWords()))c.contextWords=expanded.contextWords;
            var legacy=TargetDefaults.legacyAliases();var untouched=c.targetAliases.length==legacy.length;
            if(untouched)for(a in legacy){var found=false;for(b in c.targetAliases)if(a.targetId==b.targetId&&a.phrase.toLowerCase()==b.phrase.toLowerCase())found=true;if(!found)untouched=false;}
            if(untouched)c.targetAliases=expanded.targetAliases;
            c.migrated=true;
        }
        if(number(o,"contextWordsVersion",0,0,1)<1){
            c.contextWords=ContextDefaults.merge(c.contextWords);c.migrated=true;
        }
        c.alertsEnabled=flag(o,"alertsEnabled",false);c.alertSound=flag(o,"alertSound",false);
        c.watchActivities=words(Reflect.field(o,"watchActivities"),[],128,64);
        c.draft=readDraft(Reflect.field(o,"draft"));
        var ts:Dynamic=Reflect.field(o,"templates");
        if (Std.isOfType(ts,Array)) {
            var a:Array<Dynamic>=cast ts;
            for (v in a.slice(0,5)) if (v!=null && Reflect.isObject(v)) c.templates.push(readDraft(v));
        }
        var ig:Dynamic=Reflect.field(o,"ignored");
        if (Std.isOfType(ig,Array)) {
            var a:Array<Dynamic>=cast ig;
            for (v in a.slice(0,200)) {
                var id=str(v,"id",128);
                if (id!="") c.ignored.push({id:id,name:str(v,"name",80),until:number(v,"until",0,0,1e14)});
            }
        }
        var before=c.targetAliases.length+c.watchActivities.length;
        c.targetAliases=[for(a in c.targetAliases)if(!TargetDefaults.unavailableTarget(a.targetId)&&!TargetDefaults.unavailableTarget(a.name))a];
        c.watchActivities=[for(id in c.watchActivities)if(!TargetDefaults.unavailableTarget(id))id];
        if(before!=c.targetAliases.length+c.watchActivities.length)c.migrated=true;
        for(d in [c.draft].concat(c.templates))if(TargetDefaults.unavailableTarget(d.activity)){d.activity="";c.migrated=true;}
        return c;
    }
    public static function difficulty(value:String):String {
        var s=value==null?"":value.toLowerCase();
        return s=="heroic"?"Heroic":(s=="veteran"?"Veteran":"Normal");
    }
    public static function playerClass(value:String):String return value=="Warrior"||value=="Mage"||value=="Priest"||value=="Rogue"?value:"";
    public static function sameWords(a:Array<String>,b:Array<String>):Bool {if(a.length!=b.length)return false;for(v in a)if(b.indexOf(v)<0)return false;return true;}
    public function mergeDefaults():Void {
        var d=new Config();for(pair in [{a:lfgWords,b:d.lfgWords},{a:lfmWords,b:d.lfmWords},{a:contextWords,b:d.contextWords},{a:excludedWords,b:d.excludedWords}])for(s in pair.b)if(!Parser.matchesExact(pair.a,s)&&pair.a.length<256)pair.a.push(s);
        for(v in d.targetAliases){var found=false;for(a in targetAliases)if(a.targetId==v.targetId&&a.phrase.toLowerCase()==v.phrase.toLowerCase())found=true;if(!found&&targetAliases.length<512)targetAliases.push(v);}
    }
    public static function words(value:Dynamic,fallback:Array<String>,max:Int=48,limit:Int=256):Array<String> {
        if(!Std.isOfType(value,Array)) return fallback.copy();
        var result:Array<String>=[];var a:Array<Dynamic>=cast value;
        for(v in a.slice(0,limit)) if(Std.isOfType(v,String)) {
            var s=clean(cast v,max);var key=s.toLowerCase();
            if(s!="" && [for(x in result)x.toLowerCase()].indexOf(key)<0) result.push(s);
        }
        return result;
    }
    public function encode():String {var o:Dynamic={};for(key in Reflect.fields(this))if(key!="migrated")Reflect.setField(o,key,Reflect.field(this,key));return haxe.Json.stringify(o,null,"  ");}
}
