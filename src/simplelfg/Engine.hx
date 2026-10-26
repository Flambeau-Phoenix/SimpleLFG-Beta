package simplelfg;

import simplelfg.Types;

class Engine {
    public var config:Config;
    public var board:Board;
    public var alerts:Alerts=new Alerts();
    public var state(default,null):Session={id:"",playerId:"",cursorFree:false,available:false};
    public var status:String="Waiting for chat integration.";
    public var postFeedback(default,null):String="";
    public var whisperFeedback(default,null):String="";
    public var postFeedbackUntil(default,null):Float=0;
    public var whisperFeedbackUntil(default,null):Float=0;
    public var cooldown(default,null):Int=0;
    public var reminderReady(default,null):Bool=false;
    public var sessionChanged(default,null):Bool=false;
    public var preview(default,null):String="";
    public var dirtyAt:Float=-1;
    public var settingsRevision(default,null):Int=0;
    public var relay:CrossServerRelay;
    public var relayStatus(default,null):String="Cross-server listings disabled.";
    public var relayPostPending(default,null):Bool=false;
    public var relayPostError(default,null):String="";
    public var relayMessages=new RelayChatStore();
    public var relayMessagePending(default,null)=false;
    public var relaySentRevision(default,null)=0;
    public var testRelayPeer(default,null):String="";
    public var requestedRelayPeer="";public var requestedRelayName="";
    var sessionPending=false;var inboxPending=false;var nextSession:Float=0;var nextInbox:Float=0;var inboxCursor=0;
    public var relayVisible:Bool=true;
    var lastRelayHost:String=null;var lastRelaySteam:String=null;var nextRelayService:Float=0;var lastRelaySettings:Int=-1;var relayMaintenanceSecond:Int=-1;
    var lastRelayVisible=true;var listingsDirty=true;var inboxDirty=true;
    var streamPending=false;var streamConnected=false;var nextStream:Float=0;var streamFailures=0;
    var relayIdentity="";var pendingPeerName="";var privacyApplied:Null<Bool>=null;var privacyPending=false;var nextPrivacy:Float=0;
    var relayActive=false;var relayPollPending=false;var nextRelayPoll:Float=0;
    var actions:Array<UiAction>=[];
    var adapter:GameChatAdapter;
    var nextPost:Float=0;
    var nextWhisper:Float=0;
    var reminderDue:Float=0;
    var maintenanceSecond:Int=-1;
    var previewRevision:Int=-1;
    var parserRevision:Int=-1;
    public function new(config:Config,adapter:GameChatAdapter,parser:Parser,?relay:CrossServerRelay) {
        this.config=config;this.adapter=adapter;this.relay=relay==null?new CrossServerRelay():relay;board=new Board(parser);preview=Parser.preview(config.draft);
    }
    public function markDirty(now:Float):Void {dirtyAt=now;settingsRevision++;}
    public function previewCurrent():Bool return previewRevision==settingsRevision;
    public function report(scope:String,text:String,now:Float):Void {
        status=text;
        if(scope=="post"){postFeedback=text;postFeedbackUntil=now+10;}
        if(scope=="whisper"){whisperFeedback=text;whisperFeedbackUntil=now+10;}
    }
    public function enqueue(a:UiAction):Bool {
        if(actions.length>=16) {report(a.kind,"Too many pending actions.",Sys.time());return false;}
        actions.push(a);return true;
    }
    public function action(kind:String,text:String="",channel:String="All",target:Listing=null):UiAction {
        return {kind:kind,sessionId:state.id,text:text,channel:channel,targetId:target==null?"":target.senderId,
            targetName:target==null?"":target.senderName,listingKey:target==null?"":target.key};
    }
    public function tick(now:Float):Void {
        var s=adapter.session();
        sessionChanged=s.id!=state.id;
        if(sessionChanged) {
            previewRevision=-1;resetRelay();board.clear();alerts.reset();actions.resize(0);nextPost=0;nextWhisper=0;reminderDue=0;reminderReady=false;
            postFeedback="";whisperFeedback="";
            status=s.available?"Listening for recruiting messages.":"Chat integration unavailable.";
        }
        if(s.playerName!=state.playerName)previewRevision=-1;
        state.id=s.id;state.playerId=s.playerId;state.available=s.available;state.cursorFree=s.cursorFree;state.playerName=s.playerName;
        if(!s.available) {actions.resize(0);reminderDue=0;reminderReady=false;alerts.reset();}
        if(parserRevision!=settingsRevision){board.prepare(config);parserRevision=settingsRevision;}
        board.update(config,now);
        serviceRelay(now);
        if(previewRevision!=settingsRevision) {
            relayPostError=config.draft.channel=="Relay"?RelayProtocol.postError(config,config.draft,state.playerName):"";
            preview=config.draft.channel=="Relay"?RelayProtocol.preview(config,config.draft,state.playerName):Parser.preview(config.draft);previewRevision=settingsRevision;
        }
        var second=Std.int(now);
        if(second!=maintenanceSecond) {
            maintenanceSecond=second;
            var old=config.ignored.length;
            config.ignored=[for(r in config.ignored) if(r.until==0 || r.until>now) r];
            if(old!=config.ignored.length) markDirty(now);
        }
        cooldown=Std.int(Math.ceil(Math.max(0,nextPost-now)));
        if(!config.reminder) {reminderDue=0;reminderReady=false;}
        if(reminderDue>0 && now>=reminderDue) {reminderDue=0;reminderReady=true;status="Repost reminder: your post is ready. Posting is manual.";}
        while(actions.length>0) {
            var a=actions.shift();
            if(a.sessionId!=s.id || s.id=="" || !s.available || !s.cursorFree) {report(a.kind,"Action cancelled: session or cursor mode changed.",now);continue;}
            if(a.kind=="post") {
                if(now<nextPost) {report("post","Please wait before posting again.",now);continue;}
                if(config.draft.activity=="") {report("post","Enter an activity before posting.",now);continue;}
                var msg=Config.clean(a.text,512);
                if(msg=="" || a.text.length>512) {report("post","Message is empty or too long.",now);continue;}
                if(a.channel=="Relay"){
                    if(relay.sessionId==""){report("post","Messaging session is connecting. Try again shortly; Steam contact details are optional.",now);continue;}
                    var error=RelayProtocol.postError(config,config.draft,state.playerName);
                    if(error!=""){report("post",error,now);continue;}
                    if(!previewCurrent()||a.text!=preview){report("post","Review the updated cross-server preview before posting.",now);continue;}
                    if(relayPostPending){report("post","A cross-server post is already pending.",now);continue;}
                    if(!relay.post(RelayProtocol.body(config,config.draft,state.playerName))){report("post","Relay queue is busy. Try again shortly.",now);continue;}
                    relayPostPending=true;report("post","Publishing cross-server listing...",now);continue;
                }
                var err=adapter.send(msg,a.channel,"","");
                if(err!=null) {report("post",err,now);continue;}
                nextPost=now+60;cooldown=60;reminderReady=false;reminderDue=config.reminder?nextPost:0;
                report("post","Post submitted to game chat; delivery is not confirmed.",now);
            } else if(a.kind=="whisper") {
                if(!board.contains(a.listingKey)) {report("whisper","Listing expired or was hidden. Select a current listing.",now);continue;}
                if(a.targetId=="" || a.targetId==s.playerId) {report("whisper","Choose another player.",now);continue;}
                if(a.text.length>240) {report("whisper","Whispers must be 240 characters or fewer.",now);continue;}
                var msg=Config.clean(a.text,240);
                if(msg=="") {report("whisper","Enter a whisper first.",now);continue;}
                if(now<nextWhisper) {report("whisper","Please wait before sending another whisper.",now);continue;}
                if(StringTools.startsWith(a.targetId,"relay_")){
                    var listing:Listing=null;for(row in board.entries)if(row.key==a.listingKey)listing=row;
                    if(listing==null||listing.relaySessionId==""||listing.isOwn){report("whisper","This host is not available for private messages.",now);continue;}
                    requestedRelayPeer=listing.relaySessionId;requestedRelayName=listing.senderName;continue;
                }
                var err=adapter.send(msg,"Player",a.targetId,a.targetName);
                if(err!=null) {report("whisper",err,now);continue;}
                nextWhisper=now+2;report("whisper","Whisper submitted to game chat; delivery is not confirmed.",now);

            } else if(a.kind=="message") {
                var msg=Config.clean(a.text,240);
                if(msg==""||a.text.length>240){report("whisper","Enter a message of 1-240 characters.",now);continue;}
                if(now<nextWhisper||relayMessagePending){report("whisper","Please wait before sending again.",now);continue;}
                if(!~/^[0-9a-f]{32}$/.match(a.targetId)||a.targetId==relay.sessionId||!relay.send(a.targetId,msg)){report("whisper","Private messaging is not connected yet.",now);continue;}
                relayMessagePending=true;pendingPeerName=a.targetName;nextWhisper=now+2;report("whisper","Sending private message...",now);
            } else if(a.kind=="hide") board.hide(a.listingKey);
            else if(a.kind=="ignore" || a.kind=="ignorePermanent") {
                board.ignore(a.targetId,a.targetName,config,now,a.kind=="ignorePermanent");markDirty(now);
            }
        }
        // Apply queued hides/ignores before choosing notification candidates.
        if(secondForAlerts!=Std.int(now)||alertRevision!=board.revision||alertSettings!=settingsRevision) {
            secondForAlerts=Std.int(now);alertRevision=board.revision;alertSettings=settingsRevision;
            if(s.available)alerts.update(board,config,s.playerId,now);
        }
    }
    function resetRelay():Void {testRelayPeer="";relay.reset();listingsDirty=true;inboxDirty=true;streamPending=false;streamConnected=false;nextStream=0;nextRelayService=0;relayActive=false;relayPollPending=false;relayPostPending=false;nextRelayPoll=0;sessionPending=false;inboxPending=false;nextSession=0;nextInbox=0;inboxCursor=0;relayMessagePending=false;relayMessages.clear();requestedRelayPeer="";relayIdentity="";privacyApplied=null;privacyPending=false;nextPrivacy=0;}
    function acceptMessage(value:Dynamic,outgoing:Bool,now:Float):Void {
        if(value==null)return;
        var id:Dynamic=Reflect.field(value,"id"),sender:Dynamic=Reflect.field(value,"sender_id"),recipient:Dynamic=Reflect.field(value,"recipient_id"),name:Dynamic=Reflect.field(value,"sender"),text:Dynamic=Reflect.field(value,"message"),stamp:Dynamic=Reflect.field(value,"timestamp");
        if(!Std.isOfType(id,Int)||!Std.isOfType(sender,String)||!Std.isOfType(recipient,String)||!Std.isOfType(name,String)||!Std.isOfType(text,String)||!(Std.isOfType(stamp,Float)||Std.isOfType(stamp,Int)))return;
        var time:Float=stamp;if(!Math.isFinite(time)||time>now+60||now-time>=1800)return;
        if((outgoing?sender:recipient)!=relay.sessionId)return;
        relayMessages.remember(id,outgoing?recipient:sender,outgoing?pendingPeerName:name,text,outgoing,time);
    }
    function serviceRelay(now:Float):Void {
        var active=config.relayEnabled&&state.available&&state.id!="";
        var identityChanged=lastRelayHost!=state.playerName||lastRelaySteam!=config.steamId;
        if(!identityChanged&&lastRelayVisible==relayVisible&&active==relayActive&&lastRelaySettings==settingsRevision&&now<nextRelayService&&!relay.hasResults())return;
        nextRelayService=now+0.25;lastRelaySettings=settingsRevision;
        if(identityChanged)resetRelay();
        lastRelayHost=state.playerName;lastRelaySteam=config.steamId;
        if(active!=relayActive){resetRelay();relayActive=active;relayStatus=active?"Connecting to public cross-server listings...":"Cross-server listings disabled.";if(!active)board.clearRemote();}
        if(!relayVisible){
            if(lastRelayVisible){
                relay.suspend();streamPending=false;streamConnected=false;sessionPending=false;inboxPending=false;relayPollPending=false;
                relayPostPending=false;relayMessagePending=false;privacyPending=false;privacyApplied=null;
            }
            lastRelayVisible=false;return;
        }
        if(!lastRelayVisible){listingsDirty=true;inboxDirty=true;nextRelayPoll=0;nextInbox=0;nextStream=0;}
        lastRelayVisible=true;
        if(Std.int(now)!=relayMaintenanceSecond){relayMaintenanceSecond=Std.int(now);relayMessages.expire(now);}
        for(result in relay.drain()){
            if(!active||result.generation!=relay.generation)continue;
            if(result.error!=""){
                relayFailures=Std.int(Math.min(6,relayFailures+1));
                if(result.status==429||result.status==503||result.status==0||result.status>=500)
                    relayRetryAt=now+Math.max(result.retryAfter==null?0:result.retryAfter,Math.min(60,Math.pow(2,relayFailures)));
            }else relayFailures=0;
            if(StringTools.startsWith(result.kind,"event_")){
                if(result.status==401||result.kind=="event_expired"){resetRelay();relayStatus="Messaging session expired; reconnecting.";return;}
                if(result.kind=="event_open"){streamPending=false;streamConnected=true;streamFailures=0;}
                else if(result.kind=="event_closed"){
                    streamPending=false;streamConnected=false;streamFailures=Std.int(Math.min(6,streamFailures+1));
                    nextStream=now+Math.max(result.retryAfter==null?0:result.retryAfter,Math.min(60,Math.pow(2,streamFailures)));relayStatus=result.error;
                }else {
                    if(result.kind=="event_listings"||result.kind=="event_sync"){listingsDirty=true;nextRelayPoll=0;}
                    if(result.kind=="event_chat"||result.kind=="event_sync"){inboxDirty=true;nextInbox=0;}
                }
                continue;
            }
            if(result.status==401){resetRelay();relayStatus="Messaging session expired; reconnecting.";return;}
            if(result.kind=="session"){
                sessionPending=false;nextSession=now+30;
                if(result.error!=""||!relay.acceptSession(result.body)){relayStatus=result.error!=""?result.error:"Messaging handshake failed.";continue;}
                relayStatus="Cross-server listings and private messages connected.";nextInbox=0;nextRelayPoll=0;
            }else if(result.kind=="privacy"){
                privacyPending=false;
                if(result.error!=""){privacyApplied=null;nextPrivacy=now+30;relayStatus="Privacy update failed; retrying. Repost before sharing a listing.";}
                else {listingsDirty=true;nextRelayPoll=0;}
            }else if(result.kind=="inbox"){
                inboxPending=false;nextInbox=inboxDirty?0:now+10;
                if(result.error!=""){inboxDirty=true;nextInbox=now+10;relayStatus=result.error;continue;}
                try {
                    var data:Dynamic=haxe.Json.parse(result.body);var messages:Dynamic=Reflect.field(data,"messages");var cursor:Dynamic=Reflect.field(data,"cursor");
                    if(Reflect.field(data,"session_id")!=relay.sessionId||!Std.isOfType(messages,Array)||!Std.isOfType(cursor,Int)||cursor<inboxCursor)throw "Invalid inbox";
                    var list:Array<Dynamic>=cast messages;if(list.length>50)throw "Inbox too large";
                    for(message in list)acceptMessage(message,false,now);inboxCursor=cursor;
                    relayStatus="Cross-server listings and private messages connected.";
                }catch(_:Dynamic){relayStatus="Invalid private inbox response.";}
            }else if(result.kind=="message"){
                relayMessagePending=false;
                if(result.error!=""){report("whisper",result.error,now);continue;}
                try {
                    var data:Dynamic=haxe.Json.parse(result.body);
                    if(Reflect.field(data,"status")!="success")throw "Missing acknowledgement";
                    acceptMessage(Reflect.field(data,"chat"),true,now);relaySentRevision++;report("whisper","Private message queued for the recipient.",now);
                }catch(_:Dynamic){report("whisper","Invalid message acknowledgement.",now);}
            }else if(result.kind=="listings"){
                relayPollPending=false;nextRelayPoll=listingsDirty?0:now+15;
                if(result.error!=""){listingsDirty=true;nextRelayPoll=now+15;relayStatus=result.error;continue;}
                try {var rows=RelayProtocol.listings(result.body,now,state.playerName,config.steamId,relay.sessionId);board.mergeRemote(rows,config,now);testRelayPeer="";for(row in rows)if(row.isTest&&!row.isOwn&&row.relaySessionId!=""){testRelayPeer=row.relaySessionId;break;}relayStatus="Cross-server listings connected.";}
                catch(_:Dynamic){relayStatus="Relay returned invalid listings; retrying in 15 seconds.";}
            }else if(result.kind=="post"){
                relayPostPending=false;
                if(result.error!=""){report("post",result.error,now);continue;}
                var valid=false;
                try {
                    var response:Dynamic=haxe.Json.parse(result.body);var listing:Dynamic=response==null?null:Reflect.field(response,"listing");
                    var id:Dynamic=listing==null?null:Reflect.field(listing,"id");
                    valid=response!=null&&Reflect.field(response,"status")=="success"&&Std.isOfType(id,String)&&id!="";
                }catch(_:Dynamic){}
                if(!valid){report("post","Relay returned an invalid post acknowledgement.",now);continue;}
                nextPost=now+60;reminderReady=false;reminderDue=config.reminder?nextPost:0;
                report("post","Cross-server listing published to the public board.",now);listingsDirty=true;nextRelayPoll=0;
            }
        }
        if(!active){relayStatus=config.relayEnabled?"Cross-server listings waiting for a character.":"Cross-server listings disabled.";return;}
        if(now<relayRetryAt)return;
        if(relay.sessionId==""&&!sessionPending&&now>=nextSession&&(config.steamId==""||SteamContact.valid(config.steamId))){
            sessionPending=relay.connect(state.playerName,config.steamId);nextSession=now+30;
        }
        if(relay.sessionId!=""&&!privacyPending&&privacyApplied!=config.shareSteamPublic&&now>=nextPrivacy){
            privacyPending=relay.privacy(config.shareSteamPublic);if(privacyPending)privacyApplied=config.shareSteamPublic;
        }
        if(relay.sessionId!=""&&!streamPending&&!streamConnected&&now>=nextStream){streamPending=relay.startEvents();nextStream=now+30;}
        if(relay.sessionId!=""&&!inboxPending&&(!streamConnected||inboxDirty)&&now>=nextInbox){inboxPending=relay.inbox(inboxCursor);if(inboxPending)inboxDirty=false;nextInbox=now+10;}
        if(!relayPollPending&&(!streamConnected||listingsDirty)&&now>=nextRelayPoll){
            relayPollPending=relay.fetchListings();if(relayPollPending)listingsDirty=false;nextRelayPoll=now+15;
            if(!relayPollPending)relayStatus="Relay queue is busy.";
        }
    }
    var secondForAlerts:Int=-1;
    var relayRetryAt:Float=0;var relayFailures=0;
    var alertRevision:Int=-1;
    var alertSettings:Int=-1;
    public function saveTemplate(now:Float):Void {
        if(config.templates.length>=5) {report("post","Five templates saved. Remove one before saving another.",now);return;}
        if(config.draft.activity=="") {report("post","Enter an activity first.",now);return;}
        config.templates.push(config.draft.copy());markDirty(now);report("post","Template saved.",now);
    }
}
