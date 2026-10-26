package simplelfg;

import simplelfg.Types.Listing;
import imgui.ImGui;
import imgui.Enums.ImGuiFocusedFlags;
import imgui.Enums.ImGuiKey;
import imgui.Structs.ImVec2;
import imgui.ref.BoolRef;
import simplelfg.ui.DataTable;
import simplelfg.ui.ThemePalette;
import simplelfg.ui.UiChrome;

private class BrowseRow {
    public var listing:Listing;public var id:String;public var title:String;public var excerpt:String;public var age:String;
    public var player:String;public var party:String;public var source:String;public var kind:String;
    public function new(l:Listing,now:Float){
        listing=l;id="###listing_"+l.uiId;title=l.target;kind=l.kind;
        var seconds=Std.int(Math.max(0,now-l.seen));age=seconds<60?seconds+"s":Std.int(seconds/60)+"m";
        player=l.senderName+(l.playerClass!=""?" ("+l.playerClass+")":"");
        party=partyText(l.composition);source=l.isRemote?(l.isOwn?"Yours":"Cross-server"):"Game";excerpt=l.text;
    }
    static function partyText(c:String):String {
        if(c==null||c==""||c=="Size unspecified"||StringTools.startsWith(c,"Solo"))return "-";
        var i=c.indexOf(" advertised open slots");return i>0?c.substr(0,i)+" open":c;
    }
}
/** Master/detail board: a sortable table of listings beside a docked inspector. */
class BrowsePanel {
    static var fields=["context","target","type","player","party","source","age","message"];
    var engine:Engine;var chrome:Chrome;var layout=new WorkspaceLayout();var activities=new ActivityChoices();
    var search=new TextBuffer(160);var whisper=new TextBuffer(384);
    var kind:String="All";var activityId:String="all";var activityLabel:String="All activities";
    var selected:Listing=null;var composing=false;var now:Float=0;var revision=-1;var second=-1;var dirty=true;
    var rows:Array<BrowseRow>=[];var footer:String="Observed chat only - not a server directory.";
    var pendingCopy:String=null;var withdrawKey="";var selectedAge="";
    var historyRows:Array<{meta:String,text:String}>=[];var historyRevision=-1;var historySender="";
    var searching=false;var sortField="age";var ascending=true;var compactDetail=false;var focusSearch=false;var contextOnly=new BoolRef(false);
    var available=new ImVec2();var pane=new ImVec2();var navSize=new ImVec2();
    var table:DataTable;
    var boardBody:Void->Void;var inspectorBody:Void->Void;var choicesBody:Void->Void;var metaBody:Void->Void;var moreBody:Void->Void;
    public function new(engine:Engine,chrome:Chrome){this.engine=engine;this.chrome=chrome;
        boardBody=drawBoard;inspectorBody=drawInspector;choicesBody=drawChoices;metaBody=drawMeta;moreBody=drawActions;
        table=new DataTable("##browseTable",[
            {label:"##context",width:26,fixed:true,sortable:true},{label:"Target",width:3,fixed:false,sortable:true},
            {label:"Type",width:56,fixed:true,sortable:true},{label:"Player",width:2,fixed:false,sortable:true},
            {label:"Party",width:66,fixed:true,sortable:true},{label:"Source",width:96,fixed:true,sortable:true},
            {label:"Age",width:54,fixed:true,sortable:true,defaultSort:true},{label:"Message",width:4,fixed:false,sortable:true}],
            26,rowId,drawCell,isRowSelected,pickRow,drawRowMenu,activateRow);
    }
    public function clear():Void {selected=null;withdrawKey="";composing=false;compactDetail=false;whisper.set("");historyRows=[];historySender="";dirty=true;}
    public function hasSelection():Bool return selected!=null;
    public function selectedTargets():Array<String> return selected==null?[]:selected.matchedTargetIds;
    public function observe(time:Float,visible:Bool=true):Void {
        now=time;if(pendingCopy!=null){ImGui.setClipboardText(pendingCopy);pendingCopy=null;}activities.observe();
        table.rowHeight=Math.max(24,26*engine.config.textScale);
        if(table.takeSort()){sortField=table.sortColumn>=0?fields[table.sortColumn]:"age";ascending=table.sortColumn>=0?table.ascending:true;dirty=true;}
        if(selected!=null){var found:Listing=null;for(l in engine.board.entries)if(l.key==selected.key&&!l.hidden&&(!engine.config.requireRecruitingContext||l.contextDetected))found=l;selected=found;if(found==null){composing=false;compactDetail=false;}}
        if(contextOnly.get()!=engine.config.requireRecruitingContext)contextOnly.set(engine.config.requireRecruitingContext);
        if(selected!=null&&(historyRevision!=engine.board.history.revision||historySender!=selected.senderId||second!=Std.int(time))){
            historyRevision=engine.board.history.revision;historySender=selected.senderId;
            historyRows=[for(e in engine.board.history.forSender(selected.senderId)){meta:e.channel+" | "+Std.int(Math.max(0,time-e.receivedAt))+"s ago",text:e.text}];
            selectedAge=Std.int(Math.max(0,time-selected.seen))+"s ago";
        }
        if(visible&&(dirty||revision!=engine.board.revision||second!=Std.int(time))){
            dirty=false;revision=engine.board.revision;second=Std.int(time);
            rows=[for(l in engine.board.filtered(kind,activityId,search.get()))new BrowseRow(l,time)];
            rows.sort(compareRows);
            footer=rows.length+" listings  |  Observed chat only - not a server directory.";
        }
    }
    public function view(key:String):Void {
        kind="All";activityId="all";activityLabel="All activities";search.set("");searching=false;selected=null;composing=false;compactDetail=true;
        for(l in engine.board.entries)if(l.key==key&&!l.hidden&&(l.isRemote?now<l.expiresAt:now-l.seen<engine.config.expirySeconds))selected=l;
        if(selected==null)engine.report("whisper","That listing expired. Browse the currently active groups.",now);
        dirty=true;
    }

