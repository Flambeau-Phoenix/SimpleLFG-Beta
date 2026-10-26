package simplelfg;

import imgui.ImGui;
import imgui.Structs.ImVec2;
import imgui.ref.BoolRef;
import simplelfg.SocialService.SocialPerson;
import simplelfg.UiState.Confirmation;
import simplelfg.ui.DataTable;
import simplelfg.ui.ThemePalette;
import simplelfg.ui.UiChrome;

private class PersonRow {
    public var person:SocialPerson;public var id:String;public var relation:String;public var level:String;public var where:String;
    public function new(p:SocialPerson){
        person=p;id="##person_"+haxe.crypto.Sha256.encode(p.uid).substr(0,24);
        relation=p.pending?"Request pending":(p.friend?"Friend":"Realm player");
        level=p.level==null||p.level<=0?"-":""+p.level;where=p.detail==null||p.detail==""?"-":p.detail;
    }
}
/** Friends, realm players, your Farever code and the party, as a table beside an inspector. */
class PeoplePanel {
    static var fields=["online","name","level","where","relation","action"];
    var engine:Engine;var chrome:Chrome;var strip:PartyStrip;var layout=new WorkspaceLayout();
    var search=new TextBuffer(256);var addCode=new TextBuffer(64);
    var rows:Array<PersonRow>=[];var friendCount=0;var realmCount=0;
    var selected:SocialPerson=null;var filter="Friends";var dirty=true;var revision=-1;
    var query="";var session="";var now:Float=0;
    var searching=false;var sortField="name";var ascending=true;var onlineFirst=new BoolRef(true);var compactDetail=false;
    var confirm=new Confirmation();
    var available=new ImVec2();var pane=new ImVec2();var navSize=new ImVec2();var centre=new ImVec2();
    var table:DataTable;var boardBody:Void->Void;var inspectorBody:Void->Void;
    public function new(engine:Engine,chrome:Chrome,strip:PartyStrip){
        this.engine=engine;this.chrome=chrome;this.strip=strip;boardBody=drawBoard;inspectorBody=drawInspector;
        table=new DataTable("##peopleTable",[
            {label:"##online",width:26,fixed:true,sortable:true},{label:"Name",width:3,fixed:false,sortable:true,defaultSort:true},
            {label:"Lvl",width:48,fixed:true,sortable:true},{label:"Where",width:3,fixed:false,sortable:true},
            {label:"Relation",width:116,fixed:true,sortable:true},{label:"##action",width:92,fixed:true,sortable:false}],
            30,rowId,drawCell,isRowSelected,pickRow,drawRowMenu,activateRow);
    }
    public function clear():Void {selected=null;rows=[];search.set("");searching=false;addCode.set("");confirm.clear();compactDetail=false;dirty=true;}
    public function observe():Void {
        if(session!=engine.state.id){session=engine.state.id;clear();}
        table.rowHeight=Math.max(28,30*engine.config.textScale);
        if(table.takeSort()){sortField=table.sortColumn>=0?fields[table.sortColumn]:"name";ascending=table.sortColumn>=0?table.ascending:true;dirty=true;}
        if(!dirty&&revision==engine.social.revision)return;dirty=false;revision=engine.social.revision;
        query=search.get().toLowerCase();rows=[];friendCount=0;realmCount=0;
        for(p in engine.social.people){
            if(p.friend||p.pending)friendCount++;if(p.realm)realmCount++;
            if((filter=="Friends"?p.friend||p.pending:p.realm)&&(query==""||(p.name+" "+p.detail).toLowerCase().indexOf(query)>=0))rows.push(new PersonRow(p));
        }
        rows.sort(compareRows);
        if(selected!=null){selected=engine.social.find(selected.uid);if(selected==null){compactDetail=false;confirm.clear();}}
    }
    public function draw():Void {
        now=Sys.time();
        ImGui.getContentRegionAvail(available);layout.update(available.x,available.y,engine.config.textScale);pane.y=Math.max(1,available.y-2);
        if(layout.wide){
            pane.x=layout.leftWidth;chrome.card("##People.board",pane,boardBody);
            ImGui.sameLine(0,WorkspaceLayout.GAP);
            pane.x=layout.rightWidth;chrome.card("##People.inspector",pane,inspectorBody);
        }else{
            pane.x=available.x;
            if(selected!=null&&compactDetail)chrome.card("##People.inspector",pane,inspectorBody);else chrome.card("##People.board",pane,boardBody);
        }
    }

    // ---- table -----------------------------------------------------------------------------------

