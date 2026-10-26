package simplelfg;

import imgui.ImGui;
import imgui.Structs.ImVec2;
import simplelfg.ui.ThemePalette;

/** One-line party status beside the navigation: roster, invite shortcut and a two-step Leave. */
class PartyStrip {
    static inline var LEAVE_W:Float=124;
    static inline var INVITE_W:Float=76;
    static inline var COPY_W:Float=64;
    var engine:Engine;var chrome:Chrome;var onInvite:Void->Void;
    var revision=-1;var title="";var roster="";var code="";var armed=false;var armedUntil:Float=0;var now:Float=0;
    var frameMin=new ImVec2();var frameMax=new ImVec2();var cachedScale:Float=-1;var cachedRevision=-2;var cachedWidth:Float=0;var measure=new ImVec2();
    public function new(engine:Engine,chrome:Chrome,onInvite:Void->Void){this.engine=engine;this.chrome=chrome;this.onInvite=onInvite;}
    public function clear():Void {armed=false;}
    public function isArmed():Bool return armed;
    /** One line for menus: "Solo" or "Party 2/4: You (leader), Aria". */
    public function summary():String return roster==""||title=="Solo"?title:title+": "+roster;
    public function observe(time:Float):Void {
        now=time;if(armed&&(now>=armedUntil||!engine.social.party.canLeave))armed=false;
        if(revision==engine.social.revision)return;revision=engine.social.revision;
        var p=engine.social.party;code=engine.social.code;
        if(p.members.length>1){
            title="Party "+p.members.length+"/"+p.capacity;
            roster=[for(m in p.members)(m.self?"You":m.name)+(m.leader?" (leader)":"")].join(", ");
        }else{title="Solo";roster=code==""?"":"Friend code "+code;}
    }
    function together():Bool return engine.social.party.members.length>1;
    /** Pixel width of the strip at this text scale; cached until the roster or scale changes. */
    public function width(scale:Float):Float {
        if(cachedScale==scale&&cachedRevision==revision)return cachedWidth;
        cachedScale=scale;cachedRevision=revision;
        ImGui.calcTextSize(title+"  "+roster,false,-1,measure);
        var p=engine.social.party;
        cachedWidth=measure.x+16+(together()?(p.leader&&p.canInvite?INVITE_W*scale+8:0)+LEAVE_W*scale+8:(p.canInvite?INVITE_W*scale+8:0)+(code==""?0:COPY_W*scale+8));
        return cachedWidth;
    }
    /** Bordered pill behind the strip, drawn first so the roster and buttons sit inside it as one anchored block. */
    function drawFrame(frameWidth:Float,frameHeight:Float):Void {
        ImGui.getCursorScreenPos(frameMin);frameMin.x-=8;frameMin.y-=3;
        frameMax.x=frameMin.x+frameWidth;frameMax.y=frameMin.y+frameHeight;
        var theme=ThemePalette.current();var dl=ImGui.getWindowDrawList();
        ImGui.ImDrawList_AddRectFilled(dl,frameMin,frameMax,ImGui.colorConvertFloat4ToU32(ImGui.vec4(theme.cellBg.x,theme.cellBg.y,theme.cellBg.z,0.7)),9);
        ImGui.ImDrawList_AddRect(dl,frameMin,frameMax,ImGui.colorConvertFloat4ToU32(theme.border),9,1.5);
    }
    public function draw(frameHeight:Float):Void {
        var p=engine.social.party;var scale=engine.config.textScale;
        drawFrame(width(scale),frameHeight);
        ImGui.alignTextToFramePadding();
        ImGui.textColored(ThemePalette.status(together()?ThemePalette.STATUS_SUCCESS:ThemePalette.STATUS_INFO),title);
        if(roster!=""){ImGui.sameLine(0,10);ImGui.textUnformatted(roster);}
        if(together()){
            if(p.leader&&p.canInvite){ImGui.sameLine(0,8);if(chrome.button("Invite###partyInvite",false,INVITE_W*scale))onInvite();}
            ImGui.sameLine(0,8);
            ImGui.beginDisabled(!p.canLeave);
            var error:Dynamic=null;
            try if(chrome.button(armed?"Confirm leave?###partyLeave":"Leave###partyLeave",false,LEAVE_W*scale,armed))requestLeave() catch(e:Dynamic)error=e;
            ImGui.endDisabled();if(error!=null)throw error;
        }else{
            if(p.canInvite){ImGui.sameLine(0,8);if(chrome.button("Invite###partyInvite",false,INVITE_W*scale))onInvite();}
            if(code!=""){ImGui.sameLine(0,8);if(chrome.button("Copy###copyCode",false,COPY_W*scale))UiActionQueue.copy(code);}
        }
    }
    /** First click arms for three seconds; the second sends the request. */
    public function requestLeave():Void {
        if(!engine.social.party.canLeave)return;
        if(!armed){armed=true;armedUntil=now+3;return;}
        armed=false;engine.enqueue(engine.socialAction("leaveParty"));
    }
}