    // ---- table callbacks -------------------------------------------------------------------------

    function rowId(i:Int):String return rows[i].id;
    function isRowSelected(i:Int):Bool return selected!=null&&rows[i].listing.key==selected.key;
    function pickRow(i:Int):Void {if(i<0||i>=rows.length)return;if(selected==null||selected.key!=rows[i].listing.key){composing=false;withdrawKey="";}selected=rows[i].listing;compactDetail=true;}
    function activateRow(i:Int):Void {pickRow(i);beginWhisper();}
    function selectedIndex():Int {if(selected==null)return -1;for(i in 0...rows.length)if(rows[i].listing.key==selected.key)return i;return -1;}
    function drawCell(i:Int,column:Int):Void {
        var r=rows[i];var l=r.listing;
        switch(column){
            case 0:
                var p=ImGui.getCursorScreenPos(centre);centre.x+=8;centre.y+=ImGui.getTextLineHeight()*0.5;
                ImGui.ImDrawList_AddCircleFilled(ImGui.getWindowDrawList(),centre,4,l.contextDetected?chrome.palette.successColor:chrome.palette.dangerColor,12);
            case 1:ImGui.textUnformatted(r.title);
            case 2:ImGui.textUnformatted(r.kind);
            case 3:ImGui.textUnformatted(r.player);
            case 4:ImGui.textUnformatted(r.party);
            case 5:ImGui.textUnformatted(r.source);
            case 6:ImGui.textUnformatted(r.age);
            default:ImGui.textDisabled(r.excerpt);
        }
    }
    var centre=new ImVec2();
    function drawRowMenu(i:Int):Void {if(i>=0&&i<rows.length)drawListingMenu(rows[i].listing);}

    // ---- layout ----------------------------------------------------------------------------------

