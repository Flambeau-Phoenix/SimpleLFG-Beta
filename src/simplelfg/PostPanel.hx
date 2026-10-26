package simplelfg;

import imgui.ImGui;
import imgui.Structs.ImVec2;
import imgui.ref.BoolRef;
import imgui.ref.IntRef;
import simplelfg.Types.Draft;
import simplelfg.UiState.Confirmation;
import simplelfg.UiState.TemplateRows;
import simplelfg.UiState.TemplateRow;
import simplelfg.ui.DataTable;

class PostPanel {
    var engine:Engine;var chrome:Chrome;var workspace:Workspace;var layout=new WorkspaceLayout();
    var activities=new ActivityChoices();var templates=new TemplateRows();var confirm=new Confirmation();
    var selectedTemplate:TemplateRow=null;var now:Float=0;var revision:Int=-1;
    var activity=new TextBuffer(128);var note=new TextBuffer(256);
    var channels=["All (game chat)","Local (game chat)","Cross-server (public)"];var channelChoice=new IntRef();
    var difficulties=["Normal","Veteran","Heroic"];
    var difficulty=new IntRef();var bonus=new BoolRef();var reminder=new BoolRef();
    var playerClass=new IntRef();var classChoices=["Not specified","Warrior","Mage","Priest","Rogue"];
    var members=new IntRef();var capacity=new IntRef();
    var memberChoices=[["0"],["0","1"],["0","1","2"],["0","1","2","3"]];
    var capacityChoices=["1","2","3","4"];
    var targetCell:Int->Float->Void;var targetWeights=[3.0,1.4];var lfmWeights=[1.6,1.0,1.0,1.2];var lfgWeights=[1.6,1.2];
    var fields:Void->Void;var previewBody:Void->Void;var partyCell:Int->Float->Void;
    var steamActions:Int->Float->Void;
    var available=new ImVec2();var previewSize=new ImVec2();var listSize=new ImVec2();
    var templateTable:DataTable;var activityBody:Void->Void;
    var preview:String="";var postLabel:String="Post###post";var cooldown=-1;
    var feedback=new FeedbackTone();
    public function new(engine:Engine,chrome:Chrome){this.engine=engine;this.chrome=chrome;
        workspace=new Workspace(chrome,"##Post",drawEditor,drawLibrary,450,400);
        steamActions=drawSteamAction;fields=drawFields;previewBody=drawPreview;partyCell=drawDetailCell;targetCell=drawTargetCell;activityBody=drawActivityList;
        templateTable=new DataTable("##templateTable",[{label:"Template",width:1,fixed:false,sortable:false},{label:"##templateActions",width:156,fixed:true,sortable:false}],28,templateId,templateCell,templateSelected,templatePick,templateMenu,templateActivate);
        sync();
    }
    public function clear():Void {confirm.clear();}
    public function observe(time:Float):Void {
        now=time;activities.observe();preview=engine.preview;feedback.observe(engine.postFeedback);
        if(revision!=engine.settingsRevision){revision=engine.settingsRevision;templates.update(engine.config.templates);if(selectedTemplate!=null&&engine.config.templates.indexOf(selectedTemplate.draft)<0){selectedTemplate=null;confirm.clear();}}
        if(cooldown!=engine.cooldown){cooldown=engine.cooldown;postLabel=cooldown>0?"Wait "+cooldown+"s###post":"Post###post";}
    }
    function sync():Void {
        var d=engine.config.draft;activity.set(d.activity);note.set(d.note);difficulty.set(d.difficulty=="Heroic"?2:(d.difficulty=="Veteran"?1:0));bonus.set(d.bonusRuns);
        playerClass.set(d.playerClass==""?0:classChoices.indexOf(d.playerClass));
        channelChoice.set(d.channel=="Relay"?2:(d.channel=="Local"?1:0));reminder.set(engine.config.reminder);members.set(d.members);capacity.set(d.capacity-1);
    }
    public function draw():Void {
        ImGui.getContentRegionAvail(available);layout.update(available.x,available.y,engine.config.textScale,true);
        // What will be posted comes first, large; the Post button sits right under it, and the editor fills the rest.
        previewSize.x=0;previewSize.y=layout.previewHeight;chrome.card("##Post.preview",previewSize,previewBody);
        var submit=chrome.disabledButton(postLabel,engine.cooldown>0||engine.relayPostPending||engine.relayPostError!=""||engine.config.draft.activity==""||!engine.state.available||!engine.previewCurrent(),true,120);
        if(submit)engine.enqueue(engine.action("post",preview,engine.config.draft.channel));
        ImGui.sameLine();if(ImGui.checkbox("Remind me##reminder",reminder)){engine.config.reminder=reminder.get();engine.markDirty(now);}
        chrome.gap(8);workspace.draw(engine.config.textScale,layout.bodyHeight);
    }
    /** The reviewed text at 1.25x so it can be read at a glance before posting. */
    function drawPreview():Void {
        chrome.subHeader("Preview - this is exactly what will be posted");
        ImGui.pushFont(ImGui.getFont(),ImGui.getFontSize()*1.25);var error:Dynamic=null;
        try Scope.wrapped(preview) catch(e:Dynamic)error=e;
        ImGui.popFont();if(error!=null)throw error;
    }
    function drawEditor():Void {
        chrome.header("Build your post");
        var d=engine.config.draft;
        if(chrome.nav("Recruit (LFM)##lfm",d.kind=="LFM")){d.kind="LFM";engine.markDirty(now);}
        ImGui.sameLine();if(chrome.nav("Find group (LFG)##lfg",d.kind=="LFG")){d.kind="LFG";engine.markDirty(now);}
        chrome.gap();chrome.subHeader("Destination");Scope.properties("##postFields",fields);
        chrome.note(engine.config.draft.channel=="Relay"?"Only this reviewed listing is published to the public cross-server board.":"Party size is an advertised claim.");
    }
    function drawFields():Void {
        var d=engine.config.draft;var changed=false;
        // Two compact rows instead of five: dungeon beside difficulty, then class, party size and the Bonus Runs box.
        Scope.row("Target");Scope.inlineWeighted("##target",targetWeights,targetCell);
        Scope.row("Details");Scope.inlineWeighted("##details",d.kind=="LFM"?lfmWeights:lfgWeights,partyCell);
        Scope.row("Note");if(UiText.input("##note","Optional short note",note,true)){d.note=Config.clean(note.get(),160);changed=true;}
        if(d.channel!="Relay"){
            Scope.row("Farever contact");
            if(chrome.disabledButton("Attach Farever code##attachFareverPost",engine.social.code=="")){d.note=FareverContact.attach(d.note,engine.social.code,160);note.set(d.note);changed=true;}
            if(FareverContact.extract(d.note)!=""&&chrome.button("Remove Farever code##removeFareverPost")){d.note=FareverContact.withoutTags(d.note);note.set(d.note);changed=true;}
        }
        if((d.channel!="Relay"&&SteamContact.valid(engine.config.steamId))||SteamContact.hasTag(d.note)){
            Scope.row("Steam contact");Scope.inlineGroup("##steamPostActions",2,steamActions);
        }
        Scope.row("Channel");if(Scope.choice("##postChannel",channelChoice,channels)){
            d.channel=channelChoice.get()==2?"Relay":(channelChoice.get()==1?"Local":"All");
            if(d.channel=="Relay")engine.config.relayEnabled=true;
            changed=true;
        }
        if(changed)engine.markDirty(now);
    }
    function drawSteamAction(i:Int,w:Float):Void {
        var d=engine.config.draft;var next=d.note;
        if(i==0){if(chrome.disabledButton("Attach Steam ID##attachSteamPost",d.channel=="Relay"||!SteamContact.valid(engine.config.steamId),false,Math.min(120,w)))next=SteamContact.attach(d.note,engine.config.steamId,160);}
        else if(chrome.disabledButton("Remove Steam ID##removeSteamPost",!SteamContact.hasTag(d.note),false,Math.min(140,w)))next=SteamContact.detach(d.note);
        if(next!=d.note){d.note=next;note.set(next);engine.markDirty(now);}
    }
    function drawTargetCell(i:Int,w:Float):Void {
        var d=engine.config.draft;
        if(i==0){
            ImGui.textDisabled("Activity");ImGui.setNextItemWidth(Math.max(1,w));
            if(UiText.input("##activity","Catalogue or custom target",activity)){d.activity=Config.clean(activity.get(),80);engine.markDirty(now);}
        }else{
            ImGui.textDisabled("Difficulty");ImGui.setNextItemWidth(Math.max(1,w));
            if(Scope.choice("##difficulty",difficulty,difficulties)){d.difficulty=difficulty.get()==2?"Heroic":(difficulty.get()==1?"Veteran":"Normal");engine.markDirty(now);}
        }
    }
    function drawDetailCell(i:Int,w:Float):Void {
        var d=engine.config.draft;
        if(i==0){
            ImGui.textDisabled("Class (optional)");ImGui.setNextItemWidth(Math.max(1,w));
            if(Scope.choice("##playerClass",playerClass,classChoices)){d.playerClass=playerClass.get()==0?"":classChoices[playerClass.get()];engine.markDirty(now);}
        }else if(d.kind=="LFM"&&i<3)drawPartyCell(i-1,w);
        else{
            ImGui.textDisabled("Extras");
            if(ImGui.checkbox("Bonus Runs##bonus",bonus)){d.bonusRuns=bonus.get();engine.markDirty(now);}
        }
    }
    function drawPartyCell(i:Int,w:Float):Void {
        var d=engine.config.draft;
        if(i==0){
            chrome.note("Members");ImGui.setNextItemWidth(Math.max(1,w));
            if(Scope.choice("##members",members,memberChoices[d.capacity-1])){d.members=members.get();engine.markDirty(now);}
        }else{
            chrome.note("Capacity");ImGui.setNextItemWidth(Math.max(1,w));
            if(Scope.choice("##capacity",capacity,capacityChoices)){
                d.capacity=capacity.get()+1;d.members=Std.int(Math.min(d.members,d.capacity-1));members.set(d.members);engine.markDirty(now);
            }
        }
    }
    function drawLibrary():Void {
        chrome.header("Activities & templates");
        ImGui.setNextItemWidth(-1);if(UiText.input("##activitySearch","Search activities or bosses",activities.search))activities.changed();
        ImGui.getContentRegionAvail(available);listSize.x=0;listSize.y=Math.max(120,(available.y-120)*0.55);
        Scope.child("##activityList",listSize,activityBody);
        chrome.gap(8);chrome.subHeader("Saved templates ("+templates.rows.length+"/5)");
        if(chrome.button("Save current post###saveTemplate",false,160*engine.config.textScale)){engine.saveTemplate(now);confirm.clear();}
        chrome.gap(4);ImGui.getContentRegionAvail(available);
        templateTable.rowHeight=Math.max(28,30*engine.config.textScale);
        templateTable.draw(available.x,Math.max(70,available.y),templates.rows.length,"No saved templates yet. Fill in a post and choose Save current post.");
    }
    function drawActivityList():Void {
        for(row in activities.rows){var pick=Scope.selectable(row.id,row.activity.name,engine.config.draft.activity==row.activity.name);if(pick){engine.config.draft.activity=row.activity.name;activity.set(row.activity.name);engine.markDirty(now);}}
        if(activities.rows.length==0)chrome.empty("No activities match. You can enter a custom target.");
    }
    function templateId(i:Int):String return "##"+templates.rows[i].id;
    function templateSelected(i:Int):Bool return selectedTemplate!=null&&templates.rows[i].id==selectedTemplate.id;
    function templatePick(i:Int):Void {if(i<0||i>=templates.rows.length)return;if(selectedTemplate!=templates.rows[i])confirm.clear();selectedTemplate=templates.rows[i];}
    function templateActivate(i:Int):Void {if(i>=0&&i<templates.rows.length)loadTemplate(templates.rows[i]);}
    function templateMenu(i:Int):Void {
        if(i<0||i>=templates.rows.length)return;var row=templates.rows[i];
        if(ImGui.menuItem("Load template"))loadTemplate(row);
        ImGui.separator();
        if(ImGui.menuItem("Delete template...")){selectedTemplate=row;confirm.clear();confirm.press(row.id);}
    }
    function templateCell(i:Int,column:Int):Void {
        var row=templates.rows[i];
        if(column==0){ImGui.textUnformatted(row.label);return;}
        ImGui.setCursorPosY(ImGui.getCursorPosY()-templateTable.padY+2);
        if(chrome.button("Load###tload"+row.id,false,64))loadTemplate(row);
        ImGui.sameLine(0,4);
        var armed=confirm.target==row.id;
        if(chrome.button(armed?"Confirm?###tdelete"+row.id:"Delete###tdelete"+row.id,false,84,armed)&&confirm.press(row.id)){
            engine.config.templates.remove(row.draft);if(selectedTemplate==row)selectedTemplate=null;confirm.clear();engine.markDirty(now);
        }
    }
    function loadTemplate(row:TemplateRow):Void {confirm.clear();selectedTemplate=row;engine.config.draft=row.draft.copy();sync();engine.markDirty(now);}
}