    function compareRows(a:PersonRow,b:PersonRow):Int {
        if(onlineFirst.get()&&a.person.online!=b.person.online)return a.person.online?-1:1;
        var n=switch(sortField){
            case "online":(a.person.online?0:1)-(b.person.online?0:1);
            case "level":(a.person.level==null?0:a.person.level)-(b.person.level==null?0:b.person.level);
            case "where":SortPolicy.text(a.where,b.where);
            case "relation":SortPolicy.text(a.relation,b.relation);
            default:SortPolicy.text(a.person.name,b.person.name);
        }
        if(n==0)n=SortPolicy.text(a.person.name,b.person.name);
        if(n==0)n=SortPolicy.text(a.person.uid,b.person.uid);
        return ascending?n:-n;
    }
    function rowId(i:Int):String return rows[i].id;
    function isRowSelected(i:Int):Bool return selected!=null&&selected.uid==rows[i].person.uid;
    function pickRow(i:Int):Void {if(i<0||i>=rows.length)return;if(selected==null||selected.uid!=rows[i].person.uid)confirm.clear();selected=rows[i].person;compactDetail=true;}
    function activateRow(i:Int):Void {pickRow(i);if(selected!=null&&selected.online&&engine.social.party.canInvite)act("invite");}
    function drawCell(i:Int,column:Int):Void {
        var r=rows[i];var p=r.person;
        switch(column){
            case 0:
                ImGui.getCursorScreenPos(centre);centre.x+=8;centre.y+=ImGui.getTextLineHeight()*0.5;
                ImGui.ImDrawList_AddCircleFilled(ImGui.getWindowDrawList(),centre,4,p.online?chrome.palette.successColor:chrome.palette.mutedColor,12);
            case 1:ImGui.textUnformatted(p.name);
            case 2:ImGui.textUnformatted(r.level);
            case 3:ImGui.textDisabled(r.where);
            case 4:ImGui.textUnformatted(r.relation);
            default:drawRowAction(r);
        }
    }
    function drawRowAction(r:PersonRow):Void {
        var p=r.person;var w=84*engine.config.textScale;
        if(p.friend&&p.online){
            ImGui.setCursorPosY(ImGui.getCursorPosY()-table.padY+2);
            ImGui.beginDisabled(!engine.social.party.canInvite||inParty(p.uid));
            if(chrome.button("Invite###invite"+r.id,false,w)){selected=p;act("invite");}
            ImGui.endDisabled();
        }else if(!p.friend){
            ImGui.setCursorPosY(ImGui.getCursorPosY()-table.padY+2);
            ImGui.beginDisabled(p.pending);
            if(chrome.button(p.pending?"Pending###add"+r.id:"Add###add"+r.id,false,w)){selected=p;act("addFriend");}
            ImGui.endDisabled();
        }
    }
    function drawRowMenu(i:Int):Void {if(i>=0&&i<rows.length)drawPersonMenu(rows[i].person);}
    function drawPersonMenu(p:SocialPerson):Void {
        if(ImGui.menuItem("Invite to party",null,false,p.online&&engine.social.party.canInvite&&!inParty(p.uid)))act("invite");
        if(ImGui.menuItem("Add friend",null,false,!p.friend&&!p.pending))act("addFriend");
        ImGui.separator();
        if(ImGui.menuItem("Copy name"))UiActionQueue.copy(p.name);
        if(ImGui.menuItem("Remove friend...",null,false,p.friend)){selected=p;confirm.clear();confirm.press("remove_"+p.uid);}
    }
    function inParty(uid:String):Bool {for(m in engine.social.party.members)if(m.uid==uid)return true;return false;}

    // ---- board -----------------------------------------------------------------------------------

    function drawBoard():Void {
        var s=engine.config.textScale;navSize.x=Math.max(120,132*s);navSize.y=Math.max(26,28*s);
        if(UiChrome.navButton("Friends ("+friendCount+")###filterFriends",filter=="Friends",navSize)){filter="Friends";dirty=true;}
        ImGui.sameLine(0,6);if(UiChrome.navButton("Same realm ("+realmCount+")###filterRealm",filter=="Realm",navSize)){filter="Realm";dirty=true;}
        ImGui.sameLine(0,16);ImGui.alignTextToFramePadding();
        if(ImGui.checkbox("Online first##onlineFirst",onlineFirst))dirty=true;
        ImGui.setNextItemWidth(searching?-40:-1);
        if(UiText.input("##peopleSearch","Search people or zones",search)){dirty=true;searching=search.get()!="";}
        if(searching){ImGui.sameLine(0,6);if(chrome.button("x##clearPeopleSearch",false,30)){search.set("");searching=false;dirty=true;}}
        ImGui.textDisabled(engine.social.status);
        ImGui.getContentRegionAvail(available);
        table.navigate(selectedIndex(),rows.length);
        table.draw(available.x,Math.max(60,available.y),rows.length,filter=="Friends"?"No friends to show. Add one by Farever code, or right-click a listing and choose Add friend.":"No matching players. The realm list only includes players this game instance exposes.");
    }
    function selectedIndex():Int {if(selected==null)return -1;for(i in 0...rows.length)if(rows[i].person.uid==selected.uid)return i;return -1;}