    public function draw():Void {
        ImGui.getContentRegionAvail(available);layout.update(available.x,available.y,engine.config.textScale);
        pane.y=Math.max(1,available.y-2);
        if(layout.wide){
            pane.x=layout.leftWidth;chrome.card("##Browse.board",pane,boardBody);
            ImGui.sameLine(0,WorkspaceLayout.GAP);
            pane.x=layout.rightWidth;chrome.card("##Browse.inspector",pane,inspectorBody);
        }else{
            pane.x=available.x;
            if(selected!=null&&compactDetail)chrome.card("##Browse.inspector",pane,inspectorBody);else chrome.card("##Browse.board",pane,boardBody);
        }
    }
    function setKind(value:String):Void {kind=value;dirty=true;}
    function drawBoard():Void {
        var s=engine.config.textScale;navSize.x=Math.max(78,82*s);navSize.y=Math.max(26,28*s);
        if(UiChrome.navButton("All###kindAll",kind=="All",navSize))setKind("All");
        ImGui.sameLine(0,6);if(UiChrome.navButton("Groups###kindLfm",kind=="LFM",navSize))setKind("LFM");
        ImGui.sameLine(0,6);if(UiChrome.navButton("Players###kindLfg",kind=="LFG",navSize))setKind("LFG");
        ImGui.sameLine(0,16);ImGui.alignTextToFramePadding();
        if(ImGui.checkbox("Context only##contextOnly",contextOnly)){engine.config.requireRecruitingContext=contextOnly.get();engine.markDirty(now);}
        ImGui.setNextItemWidth(Math.max(150,210*s));Scope.combo("##activityFilter",activityLabel,choicesBody);
        ImGui.sameLine(0,8);
        if(focusSearch){ImGui.setKeyboardFocusHere();focusSearch=false;}
        ImGui.setNextItemWidth(searching?-40:-1);
        if(UiText.input("##search","Search messages, players or targets",search)){dirty=true;searching=search.get()!="";}
        if(searching){ImGui.sameLine(0,6);if(chrome.button("x##clearSearch",false,30)){search.set("");searching=false;dirty=true;}}
        ImGui.alignTextToFramePadding();
        ImGui.textColored(ThemePalette.status(ThemePalette.STATUS_SUCCESS),"Green: recruiting language");
        ImGui.sameLine(0,16);ImGui.textColored(ThemePalette.status(ThemePalette.STATUS_DANGER),"Red: target mention only");
        if(engine.config.relayEnabled){ImGui.sameLine(0,16);ImGui.textDisabled(engine.relayStatus);}
        keys();
        ImGui.getContentRegionAvail(available);
        var emptyText=!engine.state.available?"Chat integration unavailable.":(engine.board.entries.length==0?"Waiting for recruiting messages in monitored chat.":"No listings match. Adjust the filters or search.");
        table.navigate(selectedIndex(),rows.length);
        table.draw(available.x,Math.max(60,available.y-ImGui.getTextLineHeight()-18),rows.length,emptyText);
        ImGui.textDisabled(footer);
    }
    /** Ctrl+F focuses search; Delete hides the selected listing. Only while this window has focus and nothing is being edited. */
    function keys():Void {
        if(!ImGui.isWindowFocused(ImGuiFocusedFlags.RootAndChildWindows))return;
        if((ImGui.isKeyDown(ImGuiKey.LeftCtrl)||ImGui.isKeyDown(ImGuiKey.RightCtrl))&&ImGui.isKeyPressed(ImGuiKey.F,false))focusSearch=true;
        if(selected!=null&&!ImGui.isAnyItemActive()&&ImGui.isKeyPressed(ImGuiKey.Delete,false)){engine.enqueue(engine.action("hide","","",selected));selected=null;compactDetail=false;}
    }
    function drawChoices():Void {
        ImGui.setNextItemWidth(-1);if(UiText.input("##filterActivitySearch","Search activities",activities.search))activities.changed();
        if(ImGui.selectable("All activities",activityId=="all")){activityId="all";activityLabel="All activities";dirty=true;}
        for(row in activities.rows){var clicked=Scope.selectable(row.id,row.activity.name,activityId==row.activity.id);if(clicked){activityId=row.activity.id;activityLabel=row.activity.name;dirty=true;}}
        if(activities.rows.length==0)chrome.empty("No activities match this search.");
        if(ImGui.selectable("Other/Custom",activityId=="other")){activityId="other";activityLabel="Other/Custom";dirty=true;}
    }

