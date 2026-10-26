package simplelfg;

import simplelfg.Types;
import hlx.runtime.PatchTargetKey;

typedef NativeMessage = {
    var args:Dynamic;
    var channel:st.Channel;
    var localStamp:Null<Float>;
    var localTextId:String;
    var notify:String;
    var sender:{name:String,uid:String};
    var text:String;
}

/** Build-specific game calls live here. UI and configuration retain only primitives. */
class NativeChat implements GameChatAdapter {
    static var active:NativeChat;
    static final key=new PatchTargetKey("st.player.ChatClient","localReceiveMessage");
    public var board:Board;
    public var receiveCount(default,null):Int=0;
    public var failureCount(default,null):Int=0;
    public var screenWidth(default,null):Float=1920;
    public var screenHeight(default,null):Float=1080;
    var pendingError:Null<String>=null;
    public var generation(default,null):Int=0;
    var lastIdentity:String="";
    var lastAvailable:Bool=false;
    var cachedUid:String="";
    var heroHigh:Int=0;
    var heroLow:Int=0;
    var cachedIdentity:String="";
    var snapshot:Session={id:"",playerId:"",cursorFree:false,available:false};
    public function new() {}
    public function install():Void {
        active=this;
        // Register only after ModEntry verifies the actual game's build fingerprint.
        // Receiver has native N slots; contributor has N+1 with trailing result:Void.
        HlxRuntime.registerPostfix(key,afterReceive,receiver);
    }
    static function receiver(client:st.player.ChatClient,message:NativeMessage):Void {
        HlxRuntime.dispatch(key,[client,message]);
    }
    static function afterReceive(client:st.player.ChatClient,message:NativeMessage,result:Void):Void {
        if(active==null || active.board==null || message==null || message.text==null || message.sender==null) return;
        try {
            var app=GameApp.get();
            if(app==null || app.me==null || app.me.chatClient!=client) return;
            if(message.text.length>512 || message.sender.uid==null || message.sender.uid.length>128) return;
            var channel=message.channel;
            if(channel==null) return;
            var kind=channel.getConstructorName();
            if(!ChannelPolicy.known(kind)) return;
            active.board.enqueue({senderId:message.sender.uid,senderName:message.sender.name,
                channel:kind,text:message.text,receivedAt:Sys.time()});
            active.receiveCount++;
        } catch(_:Dynamic) {active.failureCount++;}
    }
    public function session():Session {
        snapshot.id="";snapshot.playerId="";snapshot.playerName="";snapshot.available=false;snapshot.cursorFree=false;
        try {
            var window=hxd.Window.getInstance();if(window!=null){screenWidth=window.get_width();screenHeight=window.get_height();}
            var app=GameApp.get();
            if(app!=null && app.me!=null) {
                snapshot.playerId=app.me.uid;snapshot.playerName=Config.clean(app.me.getName(),80);
                var info=app.connectionInfo;
                if(info!=null && snapshot.playerId!=null && snapshot.playerId!="") {
                    var id=info.heroID;
                    if(cachedUid!=snapshot.playerId || cachedIdentity=="" || heroHigh!=id.high || heroLow!=id.low) {
                        cachedUid=snapshot.playerId;heroHigh=id.high;heroLow=id.low;
                        cachedIdentity=cachedUid+"|"+haxe.Int64.toStr(id);
                    }
                    snapshot.id=cachedIdentity;
                    snapshot.available=app.me.chatClient!=null && !app.get_isLoading() && !app.isInCutscene();
                    snapshot.cursorFree=snapshot.available && app.isCursorFree();
                }
            }
        } catch(_:Dynamic) {}
        if(snapshot.id!=lastIdentity || snapshot.available!=lastAvailable) {
            generation++;pendingError=null;lastIdentity=snapshot.id;lastAvailable=snapshot.available;
        }
        return snapshot;
    }
    public function takeError():Null<String> {var e=pendingError;pendingError=null;return e;}
    public function send(text:String,channel:String,targetId:String,targetName:String):Null<String> {
        try {
            var app=GameApp.get();
            if(app==null || app.me==null || app.get_isLoading() || app.isInCutscene() || !app.isCursorFree()) return "Chat is unavailable in the current game state.";
            var me=app.me;
            var ch:st.Channel;
            if(channel=="Player") {
                if(targetId==null || targetId=="" || targetId==me.uid) return "Invalid whisper recipient.";
                if(me.whispers==null) return "Whisper service unavailable.";
                ch=st.Channel.Player(targetId,targetName);
            } else if(channel=="Local") {
                var hero=app.hero;
                if(hero==null) return "Local chat is unavailable while your character is loading.";
                var p=hero.position;
                if(p==null) return "Your character position is unavailable.";
                ch=st.Channel.Local({x:p.x,y:p.y,z:p.z});
            } else if(channel=="All") ch=st.Channel.All;
            else return "Unsupported chat channel.";
            var message:NativeMessage={args:null,channel:ch,localStamp:null,localTextId:null,notify:null,
                sender:{uid:me.uid,name:me.getName()},text:text};
            if(channel=="Player") {
                var sessionId=snapshot.id;
                var sessionGeneration=generation;
                me.whispers.sendMessage(targetId,st.player.Message.ChatMessage(message),function(ok:Bool) {
                    // A late response from an old character must not update the new session.
                    if(generation==sessionGeneration && snapshot.id==sessionId && !ok) pendingError="Whisper failed: the recipient may be offline or unavailable.";
                });
                me.chatClient.localReceiveMessage(message);
            } else me.chatClient.sendMessage(message);
            return null;
        } catch(_:Dynamic) {failureCount++;return "The game could not submit this message.";}
    }
}
