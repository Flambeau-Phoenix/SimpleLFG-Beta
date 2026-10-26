package simplelfg;

import simplelfg.LootBrowser.LootLine;
import simplelfg.TargetDefaults.BossTarget;
import imgui.ImGui;
import imgui.Structs.ImVec2;
import imgui.ref.IntRef;

/** Boss-only list/detail viewer; all model work and texture loading run in observe. */
class LootPanel {
    var model:LootBrowser;var chrome:Chrome;var config:Config;var art=new LootArt();
    var bosses:Array<BossTarget>;var bossRows:Array<BossTarget>=[];
    var bossSearch=new TextBuffer(128);var itemSearch=new TextBuffer(128);var difficulty=new IntRef();
    var difficulties=["Normal","Veteran","Heroic"];var sorts=["Name","Rarity","Type"];var sortChoice=new IntRef();
    var selectedId="";var bossName="Choose boss";var pending=true;var filterDirty=true;
    var rows:Array<LootLine>=[];var selectedItem:LootLine=null;var summary="";var error="";
    var ascending=true;var copy:String=null;var copyFeedback="";var requested=false;
    var available=new ImVec2();var origin=new ImVec2();var position=new ImVec2();var pane=new ImVec2();
    var choicesBody:Void->Void;var dropsBody:Void->Void;var inspectorBody:Void->Void;
    public function new(chrome:Chrome,config:Config){
        this.chrome=chrome;this.config=config;bosses=TargetDefaults.bosses();
        model=new LootBrowser(haxe.Resource.getString("boss-loot"));
        choicesBody=drawChoices;dropsBody=drawDrops;inspectorBody=drawInspector;
    }
    public function openForTargets(ids:Array<String>):Void {
        var match:BossTarget=null;var count=0;
        for(b in bosses)if(ids.indexOf(b.targetId)>=0){match=b;count++;}
        if(count==1)selectedId=match.id;
        if(selectedId==""&&bosses.length>0)selectedId=bosses[0].id;
        selectedItem=null;pending=true;
    }
    public function clearTransientState():Void {copy=null;copyFeedback="";bossSearch.set("");itemSearch.set("");filterDirty=true;pending=true;selectedItem=null;}
    public function observe(active:Bool=false):Void {
        art.plateColor=chrome.palette.headerColor;art.borderColor=chrome.palette.mutedColor;
        if(active){requested=true;art.observe();}
        if(copy!=null){try{ImGui.setClipboardText(copy);copyFeedback="Item name copied.";}catch(_:Dynamic){copyFeedback="Could not copy item name.";}copy=null;}
        if(filterDirty){var q=Parser.normalized(bossSearch.get());bossRows=[for(b in bosses)if(q==""||Parser.normalized(b.name+" "+b.id).indexOf(q)>=0)b];filterDirty=false;}
        if(!pending)return;pending=false;
        bossName="Choose boss";for(b in bosses)if(b.id==selectedId)bossName=b.name;
        model.choose(selectedId,difficulty.get(),itemSearch.get());rows=model.lines;rows.sort(compareRows);error=model.error;
        summary=model.selected==null?"No boss-specific loot table is linked for this boss.":model.summary;
        if(selectedItem!=null){var found:LootLine=null;for(r in rows)if(r.key==selectedItem.key)found=r;selectedItem=found;}
    }
    public function draw():Void {
        ImGui.getContentRegionAvail(available);var scale=config.textScale;
        ImGui.setNextItemWidth(Math.max(90,available.x-168*scale-8));Scope.combo("##lootBoss",bossName,choicesBody);
        ImGui.sameLine();ImGui.setNextItemWidth(168*scale);if(Scope.choice("##lootDifficulty",difficulty,difficulties))pending=true;
        chrome.gap(8);ImGui.getContentRegionAvail(available);ImGui.getCursorScreenPos(origin);
        var usable=Math.max(1,available.x-12);var left=usable*0.42;
        pane.x=left;pane.y=Math.max(1,available.y);chrome.card("##lootItemsCard",pane,dropsBody);
        position.x=origin.x+left+12;position.y=origin.y;ImGui.setCursorScreenPos(position);
        pane.x=usable-left;chrome.card("##lootInspectorCard",pane,inspectorBody);
    }
    function drawChoices():Void {
        ImGui.setNextItemWidth(-1);if(UiText.input("##bossSearch","Search bosses",bossSearch))filterDirty=true;
        for(b in bossRows)if(Scope.selectable(b.id,b.name,b.id==selectedId)){selectedId=b.id;selectedItem=null;pending=true;}
        if(bossRows.length==0)chrome.empty("No bosses match this search.");
    }
    function drawDrops():Void {
        chrome.subHeader("Boss loot");
        ImGui.setNextItemWidth(-1);if(UiText.input("##lootItemsSearch","Search this boss's items",itemSearch))pending=true;
        ImGui.setNextItemWidth(120);if(Scope.choice("##lootSort",sortChoice,sorts))pending=true;
        ImGui.sameLine();if(chrome.button(ascending?"A-Z##direction":"Z-A##direction")){ascending=!ascending;pending=true;}
        if(error!=""){chrome.status(error,2);return;}
        if(rows.length==0){chrome.empty(summary);return;}
        if(requested&&!art.ready)chrome.note("Item artwork unavailable.");
        for(row in rows)drawItem(row);
    }
    function drawItem(row:LootLine):Void {
        ImGui.pushID_Str(row.key);var error:Dynamic=null;
        try {
            ImGui.beginGroup();var groupError:Dynamic=null;
            try {
                art.draw(row.iconKey,48*config.textScale);ImGui.sameLine();
                if(ImGui.selectable(row.title,selectedItem!=null&&selectedItem.key==row.key)){selectedItem=row;copyFeedback="";}
            }catch(e:Dynamic)groupError=e;
            ImGui.endGroup();if(groupError!=null)throw groupError;
            if(ImGui.isItemClicked(1)){selectedItem=row;copyFeedback="";}
            ContextMenuSystem.openForItem("##lootContext");if(ImGui.beginPopup("##lootContext")){var failure:Dynamic=null;
                try {if(Scope.cancelPopups)ImGui.closeCurrentPopup();else{if(ImGui.menuItem("Inspect"))selectedItem=row;if(ImGui.menuItem("Copy item name"))copy=row.title;}}catch(e:Dynamic)failure=e;
                ImGui.endPopup();if(failure!=null)throw failure;
            }
        }catch(e:Dynamic)error=e;
        ImGui.popID();if(error!=null)throw error;
    }
    function drawInspector():Void {
        chrome.subHeader(bossName);
        if(selectedItem==null){chrome.note(summary);chrome.gap(8);chrome.note(rows.length==0?"":"Select an item to inspect its artwork and source restrictions.");return;}
        art.draw(selectedItem.iconKey,96*config.textScale);Scope.wrapped(selectedItem.title);
        chrome.note(selectedItem.rarity);chrome.note(selectedItem.itemType);Scope.wrapped(selectedItem.description);
        chrome.gap(8);chrome.subHeader("Authored source");Scope.wrapped(selectedItem.detail);
        chrome.note("Table weights are not per-kill drop percentages.");
        if(chrome.button("Copy item name##copy"))copy=selectedItem.title;
        if(copyFeedback!="")chrome.note(copyFeedback);
    }
    function compareRows(a:LootLine,b:LootLine):Int return SortPolicy.loot(a,b,sortChoice.get(),ascending);
}
