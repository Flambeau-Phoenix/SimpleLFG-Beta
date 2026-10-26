package simplelfg;

import simplelfg.Types.Listing;
import imgui.ImGui;
import imgui.ImGui.ImGuiListClipper;
import imgui.Structs.ImVec2;
import simplelfg.Types.ChatEnvelope;

private class BrowseRow {
    public var listing:Listing;public var id:String;public var title:String;public var meta:String;public var excerpt:String;public var age:String;
    public function new(l:Listing,now:Float){listing=l;id="###listing_"+l.uiId;title=l.target;var age=Std.int(Math.max(0,now-l.seen));
        this.age=age<60?age+"s":Std.int(age/60)+"m";meta=(l.isRemote?(l.isOwn?"[Your public listing] | ":"[Cross-server] | "):"")+l.senderName+" | "+(l.playerClass!=""?l.playerClass+" | ":"")+this.age+" | "+(l.steamId!=""?"[Steam] | ":"");
        excerpt=l.text;
    }
}
class BrowsePanel {
    var engine:Engine;var chrome:Chrome;var layout=new BrowseLayout();var activities=new ActivityChoices();
    var search=new TextBuffer(160);var whisper=new TextBuffer(384);
    var kind:String="All";var activityId:String="all";var activityLabel:String="All activities";
    var selected:Listing=null;var composing=false;var now:Float=0;var revision=-1;var second=-1;var dirty=true;
    var rows:Array<BrowseRow>=[];var footer:String="Observed chat only - not a server directory.";
    var pendingCopy:String=null;
    var historyRows:Array<{meta:String,text:String}>=[];var historyRevision=-1;var historySender="";
    var pane=new ImVec2();var origin=new ImVec2();var sidebarPos=new ImVec2();var metaSize=new ImVec2();
    var groupsBody:Void->Void;var selectionBody:Void->Void;
    var listBody:Void->Void;var choicesBody:Void->Void;var feedback=new FeedbackTone();
    var listSize=new ImVec2();var rowSize=new ImVec2();var available=new ImVec2();
    var a=new ImVec2();var b=new ImVec2();var at=new ImVec2();var clipMin=new ImVec2();var clipMax=new ImVec2();
    var clipper:ImGuiListClipper;
    var sortColumn=2;var ascending=true;var choicesActions:Void->Void;
    public function new(engine:Engine,chrome:Chrome){this.engine=engine;this.chrome=chrome;
        groupsBody=drawGroups;selectionBody=drawSelection;
        listBody=drawList;choicesBody=drawChoices;choicesActions=drawActions;clipper=ImGui.ImGuiListClipper_ImGuiListClipper();
    }
    public function clear():Void {selected=null;composing=false;whisper.set("");historyRows=[];historySender="";dirty=true;}
    public function hasSelection():Bool return selected!=null;
    public function selectedTargets():Array<String> return selected==null?[]:selected.matchedTargetIds;
    public function observe(time:Float,visible:Bool=true):Void {
        now=time;if(pendingCopy!=null){ImGui.setClipboardText(pendingCopy);pendingCopy=null;}activities.observe();feedback.observe(engine.whisperFeedback);
        if(selected!=null){var found:Listing=null;for(l in engine.board.entries)if(l.key==selected.key&&!l.hidden&&(!engine.config.requireRecruitingContext||l.contextDetected))found=l;selected=found;if(found==null)composing=false;}
        if(selected!=null&&(historyRevision!=engine.board.history.revision||historySender!=selected.senderId||second!=Std.int(time))){
            historyRevision=engine.board.history.revision;historySender=selected.senderId;
            historyRows=[for(e in engine.board.history.forSender(selected.senderId)){meta:e.channel+" | "+Std.int(Math.max(0,time-e.receivedAt))+"s ago",text:e.text}];
        }
        if(visible&&(dirty||revision!=engine.board.revision||second!=Std.int(time))){
            dirty=false;revision=engine.board.revision;second=Std.int(time);
            rows=[for(l in engine.board.filtered(kind,activityId,search.get()))new BrowseRow(l,time)];
            rows.sort(compareRows);
            footer=rows.length+" listings";
        }
    }
    public function view(key:String):Void {
        kind="All";activityId="all";activityLabel="All activities";search.set("");selected=null;composing=false;
        for(l in engine.board.entries)if(l.key==key&&!l.hidden&&(l.isRemote?now<l.expiresAt:now-l.seen<engine.config.expirySeconds))selected=l;
        if(selected==null)engine.report("whisper","That listing expired. Browse the currently active groups.",now);
        dirty=true;
    }
    public function draw():Void {
        ImGui.getContentRegionAvail(available);ImGui.getCursorScreenPos(origin);
        var showSelection=selected!=null;
        layout.update(available.x,engine.config.textScale,showSelection);
        pane.x=layout.board;pane.y=Math.max(1,available.y);chrome.card("##Browse.board",pane,groupsBody);
        if(showSelection&&selected!=null){
            sidebarPos.x=origin.x+(layout.overlay?available.x-layout.sidebar:layout.board+12);sidebarPos.y=origin.y;
            ImGui.setCursorScreenPos(sidebarPos);pane.x=layout.sidebar;chrome.card("##Browse.selection",pane,selectionBody);
        }
    }
    function drawGroups():Void {
        ImGui.alignTextToFramePadding();ImGui.textUnformatted("Recruiting board");
        ImGui.getContentRegionAvail(available);
        if(available.x>=850*engine.config.textScale){
            ImGui.sameLine(210*engine.config.textScale);
            ImGui.alignTextToFramePadding();ImGui.textColored(chrome.palette.status(0),"*Context Detected");
            ImGui.sameLine();ImGui.textColored(chrome.palette.status(2),"*No Context Detected");
            ImGui.sameLine();ImGui.textDisabled("Recruiting/run language found or absent");
        }else chrome.note("Green: recruiting/run language. Red: target mention only.");
        if(chrome.nav("Groups##groups",kind=="LFM")){kind="LFM";dirty=true;}
        ImGui.sameLine();if(chrome.nav("Players##players",kind=="LFG")){kind="LFG";dirty=true;}
        ImGui.sameLine();if(chrome.nav("All##all",kind=="All")){kind="All";dirty=true;}
        if(engine.config.relayEnabled)chrome.note(engine.relayStatus);
        ImGui.setNextItemWidth(-1);Scope.combo("##activityFilter",activityLabel,choicesBody);
        ImGui.setNextItemWidth(-1);if(ImGui.inputTextWithHint("##search","Search messages or player",search.bytes,search.size))dirty=true;
        if(ImGui.beginTable("##browseSortColumns",3,imgui.Enums.ImGuiTableFlags.SizingStretchProp)){
            var error:Dynamic=null;try{
                ImGui.tableSetupColumn("Target",imgui.Enums.ImGuiTableColumnFlags.WidthStretch,0.55);ImGui.tableSetupColumn("Player",imgui.Enums.ImGuiTableColumnFlags.WidthStretch,0.30);ImGui.tableSetupColumn("Age",imgui.Enums.ImGuiTableColumnFlags.WidthStretch,0.15);
                ImGui.tableNextRow();ImGui.tableSetColumnIndex(0);if(chrome.nav("Target##sortTarget",sortColumn==0))sort(0);
                ImGui.tableSetColumnIndex(1);if(chrome.nav("Player##sortPlayer",sortColumn==1))sort(1);
                ImGui.tableSetColumnIndex(2);if(chrome.nav("Age##sortAge",sortColumn==2))sort(2);
            }catch(e:Dynamic)error=e;ImGui.endTable();if(error!=null)throw error;
        }
        ImGui.getContentRegionAvail(available);listSize.x=0;listSize.y=Math.max(30,available.y);
        Scope.child("##listingViewport",listSize,listBody);
    }
    function drawChoices():Void {
        ImGui.setNextItemWidth(-1);if(ImGui.inputTextWithHint("##filterActivitySearch","Search activities",activities.search.bytes,activities.search.size))activities.changed();
        if(ImGui.selectable("All activities",activityId=="all")){activityId="all";activityLabel="All activities";dirty=true;}
        for(row in activities.rows){var clicked=Scope.selectable(row.id,row.activity.name,activityId==row.activity.id);if(clicked){activityId=row.activity.id;activityLabel=row.activity.name;dirty=true;}}
        if(activities.rows.length==0)chrome.empty("No activities match this search.");
        if(ImGui.selectable("Other/Custom",activityId=="other")){activityId="other";activityLabel="Other/Custom";dirty=true;}
    }
    function drawList():Void {
        if(!engine.state.available){chrome.empty("Chat integration unavailable.");return;}
        if(rows.length==0){chrome.empty(engine.board.entries.length==0?"Waiting for recruiting messages in monitored chat.":"No listings match. Adjust the filters or search.");return;}
        rowSize.x=0;rowSize.y=ImGui.getTextLineHeight()*3+20;
        ImGui.ImGuiListClipper_Begin(clipper,rows.length);var error:Dynamic=null;
        try {while(ImGui.ImGuiListClipper_Step(clipper))for(i in ImGui.ImGuiListClipper_get_DisplayStart(clipper)...ImGui.ImGuiListClipper_get_DisplayEnd(clipper))drawRow(rows[i]);}catch(e:Dynamic)error=e;
        ImGui.ImGuiListClipper_End(clipper);if(error!=null)throw error;
    }
    function drawRow(row:BrowseRow):Void {
        var l=row.listing;
        if(ImGui.selectable(row.id,selected!=null&&selected.key==l.key,0,rowSize)){selected=l;composing=false;}
        if(ImGui.isItemClicked(1)){selected=l;composing=false;}
        ImGui.getItemRectMin(a);ImGui.getItemRectMax(b);
        // Bind context actions before drawing decorations replaces LastItem.
        if(ImGui.beginPopupContextItem(l.uiId)){
            var error:Dynamic=null;try {
                if(Scope.cancelPopups)ImGui.closeCurrentPopup();else {
                    if(ImGui.menuItem("Whisper",null,false,l.isRemote?(l.relaySessionId!=""&&!l.isOwn):l.senderId!=engine.state.playerId))beginWhisper();
                    if(l.steamId!=null&&l.steamId!=""&&ImGui.menuItem("Copy Steam ID"))pendingCopy=l.steamId;
                    if(ImGui.menuItem("Hide listing"))engine.enqueue(engine.action("hide","","",l));
                    if(ImGui.menuItem("Ignore 30 minutes"))engine.enqueue(engine.action("ignore","","",l));
                    if(ImGui.menuItem("Watch activity"))watch(l);
                }
            }catch(e:Dynamic)error=e;ImGui.endPopup();if(error!=null)throw error;
        }
        // Popup submission can change scratch UI geometry; row rect was retained above.
        clipMin.x=a.x+6;clipMin.y=a.y;clipMax.x=b.x-6;clipMax.y=b.y;ImGui.pushClipRect(clipMin,clipMax,true);
        var dl=ImGui.getWindowDrawList();at.x=a.x+8;at.y=a.y+4;
        ImGui.ImDrawList_AddText_Vec2(dl,at,chrome.palette.textColor,row.title);
        at.y+=ImGui.getTextLineHeight()+2;
        ImGui.pushFont(ImGui.getFont(),ImGui.getFontSize()*0.85);var metaError:Dynamic=null;
        try {
            ImGui.ImDrawList_AddText_Vec2(dl,at,chrome.palette.mutedColor,row.meta);
            ImGui.calcTextSize(row.meta,false,-1,metaSize);at.x+=metaSize.x;
            ImGui.ImDrawList_AddText_Vec2(dl,at,l.contextDetected?chrome.palette.successColor:chrome.palette.dangerColor,l.contextDetected?"*Context Detected":"*No Context Detected");
        }catch(e:Dynamic)metaError=e;
        ImGui.popFont();if(metaError!=null){ImGui.popClipRect();throw metaError;}
        at.x=a.x+8;at.y+=ImGui.getTextLineHeight()+2;ImGui.ImDrawList_AddText_Vec2(dl,at,chrome.palette.mutedColor,row.excerpt);ImGui.popClipRect();
    }

