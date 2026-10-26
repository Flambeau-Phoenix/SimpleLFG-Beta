import simplelfg.Config;
import simplelfg.TargetDefaults;
import simplelfg.SteamContact;
import simplelfg.RelayProtocol;
import simplelfg.Engine;
import simplelfg.Parser;
import simplelfg.CrossServerRelay;
import NetworkTest.MockRelay;
import TestMain.FakeChat;

class Release018Test {
    static var checks=0;
    static function ok(value:Bool,label:String):Void {checks++;if(!value)throw label;}
    static function main():Void {
        var classConfig=new Config();classConfig.draft.activity="Boss farm";classConfig.draft.playerClass="Mage";
        classConfig.templates=[classConfig.draft.copy()];
        var classReload=Config.decode(classConfig.encode());
        ok(classReload.draft.playerClass=="Mage"&&classReload.templates[0].playerClass=="Mage","optional class survives draft and template copies/reloads");
        ok(Parser.preview(classReload.draft).indexOf("Class: Mage")>=0,"native chat preview includes the selected class");
        ok(haxe.Json.parse(RelayProtocol.body(classReload,classReload.draft,"Hero")).player_class=="Mage","relay class is separate metadata");
        ok(RelayProtocol.preview(classReload,classReload.draft,"Hero").indexOf("Class: Mage")>=0,"relay preview shows the selected class");
        ok(new Config().draft.playerClass==""&&Config.readDraft({playerClass:"<script>"}).playerClass=="","class is optional and unknown saved classes are rejected");
        var context=Config.decode('{"version":4,"networkVersion":3,"geometryVersion":2,"contextWords":["Custom Run","Heroic","HC","Farm"]}');
        ok(context.contextWords.indexOf("Custom Run")>=0&&context.contextWords.indexOf("speed")>=0&&context.contextWords.indexOf("te'ror")>=0,"requested context merges into saved filters without losing custom phrases");
        var heroic=0;for(word in context.contextWords)if(word.toLowerCase()=="heroic")heroic++;
        ok(heroic==1,"requested context migration deduplicates case variants");
        context.contextWords.remove("speed");
        ok(Config.decode(context.encode()).contextWords.indexOf("speed")<0,"later context removals survive reload");
        ok(new Config().excludedWords.indexOf("heroic")<0,"recruiting context never becomes an exclusion");
        var recognition=new simplelfg.RecognitionIndex(["speed","chillrun","crabgantua's","te'ror"]);
        ok(recognition.matches("speed")&&recognition.matches("chillrun")&&recognition.matches(simplelfg.RecognitionIndex.RecognitionWord.fold("Crabgantua’s")),"context recognizes whole words and apostrophe variants");
        ok(!recognition.matches("speedometer")&&!recognition.matches("chillrunner"),"context does not match inside unrelated words");
        var tagged=simplelfg.SteamContactLookup.find(["[Steam: 123456]","newer 76561198012345678"]);
        ok(tagged.length==1&&tagged[0].value=="123456","our syntax takes precedence across the conversation before fallback");
        ok(simplelfg.SteamContactLookup.find(["[Steam: invalid]","76561198012345678"])[0].value=="76561198012345678","Steam64 fallback only after our syntax fails");
        var contactURL="https://steamcommunity.com/profiles/76561197960389184";
        for(text in ["123456","friend code: 123456","STEAM_0:0:61728","[U:1:123456]","https://steamcommunity.com/profiles/76561197960389184"]){
            var found=simplelfg.SteamContactLookup.find([text]);ok(found.length==1&&found[0].profile==contactURL,"supported numeric/legacy Steam formats resolve to one fixed official profile");
        }
        for(text in ["we did 123456 damage","20","76561197960265728","76561202255233024","18446744073709551616","[Steam: 4294967296]","https://evil.example/?code=123456","STEAM_0:1:4294967295","[U:1:0]"])
            ok(simplelfg.SteamContactLookup.find([text]).length==0,"invalid formats and ordinary embedded numbers do not create links");
        var chat=new simplelfg.RelayChatStore();var peer="0123456789abcdef0123456789abcdef";var other="1123456789abcdef0123456789abcdef";
        chat.remember(1,other,"Other","[Steam: 654321]",false,100);
        chat.remember(2,peer,"Peer","[Steam: 999999]",true,101);
        ok(chat.contactsFor(peer).length==0,"contact lookup ignores other conversations and our own messages");
        chat.remember(3,peer,"Peer","[Steam: 123456]",false,102);
        ok(chat.contactsFor(peer)[0].value=="123456","explicit lookup uses only the selected recipient's messages");
        chat.clear();ok(chat.contactsFor(peer).length==0,"contacts clear with private session history");
        var privateDefaults=new Config();
        ok(privateDefaults.steamId==""&&!privateDefaults.shareSteamPublic,"fresh settings contain no Steam contact and sharing is off");
        var privateUpgrade=Config.decode('{"steamId":"123456","shareSteamPublic":true}');
        ok(privateUpgrade.steamId=="123456"&&!privateUpgrade.shareSteamPublic,"privacy upgrade keeps a deliberately saved contact but requires new public consent");
        privateUpgrade.shareSteamPublic=true;
        ok(Config.decode(privateUpgrade.encode()).shareSteamPublic,"later explicit sharing consent persists");
        var emptyTransport=new MockRelay();var emptyEngine=new Engine(privateDefaults,new FakeChat(),new Parser(TargetDefaults.activities()),new CrossServerRelay(emptyTransport));
        emptyEngine.relayVisible=true;emptyEngine.tick(100);
        var created=false;for(request in emptyTransport.requests)if(request.kind=="session"&&haxe.Json.parse(request.body).steam_id=="")created=true;
        ok(created,"private session connects with a blank Steam contact");
        privateDefaults.draft.activity="Boss farm";
        ok(RelayProtocol.postError(privateDefaults,privateDefaults.draft,"Hero")=="","posting is allowed with a blank Steam contact");
        var legacy=new Config();legacy.hotkey=8;legacy.networkVersion=2;legacy.relayEnabled=false;
        legacy.draft.activity="ul'Serous, Herald Avatar";legacy.draft.note="Keep 123456";legacy.draft.channel="Local";
        legacy.targetAliases.push({targetId:"boss:Queenslayer",name:"Queenslayer",phrase:"qs"});
        legacy.watchActivities=["boss:Phrixes_NightGod","custom:Queenslayer","custom:Released Custom"];
        var template=legacy.draft.copy();template.activity="Phrixes_NightGod";legacy.templates=[template];
        var migrated=Config.decode(legacy.encode());
        ok(migrated.hotkey==5&&migrated.relayEnabled,"upgrade selects F5 and enables relay once");
        ok(migrated.draft.channel=="Local"&&migrated.draft.note=="Keep 123456"&&migrated.draft.activity=="","migration preserves draft except excluded activity");
        ok(migrated.templates.length==1&&migrated.templates[0].activity==""&&migrated.templates[0].note=="Keep 123456","template fields survive excluded selection cleanup");
        ok(migrated.watchActivities.length==1&&migrated.watchActivities[0]=="custom:Released Custom","only unreleased watches removed");
        for(a in migrated.targetAliases)ok(!TargetDefaults.unavailableTarget(a.targetId),"unreleased alias absent");
        migrated.relayEnabled=false;ok(!Config.decode(migrated.encode()).relayEnabled,"later relay opt-out survives save/load");
        ok(TargetDefaults.bosses().length==14,"released boss inventory");
        var chakram=false;
        for(b in TargetDefaults.bosses()){ok(!TargetDefaults.unavailableTarget(b.id),"unreleased boss absent");if(b.id=="Phrixes")chakram=true;}
        ok(chakram,"released High Inquisitor Chakram preserved");
        for(text in ["Hi [Steam: 123456] there [sTeAmId: 999]", "[steam id: 1]", "123456 + (bonus) [Steam: 1]"]){
            var removed=SteamContact.detach(text);ok(SteamContact.extract(removed)=="","all attached Steam tags removed");
        }
        ok(SteamContact.detach("Hi [Steam: 123456] there [sTeAmId: 999]")=="Hi there","duplicate/mixed-case tags normalize spacing");
        ok(SteamContact.detach("123456 + (bonus) [Steam: 1]")=="123456 + (bonus)","ordinary numbers and punctuation preserved");
        ok(SteamContact.detach("")==""&&SteamContact.detach("[Steamworks]")=="[Steamworks]","empty composer and unrelated bracket text preserved");
        for(cursor in [false,true]){
            var transport=new MockRelay();var adapter=new FakeChat();adapter.current.playerName="Hero";adapter.current.cursorFree=cursor;
            var config=new Config();config.steamId="123456";var engine=new Engine(config,adapter,new Parser(TargetDefaults.activities()),new CrossServerRelay(transport));
            engine.relayVisible=true;engine.tick(100);ok(transport.requests.length==2,"relay connects regardless of pointer mode");
            var generation=engine.relay.generation;adapter.current.cursorFree=!cursor;engine.tick(101);ok(engine.relay.generation==generation,"pointer transitions do not restart the relay session");
        }
        var config=new Config();config.steamId="123456";config.draft.kind="LFG";config.draft.capacity=40;config.draft.members=10;config.draft.activity="Boss farm";
        var data:Dynamic=haxe.Json.parse(RelayProtocol.body(config,config.draft,"Hero"));
        ok(data.kind=="LFG"&&data.undefined==0&&RelayProtocol.postError(config,config.draft,"Hero")=="","solo publishing ignores retained group fields");
        ok(RelayProtocol.preview(config,config.draft,"Hero").indexOf("Solo player")>=0,"solo preview identifies looking-for-group state");
        var row:Dynamic={id:"test",kind:"LFG",is_test:true,host:"SimpleLFG Test",steam_id:"",activity:"Messaging test",note:"TEST ONLY",warriors:0,mages:0,priests:0,rogues:0,undefined:0,timestamp:100,relay_session:"0123456789abcdef0123456789abcdef"};
        var rows=RelayProtocol.listings(haxe.Json.stringify([row]),100,"Hero","123456");
        ok(rows.length==1&&rows[0].kind=="LFG"&&rows[0].isTest,"server-owned test contact and solo kind accepted");
        row.undefined=1;ok(RelayProtocol.listings(haxe.Json.stringify([row]),100,"Hero","123456").length==0,"malformed solo recruiting slots rejected");
        row.kind="LFM";Reflect.deleteField(row,"kind");rows=RelayProtocol.listings(haxe.Json.stringify([row]),100,"Hero","123456");ok(rows.length==1&&rows[0].kind=="LFM","old listing payload defaults to LFM");
        Sys.println("PASS "+checks+" release 0.1.8 migration, catalogue, composer and relay checks");
    }
}
