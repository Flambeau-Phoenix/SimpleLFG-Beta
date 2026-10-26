import simplelfg.Config;
import simplelfg.Engine;
import simplelfg.KeyBinding;
import simplelfg.Parser;
import simplelfg.SocialService;
import simplelfg.SortPolicy;
import simplelfg.TargetDefaults;
import simplelfg.Types.Listing;
import NetworkTest.MockRelay;
import TestMain.FakeChat;
import simplelfg.CrossServerRelay;

class PartySocial implements GameSocialAdapter {
    public var reads=0;public var actions:Array<String>=[];public var members=2;
    public function new(){}
    public function socialSnapshot(includePeople:Bool):SocialSnapshot {
        reads++;var party=SocialService.emptyParty();
        for(i in 0...members)party.members.push({uid:"u"+i,name:"P"+i,leader:i==0,self:i==1});
        party.canLeave=members>1;party.canInvite=members<4;
        return {code:"ABCD-EFGH-JKLM",people:[],available:true,party:party};
    }
    public function socialAction(kind:String,uid:String,code:String):Null<String> {actions.push(kind);return null;}
}
/** Shell-level behaviour: panel key, board sorting, party state and the social action path. */
class ShellTest {
    static var checks=0;
    static function ok(value:Bool,label:String):Void {checks++;if(!value)throw label;}
    static function listing(key:String,seen:Float,target:String,player:String):Listing {
        var l=new Listing();l.key=key;l.seen=seen;l.target=target;l.senderName=player;l.kind="LFM";l.composition="1/4";l.text="msg";return l;
    }
    static function main():Void {
        ok(KeyBinding.valid("F5",0)&&KeyBinding.valid("Insert",0)&&KeyBinding.valid("Keypad3",0),"function, navigation and keypad keys need no modifier");
        ok(!KeyBinding.valid("A",0)&&!KeyBinding.valid("5",0)&&!KeyBinding.valid("GraveAccent",0),"typing keys require a modifier");
        ok(KeyBinding.valid("A",KeyBinding.CTRL)&&KeyBinding.valid("F9",KeyBinding.CTRL|KeyBinding.ALT),"modified chords accepted");
        ok(!KeyBinding.valid("Bogus",0)&&!KeyBinding.valid("F5",8)&&!KeyBinding.valid("F5",-1),"unknown keys and modifier bits rejected");
        ok(KeyBinding.label("F5",0)=="F5"&&KeyBinding.label("A",3)=="Ctrl+Shift+A"&&KeyBinding.label("Keypad3",0)=="Numpad 3","readable labels");
        ok(KeyBinding.code("F1")==572&&KeyBinding.code("F12")==583&&KeyBinding.code("A")==546&&KeyBinding.code("Z")==571&&KeyBinding.code("0")==536,"named-key ids follow Dear ImGui");
        ok(KeyBinding.clean("Bogus",0).name=="F5"&&KeyBinding.clean("A",0).name=="F5"&&KeyBinding.clean("A",1).name=="A","invalid bindings fall back to F5");
        ok(KeyBinding.knownOwner("F6",0)!=""&&KeyBinding.knownOwner("F5",0)==""&&KeyBinding.knownOwner("F6",1)=="","known neighbours are only warned about when unmodified");

        var c=new Config();ok(c.panelKey=="F5"&&c.panelMods==0&&!c.quickLeaveChip,"defaults keep F5 and no quick-leave chip");
        c.panelKey="F9";c.panelMods=KeyBinding.CTRL;c.quickLeaveChip=true;
        var back=Config.decode(c.encode());ok(back.panelKey=="F9"&&back.panelMods==1&&back.quickLeaveChip,"panel key round trips");
        ok(Config.decode('{"panelKey":"Nope","panelMods":0}').panelKey=="F5"&&Config.decode('{"panelKey":"Q","panelMods":0}').panelKey=="F5","corrupt or unsafe panel keys recover to F5");
        ok(Config.decode('{"panelKey":"Q","panelMods":2}').panelKey=="Q"&&Config.decode('{"hotkey":9}').panelKey=="F5","legacy numeric hotkey cannot change the key");

        var fit=simplelfg.Geometry.designFit(1000,1920,1080,520,360);
        ok(fit.w==1000&&Math.abs(fit.w/fit.h-1180/768)<0.01,"fit keeps width and restores the design shape");
        fit=simplelfg.Geometry.designFit(2000,1920,800,520,360);ok(fit.h==800&&fit.w<=1920&&Math.abs(fit.w/fit.h-1180/768)<0.01,"fit shrinks width when the screen is short");
        fit=simplelfg.Geometry.designFit(300,1920,1080,520,360);ok(fit.w>=520&&fit.h>=360,"fit respects the window minimums");
        var lc=new Config();ok(lc.launcherX==-1&&lc.launcherY==-1&&!lc.launcherLocked&&!lc.launcherTransparent,"launcher defaults: default spot, unlocked, opaque");
        lc.launcherX=0.25;lc.launcherY=0.5;lc.launcherLocked=true;lc.launcherTransparent=true;
        var lb=Config.decode(lc.encode());ok(lb.launcherX==0.25&&lb.launcherY==0.5&&lb.launcherLocked&&lb.launcherTransparent,"launcher placement and chrome toggles round trip");
        var half=Config.decode('{"launcherX":0.4}');ok(half.launcherX==-1&&half.launcherY==-1,"a half-saved position falls back to the default spot");
        var wild=Config.decode('{"launcherX":9,"launcherY":-3}');ok(wild.launcherX==-1&&wild.launcherY==-1,"out-of-range positions are discarded");
        ok(Config.decode('{"steamId":"Cross-server posts are public. S"}').steamId==""&&Config.decode('{"steamId":"12345"}').steamId=="12345","a corrupt saved Steam ID heals on load; a numeric one is kept");
        var badConfig=new Config();badConfig.steamId="Cross-server posts are public. S";
        var relayChat=new FakeChat();var relayWire=new MockRelay();var relayClient=new CrossServerRelay(relayWire);
        var relayEngine=new Engine(badConfig,relayChat,new Parser(TargetDefaults.activities()),relayClient);relayEngine.relayVisible=true;
        relayEngine.tick(100);relayWire.finish(relayClient.generation,"capabilities",'{"features":["social-v1"]}');relayEngine.tick(101);
        var sessions=relayWire.requests.filter(r->r.kind=="session");
        ok(sessions.length==1&&haxe.Json.parse(sessions[0].body).steam_id=="","a malformed Steam ID never blocks the messaging session and is not sent");
        ok(new Config().showLogo&&!Config.decode('{"showLogo":false}').showLogo&&Config.decode(Config.decode('{"showLogo":false}').encode()).showLogo==false,"wordmark is on by default and the View menu choice round trips");
        var older=listing("a",100,"Zed","Bo");var newer=listing("b",200,"Abe","Cy");
        ok(SortPolicy.board(newer,older,"age",true)<0&&SortPolicy.board(newer,older,"age",false)>0,"newest first when age ascends");
        ok(SortPolicy.board(newer,older,"target",true)<0&&SortPolicy.board(older,newer,"player",true)<0,"named column sorting");
        var twin=listing("c",200,"Abe","Cy");ok(SortPolicy.board(newer,twin,"target",true)==-SortPolicy.board(twin,newer,"target",true)&&SortPolicy.board(newer,twin,"target",true)!=0,"equal rows order by identity, never flicker");

        var fake=new PartySocial();var social=new SocialService(fake);var cfg=new Config();
        social.observe(cfg,"a|h","u1",true,1);social.observe(cfg,"a|h","u1",true,2);
        ok(fake.reads==1&&social.party.members.length==2&&social.inParty(),"hidden window refreshes party at the slow rate");
        social.open=true;social.observe(cfg,"a|h","u1",true,6);social.observe(cfg,"a|h","u1",true,6.4);social.observe(cfg,"a|h","u1",true,7.1);
        ok(fake.reads==3,"open window refreshes party once a second");
        ok(social.party.leader==false&&social.party.canInvite&&social.party.capacity==4,"party permissions come from the snapshot");
        social.observe(cfg,"b|h","u9",true,8);ok(fake.reads==4&&social.party.members.length==2,"new session re-reads rather than reusing the old roster");
        social.observe(cfg,"b|h","u9",false,9);ok(social.party.members.length==0&&!social.inParty(),"unavailable game clears the roster");

        var chat=new FakeChat();var transport=new MockRelay();var relay=new CrossServerRelay(transport);
        var party=new PartySocial();var e=new Engine(new Config(),chat,new Parser(TargetDefaults.activities()),relay);e.social=new SocialService(party);
        e.tick(100);var serial=e.feedbackSerial;e.report("whisper","Template saved.",100);
        ok(e.feedbackSerial==serial+1&&e.feedbackText=="Template saved.","every result raises a fresh toast serial");
        e.enqueue(e.socialAction("addFriend","u5","Pal"));e.enqueue(e.socialAction("leaveParty"));e.tick(101);
        ok(party.actions.length==2&&party.actions[1]=="leaveParty","leaving a party is never delayed by the friend-request throttle");
        e.enqueue(e.socialAction("invite","u6","Pal"));e.tick(101.5);
        ok(party.actions.length==2,"other social verbs stay throttled");
        e.enqueue(e.socialAction("removeFriend","u5","Pal"));e.tick(104);
        ok(party.actions[party.actions.length-1]=="removeFriend","removing a friend uses the same guarded path");
        chat.current.cursorFree=false;e.enqueue(e.socialAction("leaveParty"));e.tick(106);
        ok(party.actions.length==3,"camera mode cancels a queued leave");
        Sys.println("PASS "+checks+" panel key, board sort, party state and social action checks");
    }
}
