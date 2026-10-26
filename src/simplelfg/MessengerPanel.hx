package simplelfg;

import imgui.ImGui;
import imgui.Structs.ImVec2;
import simplelfg.RelayChatStore.RelayPeer;

/** Explicit private messages. All network work is queued for Engine observation. */
class MessengerPanel {
    var engine:Engine;var chrome:Chrome;var compose=new TextBuffer(384);
    var peer="";var peerName="Choose a conversation";var peers:Array<RelayPeer>=[];
    var rows:Array<{meta:String,text:String}>=[];var available=new ImVec2();var historySize=new ImVec2();
    var hasSteamTag=false;
    var contactRequested=false;var contactReady=false;var contactPeer="";
    var contacts:Array<SteamContactLookup.SteamContactMatch>=[];var pendingProfile="";var pendingCopy="";
    var revision=-1;var lastPeer="";var submitted="";
    var sentRevision=0;var choices:Void->Void;var history:Void->Void;var feedback=new FeedbackTone();
    public function new(engine:Engine,chrome:Chrome){this.engine=engine;this.chrome=chrome;choices=drawChoices;history=drawHistory;}
    public function clear():Void {peer="";peerName="Choose a conversation";compose.set("");hasSteamTag=false;rows=[];contactRequested=false;contactReady=false;contactPeer="";contacts=[];pendingProfile="";pendingCopy="";}
    public function observe():Void {
        if(pendingCopy!=""){ImGui.setClipboardText(pendingCopy);pendingCopy="";}
        if(pendingProfile!=""){
            var url=pendingProfile;pendingProfile="";
            if(contactPeer==peer&&engine.state.available)for(contact in contacts)if(contact.profile==url&&SteamContactLookup.profileFor(contact.value)==url){hxd.System.openURL(url);break;}
        }
        if(sentRevision!=engine.relaySentRevision){sentRevision=engine.relaySentRevision;if(compose.get()==submitted){compose.set("");hasSteamTag=false;}}
        if(engine.requestedRelayPeer!=""){
            peer=engine.requestedRelayPeer;peerName=engine.requestedRelayName;engine.requestedRelayPeer="";
        }
        if(contactPeer!=peer){contactRequested=false;contactReady=false;contacts=[];contactPeer=peer;}
        if(contactRequested){contactRequested=false;contacts=engine.relayMessages.contactsFor(peer);contactReady=true;}
        feedback.observe(engine.whisperFeedback);
        if(revision==engine.relayMessages.revision&&lastPeer==peer)return;
        revision=engine.relayMessages.revision;lastPeer=peer;
        peers=engine.relayMessages.peers();
        rows=[for(line in engine.relayMessages.conversation(peer)){meta:(line.outgoing?"You":line.name)+" | "+Date.fromTime(line.time*1000).toString(),text:line.text}];
    }
    public function draw():Void {
        chrome.header("Cross-server messages");chrome.note(engine.relayStatus);
        chrome.note("Private session inbox. Names and Steam codes are self-reported. Messages clear on logout.");
        ImGui.setNextItemWidth(-1);Scope.combo("##relayConversation",peerName,choices);
        ImGui.getContentRegionAvail(available);historySize.x=0;historySize.y=Math.max(80,available.y-190*engine.config.textScale);
        Scope.child("##relayHistory",historySize,history);
        if(engine.testRelayPeer!=""&&chrome.button("Message test responder##testPeer")){peer=engine.testRelayPeer;peerName="SimpleLFG Test";}
        if(peer==""){chrome.note("Choose Message on a cross-server listing, or select an incoming conversation.");return;}
        drawContact();
        ImGui.setNextItemWidth(-1);if(ImGui.inputTextWithHint("##relayCompose","Write a private message",compose.bytes,compose.size))hasSteamTag=SteamContact.hasTag(compose.get());
        if(chrome.disabledButton("Send message##relaySend",engine.relay.sessionId==""||engine.relayMessagePending,true)){
            submitted=compose.get();
            engine.enqueue({kind:"message",sessionId:engine.state.id,text:compose.get(),channel:"Relay",targetId:peer,targetName:peerName,listingKey:""});
        }
        if(SteamContact.valid(engine.config.steamId)){
            ImGui.sameLine();if(chrome.button("Share Steam code##relayShare")){compose.set(SteamContact.attach(compose.get(),engine.config.steamId,240));hasSteamTag=SteamContact.hasTag(compose.get());}
        }
        if(hasSteamTag&&chrome.button("Remove Steam ID##removeSteamMessage")){compose.set(SteamContact.detach(compose.get()));hasSteamTag=false;}
        chrome.status(feedback.text,feedback.kind);
    }
    function drawContact():Void {
        if(chrome.button("Steam contact##relayContact")){contactPeer=peer;contactRequested=true;}
        if(ImGui.beginPopupContextItem("##relayContactMenu")){
            var error:Dynamic=null;
            try {
                if(Scope.cancelPopups)ImGui.closeCurrentPopup();
                else if(ImGui.menuItem("Detect and review contact")){contactPeer=peer;contactRequested=true;}
            }catch(e:Dynamic)error=e;
            ImGui.endPopup();if(error!=null)throw error;
        }
        if(contactReady){contactReady=false;ImGui.openPopup("##relayContactReview");}
        if(ImGui.beginPopup("##relayContactReview")){
            var error:Dynamic=null;
            try {
                if(Scope.cancelPopups||contactPeer!=peer)ImGui.closeCurrentPopup();
                else {
                    chrome.note("Self-reported contact from this person. Check it before adding.");
                    if(contacts.length==0)chrome.note("No supported Steam contact found. Ask them to share their code.");
                    for(contact in contacts){
                        if(ImGui.menuItem(contact.label))pendingProfile=contact.profile;
                        if(ImGui.menuItem(contact.copyLabel))pendingCopy=contact.value;
                    }
                }
            }catch(e:Dynamic)error=e;
            ImGui.endPopup();if(error!=null)throw error;
        }
    }
    function drawChoices():Void {
        for(p in peers)if(ImGui.selectable(p.name+"##conversation_"+p.id,p.id==peer)){peer=p.id;peerName=p.name;}
    }
    function drawHistory():Void {for(row in rows){chrome.note(row.meta);Scope.wrapped(row.text);chrome.gap(8);}}
}
