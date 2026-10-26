package simplelfg;

import imgui.ImGui;
import imgui.Structs.ImVec2;
import simplelfg.RelayChatStore.RelayPeer;
import simplelfg.ui.DataTable;
import simplelfg.ui.ThemePalette;

/** Explicit private messages. All network work is queued for Engine observation. */
class MessengerPanel {
    var engine:Engine;var chrome:Chrome;var compose=new TextBuffer(1024);var workspace:Workspace;var compact=false;
    var peer="";var peerName="Choose a conversation";var peers:Array<RelayPeer>=[];
    var rows:Array<{id:Int,menu:String,meta:String,text:String,outgoing:Bool,deleted:Bool}>=[];var available=new ImVec2();var historySize=new ImVec2();
    var deleteId=0;var deletePeer="";
    var hasSteamTag=false;
    var contactRequested=false;var contactReady=false;var contactPeer="";
    var contacts:Array<SteamContactLookup.SteamContactMatch>=[];var pendingProfile="";var pendingCopy="";
    var revision=-1;var lastPeer="";var submitted="";
    var sentRevision=0;var choices:Void->Void;var history:Void->Void;var feedback=new FeedbackTone();
    var convRows:Array<{id:String,name:String,last:String,age:String}>=[];var table:DataTable;var now:Float=0;
    public function new(engine:Engine,chrome:Chrome){this.engine=engine;this.chrome=chrome;choices=drawChoices;history=drawHistory;workspace=new Workspace(chrome,"##Messages",drawInbox,drawConversation,300,520);
        table=new DataTable("##conversationTable",[{label:"Conversation",width:2,fixed:false,sortable:false},{label:"Last message",width:3,fixed:false,sortable:false},{label:"Age",width:54,fixed:true,sortable:false}],30,convId,convCell,convSelected,convPick);}
    function convId(i:Int):String return "##conv_"+convRows[i].id;
    function convSelected(i:Int):Bool return convRows[i].id==peer;
    function convPick(i:Int):Void {if(i<0||i>=convRows.length)return;peer=convRows[i].id;peerName=convRows[i].name;}
    function convCell(i:Int,column:Int):Void {var r=convRows[i];if(column==0)ImGui.textUnformatted(r.name);else if(column==1)ImGui.textDisabled(r.last);else ImGui.textUnformatted(r.age);}
    public function clear():Void {peer="";peerName="Choose a conversation";compose.set("");hasSteamTag=false;rows=[];revision=-1;lastPeer="";deleteId=0;deletePeer="";contactRequested=false;contactReady=false;contactPeer="";contacts=[];pendingProfile="";pendingCopy="";}
    static function ageText(seconds:Float):String {var n=Std.int(Math.max(0,seconds));return n<60?n+"s":Std.int(n/60)+"m";}
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
        if(contactPeer!=peer){contactRequested=false;contactReady=false;contacts=[];contactPeer=peer;deleteId=0;}
        if(contactRequested){contactRequested=false;contacts=engine.relayMessages.contactsFor(peer);contactReady=true;}
        feedback.observe(engine.whisperFeedback);
        if(revision==engine.relayMessages.revision&&lastPeer==peer)return;
        revision=engine.relayMessages.revision;lastPeer=peer;
        peers=engine.relayMessages.peers();
        convRows=[for(p in peers){var lines=engine.relayMessages.conversation(p.id);var last=lines.length>0?lines[lines.length-1]:null;{id:p.id,name:p.name,last:last==null?"":(last.outgoing?"You: ":"")+StringTools.replace(last.text,"
"," "),age:last==null?"":ageText(Sys.time()-last.time)}}];
        rows=[for(line in engine.relayMessages.conversation(peer)){id:line.id,menu:"##message_"+line.id,meta:(line.outgoing?"You":line.name)+" | "+Date.fromTime(line.time*1000).toString(),text:line.text,outgoing:line.outgoing,deleted:line.deleted==true}];
    }
    public function draw():Void {
        ImGui.getContentRegionAvail(available);compact=available.x<780*engine.config.textScale;
        if(compact){ImGui.setNextItemWidth(-1);Scope.combo("##compactConversation",peerName,choices);drawConversation();}
        else workspace.draw(engine.config.textScale);
    }
    function drawInbox():Void {
        chrome.header("Conversations");chrome.note(engine.relayStatus,false);
        if(engine.testRelayPeer!=""&&chrome.button("Message test responder###testPeer")){peer=engine.testRelayPeer;peerName="SimpleLFG Test";}
        ImGui.getContentRegionAvail(available);
        table.rowHeight=Math.max(28,30*engine.config.textScale);
        table.draw(available.x,Math.max(80,available.y-(peer==""?0:96*engine.config.textScale)),convRows.length,"No conversations yet. Choose Message on a cross-server listing to start one. Names and Steam codes are self-reported; messages clear on logout.");
        if(peer=="")return;
        chrome.gap(4);drawContact();
    }
    function drawConversation():Void {
        chrome.header(peerName);
        if(peer==""){chrome.empty("Choose Message on a listing, or select an incoming conversation.");return;}
        ImGui.getContentRegionAvail(available);historySize.x=0;historySize.y=Math.max(60,available.y-250*engine.config.textScale-(deleteId>0?80*engine.config.textScale:0));
        Scope.child("##relayHistory",historySize,history);
        if(compact)drawContact();
        ImGui.setNextItemWidth(-1);if(UiText.input("##relayCompose","Write a private message",compose,true))hasSteamTag=SteamContact.hasTag(compose.get());
        var scale=engine.config.textScale;
        if(chrome.disabledButton("Send message###relaySend",engine.relay.sessionId==""||engine.relayMessagePending,true,130*scale)){
            submitted=compose.get();
            engine.enqueue({kind:"message",sessionId:engine.state.id,text:compose.get(),channel:"Relay",targetId:peer,targetName:peerName,listingKey:""});
        }
        ImGui.sameLine(0,6);if(chrome.disabledButton("Farever code###shareFareverMessage",engine.social.code=="",false,120*scale))compose.set(FareverContact.attach(compose.get(),engine.social.code));
        if(SteamContact.valid(engine.config.steamId)){
            ImGui.sameLine(0,6);if(chrome.button("Steam code###relayShare",false,110*scale)){compose.set(SteamContact.attach(compose.get(),engine.config.steamId,240));hasSteamTag=SteamContact.hasTag(compose.get());}
        }
        if(hasSteamTag){ImGui.sameLine(0,6);if(chrome.button("Remove Steam###removeSteamMessage",false,120*scale)){compose.set(SteamContact.detach(compose.get()));hasSteamTag=false;}}
        if(FareverContact.extract(compose.get())!=""){ImGui.sameLine(0,6);if(chrome.button("Remove Farever###removeFareverMessage",false,130*scale))compose.set(FareverContact.withoutTags(compose.get()));}
        if(deleteId>0&&deletePeer==peer){
            chrome.note("Delete this message for both participants? Previously read text cannot be recalled.");
            if(chrome.disabledButton("Confirm deletion##confirmDeleteMessage",engine.deletePending)){
                engine.enqueue(engine.action("deleteMessage",Std.string(deleteId)));deleteId=0;
            }
            ImGui.sameLine();if(chrome.button("Cancel##cancelMessageDelete"))deleteId=0;
        }
    }
    function drawContact():Void {
        if(chrome.button("Steam contact##relayContact")){contactPeer=peer;contactRequested=true;}
        ContextMenuSystem.openForItem("##relayContactMenu");if(ImGui.beginPopup("##relayContactMenu")){
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
    function drawHistory():Void {
        for(row in rows){
            ImGui.pushID_Int(row.id);var error:Dynamic=null;
            try {
                ImGui.beginGroup();var groupError:Dynamic=null;
                try {
                    if(row.outgoing)ImGui.indent(48);
                    ImGui.textColored(row.outgoing?ThemePalette.current().accent:ThemePalette.current().textDisabled,row.meta);Scope.wrapped(row.text,false);
                    if(row.outgoing)ImGui.unindent(48);
                }catch(e:Dynamic)groupError=e;
                ImGui.endGroup();if(groupError!=null)throw groupError;
                ContextMenuSystem.openForItem(row.menu);
                if(ImGui.beginPopup(row.menu)){var inner:Dynamic=null;
                    try {if(Scope.cancelPopups)ImGui.closeCurrentPopup();else {
                        if(ImGui.menuItem("Copy message"))UiActionQueue.copy(row.text);
                        if(ImGui.menuItem("Delete for both...",null,false,row.outgoing&&!row.deleted&&engine.relay.socialSupported)){deleteId=row.id;deletePeer=peer;}
                        var code=FareverContact.extract(row.text);
                        if(code!=""&&!row.outgoing){
                            if(ImGui.menuItem("Copy Farever code"))UiActionQueue.copy(code);
                            if(ImGui.menuItem("Add Farever friend"))engine.enqueue(engine.action("addCode",code));
                        }
                    }}catch(e:Dynamic)inner=e;
                    ImGui.endPopup();if(inner!=null)throw inner;
                }
                chrome.gap(8);
            }catch(e:Dynamic)error=e;
            ImGui.popID();if(error!=null)throw error;
        }
    }
}
