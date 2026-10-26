package simplelfg;

import imgui.ImGui;
import imgui.Structs.ImVec2;
import imgui.ref.BoolRef;
import imgui.ref.IntRef;
import simplelfg.Types.Draft;
import simplelfg.UiState.Confirmation;
import simplelfg.UiState.TemplateRows;
import simplelfg.UiState.TemplateRow;

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
    var fields:Void->Void;var previewBody:Void->Void;var partyCell:Int->Float->Void;
    var steamActions:Int->Float->Void;
    var available=new ImVec2();var previewSize=new ImVec2();
    var preview:String="";var postLabel:String="Post###post";var cooldown=-1;
    var feedback=new FeedbackTone();
    public function new(engine:Engine,chrome:Chrome){this.engine=engine;this.chrome=chrome;
        workspace=new Workspace(chrome,"##Post",drawEditor,drawLibrary,450,400);
        steamActions=drawSteamAction;fields=drawFields;previewBody=drawPreview;partyCell=drawPartyCell;sync();
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
        workspace.draw(engine.config.textScale,layout.bodyHeight);
        chrome.gap(8);previewSize.x=0;previewSize.y=layout.previewHeight;chrome.canvas("##Post.preview",previewSize,previewBody);
        var submit=chrome.disabledButton(postLabel,engine.cooldown>0||engine.relayPostPending||engine.relayPostError!=""||engine.config.draft.activity==""||!engine.state.available||!engine.previewCurrent(),true,120);
        if(submit)engine.enqueue(engine.action("post",preview,engine.config.draft.channel));
        ImGui.sameLine();if(ImGui.checkbox("Remind me##reminder",reminder)){engine.config.reminder=reminder.get();engine.markDirty(now);}
    }
    function drawPreview():Void {
        if(now<engine.postFeedbackUntil)chrome.status(feedback.text,feedback.kind);
        Scope.wrapped(preview);
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
        Scope.row("Activity");if(ImGui.inputTextWithHint("##activity","Catalogue or custom target",activity.bytes,activity.size)){d.activity=Config.clean(activity.get(),80);changed=true;}
        Scope.row("Difficulty");if(Scope.choice("##difficulty",difficulty,difficulties)){d.difficulty=difficulty.get()==2?"Heroic":(difficulty.get()==1?"Veteran":"Normal");changed=true;}
        Scope.row("Class (optional)");if(Scope.choice("##playerClass",playerClass,classChoices)){d.playerClass=playerClass.get()==0?"":classChoices[playerClass.get()];changed=true;}
        Scope.row("Bonus Runs");if(ImGui.checkbox("Bonus Runs##bonus",bonus)){d.bonusRuns=bonus.get();changed=true;}
        if(d.kind=="LFM"){Scope.row("Party size");Scope.inlineGroup("##party",2,partyCell);}
        Scope.row("Note");if(ImGui.inputTextWithHint("##note","Optional short note",note.bytes,note.size)){d.note=Config.clean(note.get(),160);changed=true;}
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
        ImGui.setNextItemWidth(-1);if(ImGui.inputTextWithHint("##activitySearch","Search activities or bosses",activities.search.bytes,activities.search.size))activities.changed();
        for(row in activities.rows){var pick=Scope.selectable(row.id,row.activity.name,engine.config.draft.activity==row.activity.name);if(pick){engine.config.draft.activity=row.activity.name;activity.set(row.activity.name);engine.markDirty(now);}}
        if(activities.rows.length==0)chrome.empty("No activities match. You can enter a custom target.");
        chrome.gap(12);if(chrome.actionRow("Saved templates","Save##saveTemplate")){engine.saveTemplate(now);confirm.clear();}
        chrome.note("Up to five saved posts. Select one to load a copy.");
        if(templates.rows.length==0)chrome.empty("No saved templates yet.");
        for(row in templates.rows){var picked=Scope.selectable(row.id,row.label,selectedTemplate!=null&&row.id==selectedTemplate.id);
            if(picked)loadTemplate(row);
            if(ImGui.isItemClicked(1)){if(selectedTemplate!=row)confirm.clear();selectedTemplate=row;}
            if(ImGui.beginPopupContextItem(row.menuId)){var e:Dynamic=null;try{if(Scope.cancelPopups)ImGui.closeCurrentPopup();else{if(ImGui.menuItem("Load template"))loadTemplate(row);if(ImGui.menuItem("Delete template")){selectedTemplate=row;confirm.clear();confirm.press(row.id);}}}catch(x:Dynamic)e=x;ImGui.endPopup();if(e!=null)throw e;}
        }
        if(selectedTemplate!=null&&chrome.confirm("Delete template###confirm",confirm,selectedTemplate.id)){
            engine.config.templates.remove(selectedTemplate.draft);selectedTemplate=null;engine.markDirty(now);
        }
    }
    function loadTemplate(row:TemplateRow):Void {confirm.clear();selectedTemplate=row;engine.config.draft=row.draft.copy();sync();engine.markDirty(now);}
}