    // ---- inspector -------------------------------------------------------------------------------

    function drawInspector():Void {
        if(!layout.wide&&chrome.button("Back to board##backBoard")){compactDetail=false;return;}
        chrome.header("Listing");
        if(selected==null){chrome.empty("Select a listing to read the message and contact its player.");return;}
        var l=selected;var s=engine.config.textScale;
        UiChrome.heading(l.target,1.15);
        ImGui.alignTextToFramePadding();
        ImGui.textColored(ThemePalette.status(l.contextDetected?ThemePalette.STATUS_SUCCESS:ThemePalette.STATUS_DANGER),l.contextDetected?"Context detected":"No context detected");
        ImGui.sameLine(0,12);ImGui.textDisabled(l.kind=="LFM"?"Recruiting":(l.kind=="LFG"?"Looking for a group":l.kind));
        chrome.gap(4);
        Scope.properties("##browseMeta",metaBody);
        chrome.gap(8);
        drawActionRow(l,s);
        if(composing)drawComposer(l,s);
        if(l.isRemote&&l.isOwn&&withdrawKey==l.key){
            chrome.gap(4);chrome.note("Remove your public listing from the cross-server board?");
            if(chrome.disabledButton("Confirm withdrawal##confirmWithdraw",engine.withdrawPending,false,150*s)){engine.enqueue(engine.action("withdraw",l.relayListingId,"",l));withdrawKey="";}
            ImGui.sameLine(0,6);if(chrome.button("Cancel##cancelWithdraw"))withdrawKey="";
        }
        chrome.gap(8);chrome.subHeader("Original message");Scope.wrapped(l.text);
        chrome.gap(8);chrome.subHeader(l.isRemote?"Cross-server contact":"Recent chat this session");
        if(l.isRemote){chrome.note(l.relaySessionId==""?"This host is offline or using an older client.":"Use Message to open a private conversation. Steam code sharing is optional.");return;}
        if(historySender!=l.senderId)chrome.note("Loading recent messages...");
        else if(historyRows.length==0)chrome.note("No recent messages retained.");
        else for(row in historyRows){chrome.note(row.meta);Scope.wrapped(row.text);chrome.gap(6);}
    }
    function drawMeta():Void {
        var l=selected;if(l==null)return;
        Scope.row("Player");ImGui.textUnformatted(l.senderName);
        if(l.playerClass!=""){Scope.row("Class");ImGui.textUnformatted(l.playerClass);}
        Scope.row("Posted");ImGui.textUnformatted(selectedAge);
        Scope.row("Source");ImGui.textUnformatted(l.isRemote?(l.isOwn?"Your public listing":"Cross-server board"):"Game chat ("+l.channel+")");
        Scope.row("Party");ImGui.textUnformatted(l.composition);
        if(l.steamId!=null&&l.steamId!=""){Scope.row("Steam ID");ImGui.textUnformatted(l.steamId);}
        if(l.fareverCode!=""){Scope.row("Farever code");ImGui.textUnformatted(l.fareverCode);}
    }
    function drawActionRow(l:Listing,s:Float):Void {
        var canMessage=l.isRemote?(l.relaySessionId!=""&&!l.isOwn):l.senderId!=engine.state.playerId;
        if(chrome.disabledButton(l.isRemote?"Message###inspectorWhisper":"Whisper###inspectorWhisper",!canMessage,!composing,110*s))beginWhisper();
        if(!l.isRemote){
            var p=engine.social.find(l.senderId);
            ImGui.sameLine(0,6);if(chrome.disabledButton("Add friend###inspectorAdd",p==null||p.friend||p.pending,false,110*s))engine.enqueue(engine.action("addFriend","","",l));
            ImGui.sameLine(0,6);if(chrome.disabledButton("Invite###inspectorInvite",p==null||!p.online,false,90*s))engine.enqueue(engine.action("invite","","",l));
        }
        ImGui.sameLine(0,6);if(chrome.button("More###inspectorMore",false,80*s))ImGui.openPopup("##inspectorMoreMenu");
        simplelfg.ContextMenuSystem.draw("##inspectorMoreMenu",moreBody);
    }
    function drawComposer(l:Listing,s:Float):Void {
        chrome.gap(8);chrome.subHeader("Whisper");
        ImGui.setNextItemWidth(-1);UiText.input("##whisperText","Edit your whisper",whisper,true);
        if(chrome.button("Send whisper###sendWhisper",true,130*s))engine.enqueue(engine.action("whisper",whisper.get(),"Player",l));
        ImGui.sameLine(0,6);if(chrome.button("Cancel###cancelWhisper",false,90*s))composing=false;
        if(SteamContact.valid(engine.config.steamId)){ImGui.sameLine(0,6);if(chrome.button("Add Steam ID###attachSteamWhisper")){whisper.set(SteamContact.attach(whisper.get(),engine.config.steamId,240));}}
        ImGui.sameLine(0,6);if(chrome.disabledButton("Share Farever code###attachFareverWhisper",engine.social.code==""))whisper.set(FareverContact.attach(whisper.get(),engine.social.code));
    }