    // ---- inspector -------------------------------------------------------------------------------

    function drawInspector():Void {
        if(!layout.wide&&chrome.button("Back to list##backPeople")){compactDetail=false;return;}
        chrome.header("Farever contacts");
        drawCode();
        chrome.gap(8);drawParty();
        chrome.gap(8);drawSelected();
    }
    function drawCode():Void {
        var code=engine.social.code;var s=engine.config.textScale;
        chrome.subHeader("Your friend code");
        ImGui.alignTextToFramePadding();
        if(code=="")ImGui.textDisabled("Unavailable until the game loads. A manual code can be set under Settings, Privacy.");
        else{
            ImGui.textUnformatted(code);ImGui.sameLine(0,10);
            if(chrome.button("Copy###copyMyCode",false,70*s))UiActionQueue.copy(code);
        }
        chrome.gap(4);
        ImGui.alignTextToFramePadding();ImGui.textDisabled("Add by code");ImGui.sameLine(0,8);
        ImGui.setNextItemWidth(-(104*s));UiText.input("##addCode","XXXX-XXXX-XXXX",addCode);
        ImGui.sameLine(0,6);
        if(chrome.disabledButton("Add friend###addByCode",!FareverContact.valid(addCode.get()),false,96*s)){engine.enqueue(engine.action("addCode",addCode.get()));addCode.set("");}
        if(addCode.get()!=""&&!FareverContact.valid(addCode.get()))chrome.status("Farever codes have 12 letters or digits.",1);
    }
    function drawParty():Void {
        var p=engine.social.party;var s=engine.config.textScale;
        chrome.subHeader(p.members.length>1?"Party "+p.members.length+"/"+p.capacity:"Party");
        if(p.members.length<=1){chrome.note("You are not in a party. Invite an online friend from the list, or accept an invitation in game.",false);return;}
        for(m in p.members){
            ImGui.alignTextToFramePadding();
            ImGui.textUnformatted(m.self?"You":m.name);
            if(m.leader){ImGui.sameLine(0,8);ImGui.textColored(ThemePalette.status(ThemePalette.STATUS_INFO),"leader");}
        }
        chrome.gap(4);
        ImGui.beginDisabled(!p.canLeave);
        if(chrome.button(strip.isArmed()?"Confirm leave?###peopleLeave":"Leave party###peopleLeave",false,130*s,strip.isArmed()))strip.requestLeave();
        ImGui.endDisabled();
        if(p.leader)chrome.note("You lead this party. The game decides who can be invited.",false);
    }
    function drawSelected():Void {
        var s=engine.config.textScale;
        chrome.subHeader("Selected player");
        if(selected==null){chrome.note("Select a person, or right-click for actions.",false);return;}
        var p=selected;
        UiChrome.heading(p.name,1.15);
        ImGui.textColored(ThemePalette.status(p.online?ThemePalette.STATUS_SUCCESS:ThemePalette.STATUS_INFO),p.online?"Online":"Offline");
        ImGui.sameLine(0,12);ImGui.textDisabled(p.pending?"Request pending":(p.friend?"Friend":"Same realm"));
        if(p.level!=null&&p.level>0){ImGui.sameLine(0,12);ImGui.textDisabled("Level "+p.level);}
        if(p.detail!=null&&p.detail!="")chrome.note(p.detail,false);
        chrome.gap(4);
        var canInvite=p.online&&engine.social.party.canInvite&&!inParty(p.uid);
        if(chrome.disabledButton("Invite to party###inspectorInvitePerson",!canInvite,true,140*s))act("invite");
        ImGui.sameLine(0,6);
        if(p.friend){
            var id="remove_"+p.uid;
            if(chrome.button(confirm.target==id?"Confirm remove?###removeFriend":"Remove friend###removeFriend",false,140*s,confirm.target==id)&&confirm.press(id))act("removeFriend");
        }else if(chrome.disabledButton("Add friend###inspectorAddPerson",p.pending,false,120*s))act("addFriend");
        ImGui.sameLine(0,6);if(chrome.button("Copy name###copyPersonName",false,100*s))UiActionQueue.copy(p.name);
        chrome.note("Friend requests and party invitations need the other player's normal acceptance in game.",false);
    }
    function act(kind:String):Void {
        if(selected==null)return;
        engine.enqueue(engine.socialAction(kind,selected.uid,selected.name));
        if(kind=="removeFriend")confirm.clear();
    }
}
