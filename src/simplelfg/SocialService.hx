package simplelfg;

typedef SocialPerson={var uid:String;var name:String;var online:Bool;var friend:Bool;var pending:Bool;var realm:Bool;var detail:String;@:optional var level:Int;}
typedef PartyMember={var uid:String;var name:String;var leader:Bool;var self:Bool;}
/** Primitive copy of the native group: members, whether you lead it, and the game's own permission answers. */
typedef PartySnapshot={var members:Array<PartyMember>;var leader:Bool;var canLeave:Bool;var canInvite:Bool;var capacity:Int;}
typedef SocialSnapshot={var code:String;var people:Array<SocialPerson>;var available:Bool;@:optional var party:PartySnapshot;}
interface GameSocialAdapter {
    public function socialSnapshot(includePeople:Bool):SocialSnapshot;
    public function socialAction(kind:String,uid:String,code:String):Null<String>;
}

/** Only sanitized primitives survive observation. No native references enter panels. */
class SocialService {
    public static inline var PARTY_CAPACITY=4;
    public var people(default,null):Array<SocialPerson>=[];
    public var gameCode(default,null)="";
    public var code(default,null)="";
    public var party(default,null):PartySnapshot=emptyParty();
    public var status="Open People to load friends and known realm players.";
    /** People scans are wanted (People page, a selected listing, the Party menu). */
    public var visible=false;
    /** Window is open: party state refreshes once a second even without a people scan. */
    public var open=false;
    public var revision(default,null)=0;
    var adapter:GameSocialAdapter;var identity="";var next:Float=0;
    var wasVisible=false;
    public function new(?adapter:GameSocialAdapter)this.adapter=adapter;
    public static function emptyParty():PartySnapshot return {members:[],leader:false,canLeave:false,canInvite:false,capacity:PARTY_CAPACITY};
    public function inParty():Bool return party.members.length>1;
    public function observe(c:Config,session:String,uid:String,available:Bool,now:Float):Void {
        if(visible&&!wasVisible)next=0;wasVisible=visible;
        if(identity!=session||!available){
            if(identity!=session||people.length>0||gameCode!=""||party.members.length>0){people=[];gameCode="";party=emptyParty();revision++;}
            identity=session;next=0;
        }
        if(available&&adapter!=null&&now>=next){
            next=now+(visible||open?1:5);
            try {
                var s=adapter.socialSnapshot(visible);gameCode=FareverContact.format(s.code);
                if(visible)people=s.people;party=s.party==null?emptyParty():s.party;
                status=s.available?"Friends and players exposed by this game instance.":"Social services are unavailable.";revision++;
            }catch(_:Dynamic){people=[];gameCode="";party=emptyParty();status="Could not read game social services.";revision++;}
        }
        code=c.fareverOwner==uid&&FareverContact.valid(c.fareverCode)?FareverContact.format(c.fareverCode):gameCode;
    }
    public function find(uid:String):SocialPerson {for(p in people)if(p.uid==uid)return p;return null;}
    public function run(kind:String,uid:String,code:String):String {
        if(adapter==null)return "Social services unavailable.";
        try {
            var error=adapter.socialAction(kind,uid,code);next=0;
            if(error!=null)return error;
            return switch(kind){
                case "invite":"Party invitation submitted; waiting for the player.";
                case "leaveParty":"Leaving the party...";
                case "removeFriend":"Friend removal submitted.";
                default:"Friend request submitted; acceptance is pending.";
            }
        }catch(_:Dynamic)return "The game could not submit this social action.";
    }
}