    // ---- actions ---------------------------------------------------------------------------------

    /** Row right-click menu and the inspector's More menu: the same actions in the same order. */
    function drawListingMenu(l:Listing):Void {
        if(ImGui.menuItem("Whisper",null,false,l.isRemote?(l.relaySessionId!=""&&!l.isOwn):l.senderId!=engine.state.playerId))beginWhisper();
        ImGui.separator();
        if(l.steamId!=null&&l.steamId!=""&&ImGui.menuItem("Copy Steam ID"))pendingCopy=l.steamId;
        if(l.fareverCode!=""){
            if(ImGui.menuItem("Copy Farever code"))pendingCopy=l.fareverCode;
            if(ImGui.menuItem("Add friend by Farever code"))engine.enqueue(engine.action("addCode",l.fareverCode));
        }
        if(!l.isRemote){
            var p=engine.social.find(l.senderId);
            if(ImGui.menuItem("Add friend",null,false,p!=null&&!p.friend&&!p.pending))engine.enqueue(engine.action("addFriend","","",l));
            if(ImGui.menuItem("Invite to party",null,false,p!=null&&p.online))engine.enqueue(engine.action("invite","","",l));
        }
        ImGui.separator();
        if(ImGui.menuItem("Watch activity"))watch(l);
        if(ImGui.menuItem("Hide listing","Del"))engine.enqueue(engine.action("hide","","",l));
        if(ImGui.menuItem("Ignore 30 minutes"))engine.enqueue(engine.action("ignore","","",l));
        ImGui.separator();
        if(ImGui.menuItem("Copy message"))pendingCopy=l.text;
        if(l.isRemote&&l.isOwn&&ImGui.menuItem("Withdraw public listing...",null,false,engine.relay.socialSupported))withdrawKey=l.key;
    }
    function drawActions():Void {if(selected!=null)drawListingMenu(selected);}
    function compareRows(a:BrowseRow,b:BrowseRow):Int return SortPolicy.board(a.listing,b.listing,sortField,ascending);
    function beginWhisper():Void {if(selected==null)return;if(selected.isRemote){engine.enqueue(engine.action("whisper","Open private conversation","Relay",selected));return;}composing=true;whisper.set(selected.kind=="LFM"?"Hi! I'm interested in your group.":(selected.kind=="LFG"?"Hi! Would you like to join our group?":"Hi! Are you looking for a group?"));}
    function watch(l:Listing):Void {var id=l.activityId=="other"?"custom:"+Parser.normalized(l.target):l.activityId;if(engine.config.watchActivities.indexOf(id)<0&&engine.config.watchActivities.length<64)engine.config.watchActivities.push(id);engine.config.alertsEnabled=true;engine.markDirty(now);}
}