    function drawSelection():Void {
        if(chrome.button("Close details##closeSelection")){clear();return;}
        chrome.header("Selected listing");
        if(selected==null){chrome.empty("Select a listing to read the original message and contact its player.");if(now<engine.whisperFeedbackUntil)chrome.status(feedback.text,feedback.kind);return;}
        Scope.colored(chrome.palette.accent,selected.target);chrome.note(selected.senderName);
        chrome.status(selected.contextDetected?"*Context Detected":"*No Context Detected",selected.contextDetected?0:2);
        chrome.gap();chrome.subHeader("Original message");Scope.wrapped(selected.text);chrome.note(selected.channel);
        if(selected.steamId!=null&&selected.steamId!=""){
            chrome.gap(4);chrome.note(selected.steamId);
            if(chrome.button("Copy Steam ID##copySelSteam"))pendingCopy=selected.steamId;
        }
        chrome.gap();var start=chrome.disabledButton(selected.isRemote?"Message##whisper":"Whisper##whisper",selected.isRemote?(selected.relaySessionId==""||selected.isOwn):selected.senderId==engine.state.playerId);
        if(start)beginWhisper();
        ImGui.sameLine();ImGui.setNextItemWidth(120);Scope.combo("##listingActions","Actions",choicesActions);
        if(composing){chrome.gap();chrome.subHeader("Whisper composer");ImGui.setNextItemWidth(-1);ImGui.inputTextWithHint("##whisperText","Edit your whisper",whisper.bytes,whisper.size);
            if(chrome.button("Send whisper##send",true))engine.enqueue(engine.action("whisper",whisper.get(),"Player",selected));
            if(SteamContact.valid(engine.config.steamId)){
                ImGui.sameLine();
                if(chrome.button("Attach Steam ID##attachSteamWhisper")){
                    var current=whisper.get();whisper.set(SteamContact.attach(current,engine.config.steamId,240));
                }
            }
            if(chrome.button("Cancel##cancel"))composing=false;
            if(now<engine.whisperFeedbackUntil)chrome.status(feedback.text,feedback.kind);
        }
        chrome.gap(12);chrome.subHeader(selected.isRemote?"Cross-server contact":"Recent chat this session");
        if(selected.isRemote){chrome.note(selected.relaySessionId==""?"This host is offline or using an older client.":"Use Message to open a private session conversation. Steam code sharing is optional.");return;}
        if(historySender!=selected.senderId)chrome.note("Loading recent messages...");
        else if(historyRows.length==0)chrome.note("No recent messages retained.");
        else for(row in historyRows){chrome.note(row.meta);Scope.wrapped(row.text);chrome.gap(8);}

    }
    function compareRows(a:BrowseRow,b:BrowseRow):Int return SortPolicy.listing(a.listing,b.listing,sortColumn,ascending);
    function sort(column:Int):Void {ascending=sortColumn==column?!ascending:true;sortColumn=column;dirty=true;}
    function drawActions():Void {if(selected==null)return;if(selected.steamId!=null&&selected.steamId!=""&&ImGui.menuItem("Copy Steam ID"))pendingCopy=selected.steamId;if(ImGui.menuItem("Hide listing"))engine.enqueue(engine.action("hide","","",selected));if(ImGui.menuItem("Ignore 30 minutes"))engine.enqueue(engine.action("ignore","","",selected));if(ImGui.menuItem("Watch activity"))watch(selected);}
    function beginWhisper():Void {if(selected==null)return;if(selected.isRemote){engine.enqueue(engine.action("whisper","Open private conversation","Relay",selected));return;}composing=true;whisper.set(selected.kind=="LFM"?"Hi! I'm interested in your group.":(selected.kind=="LFG"?"Hi! Would you like to join our group?":"Hi! Are you looking for a group?"));}
    function watch(l:Listing):Void {var id=l.activityId=="other"?"custom:"+Parser.normalized(l.target):l.activityId;if(engine.config.watchActivities.indexOf(id)<0&&engine.config.watchActivities.length<64)engine.config.watchActivities.push(id);engine.config.alertsEnabled=true;engine.markDirty(now);}
}
