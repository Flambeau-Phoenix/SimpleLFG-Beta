package simplelfg;

import imgui.ImGui;
import imgui.Structs.ImVec2;
import imgui.Enums.ImGuiKey;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Enums.ImGuiCond;
import imgui.ref.BoolRef;
import imgui.ref.IntRef;
import simplelfg.ui.MenuKit;
import simplelfg.ui.ThemePalette;
import simplelfg.ui.ToastManager;
import simplelfg.ui.UiChrome;

/** Window lifetime, geometry and shared-style scope; workspaces own their editors. */
class Panel {
    public static inline var VERSION="SimpleLFG v1.1";
    var engine:Engine;var native:NativeChat;
    var palette=new Palette();var input=new InputController();var chrome:Chrome;
    var artwork=new LauncherArt();
    var browse:BrowsePanel;var post:PostPanel;var loot:LootPanel;var settings:SettingsPanel;var launcher:Launcher;
    var messenger:MessengerPanel;var messageLabel="Messages###navMessages";
    var people:PeoplePanel;var tabChoice=new IntRef();var strip:PartyStrip;
    /** Display order of the pages; the page indices themselves are stable (0 Browse, 1 Post, 2 Settings, 3 Messages, 4 People). */
    var navOrder=[0,1,4,3,2];var navNames=["Browse","Post","People","Messages","Settings"];var navLabels=["Browse###navBrowse","Post###navPost","People###navPeople","Messages###navMessages","Settings###navSettings"];
    var lootOpen=new BoolRef(false);var lootNextSize=true;var lootSize=new ImVec2(820,620);var lootPosition=new ImVec2();
    var lootMinimum=new ImVec2(640,420);
    var navAvailable=new ImVec2();var navSize=new ImVec2();var navText=new ImVec2();var stripPos=new ImVec2();
    var open=new BoolRef(false);var forceBrowse=false;var nextSize=true;var now:Float=0;
    var size=new ImVec2();var position=new ImVec2();var measured=new ImVec2();var measuredPosition=new ImVec2();
    var minimum=new ImVec2(520,360);var maximum=new ImVec2(1800,1200);
    var toastPosition=new ImVec2();var toastSize=new ImVec2(350,150);
    var screenW:Float=0;var screenH:Float=0;
    var activeTab:Int=0;
    var themeRevision=-1;var toastSerial=0;var toastTone=new FeedbackTone();
    var quickInvite=false;var logoPos=new ImVec2();var logoSize=new ImVec2();var uv0=new ImVec2(0,0);var uv1=new ImVec2(1,1);var leavePrompt=false;var shortcutsPrompt=false;var aboutPrompt=false;var partyMenuWanted=false;
    var menuBody:Void->Void;var fileBody:Void->Void;var viewBody:Void->Void;var partyBody:Void->Void;var helpBody:Void->Void;var textSizeBody:Void->Void;var themeBody:Void->Void;var inviteBody:Void->Void;
    var windowMenuBody:Void->Void;var leaveBody:Void->Void;var shortcutsBody:Void->Void;var aboutBody:Void->Void;
    var scales=[0.85,1.0,1.25,1.5];var scaleNames=["85%","100%","125%","150%"];var themeNames=["Midnight","Slate","Warm"];
    var keyTableOk=true;var keyClash="";var keyClashFor="";var gameKey=-1;var gameKeyFor="";var toggleAt:Float=0;
    public function new(engine:Engine,native:NativeChat){
        this.engine=engine;this.native=native;chrome=new Chrome(palette);
        browse=new BrowsePanel(engine,chrome);post=new PostPanel(engine,chrome);loot=new LootPanel(chrome,engine.config);
        messenger=new MessengerPanel(engine,chrome);settings=new SettingsPanel(engine,chrome);launcher=new Launcher(engine,artwork);
        strip=new PartyStrip(engine,chrome,openQuickInvite);people=new PeoplePanel(engine,chrome,strip);launcher.leave=strip;
        size.x=engine.config.width;size.y=engine.config.height;
        menuBody=drawMenus;fileBody=drawFileMenu;viewBody=drawViewMenu;partyBody=drawPartyMenu;helpBody=drawHelpMenu;textSizeBody=drawTextSizeMenu;themeBody=drawThemeMenu;inviteBody=drawInviteMenu;
        windowMenuBody=drawWindowMenu;leaveBody=drawLeaveBody;shortcutsBody=drawShortcutsBody;aboutBody=drawAboutBody;
        keyTableOk=KeyCapture.tableMatchesBinding();
        ThemePalette.init();
    }
    function openPeople():Void activate(4);
    /** The strip's Invite button: a list at the pointer, not a page change. */
    function openQuickInvite():Void {quickInvite=true;partyMenuWanted=true;}
    public function observe(time:Float):Void {
        engine.relayVisible=open.get();
        now=time;palette.observe(engine.config);
        if(themeRevision!=engine.settingsRevision){
            themeRevision=engine.settingsRevision;var c=engine.config;
            ThemePalette.applyHost(c.highContrast?0x000000:c.background,c.highContrast?0x171717:c.surface,c.accent,c.highContrast?0xFFFFFF:c.foreground,c.opacity);
        }
        maximum.x=Math.max(1,native.screenWidth);maximum.y=Math.max(1,native.screenHeight);
        minimum.x=Math.min(520,maximum.x);minimum.y=Math.min(360,maximum.y);
        if(engine.config.migrated){
            engine.config.width=Geometry.clamp(engine.config.width,minimum.x,maximum.x);engine.config.height=Geometry.clamp(engine.config.height,minimum.y,maximum.y);
            engine.config.windowX=Geometry.x(engine.config,native.screenWidth);engine.config.windowY=Geometry.y(engine.config,native.screenHeight);
            engine.config.migrated=false;engine.markDirty(now);
        }
        if(screenW!=native.screenWidth||screenH!=native.screenHeight){screenW=native.screenWidth;screenH=native.screenHeight;nextSize=true;size.x=engine.config.width;size.y=engine.config.height;}
        if(settings.resetGeometry){settings.resetGeometry=false;browse.clear();nextSize=true;size.x=engine.config.width;size.y=engine.config.height;}
        // The game owning the pointer (camera mode) only makes the window non-interactive; logout, loading and cutscenes still close it.
        if(engine.sessionChanged||!engine.state.available){if(open.get()||lootOpen.get())close(true);}
        if(engine.sessionChanged){browse.clear();post.clear();settings.clear();messenger.clear();people.clear();strip.clear();}
        UiActionQueue.observe(engine.state.id,open.get()&&engine.state.available&&engine.state.cursorFree||lootOpen.get()&&engine.state.available&&engine.state.cursorFree);
        engine.social.open=open.get()||engine.config.quickLeaveChip;
        engine.social.visible=open.get()&&(activeTab==4||activeTab==0&&browse.hasSelection()||partyMenuWanted);partyMenuWanted=false;
        people.observe();strip.observe(now);
        if(engine.requestedRelayPeer!=""){activeTab=3;open.set(true);}
        messenger.observe();if(open.get()&&activeTab==3)engine.relayMessages.read();
        messageLabel=engine.relayMessages.unread>0?"Messages ("+engine.relayMessages.unread+")###navMessages":"Messages###navMessages";
        browse.observe(time,open.get()&&activeTab==0);post.observe(time);loot.observe(lootOpen.get());settings.observe(time);launcher.observe(time,screenW,screenH);
        resolveGameKey();observeKey();
        if(toastSerial!=engine.feedbackSerial){
            toastSerial=engine.feedbackSerial;
            if(open.get()&&engine.feedbackText!=""){
                toastTone.observe(engine.feedbackText);
                switch(toastTone.kind){case 0:ToastManager.success(engine.feedbackText,2.5);case 1:ToastManager.warn(engine.feedbackText,3.5);case 2:ToastManager.error(engine.feedbackText,4.5);default:ToastManager.info(engine.feedbackText,2.5);}
            }
        }
        if(engine.alerts.soundRequested){if(engine.state.available)input.playSound();engine.alerts.soundRequested=false;}
        input.observe(engine.state.available,engine.state.cursorFree,open.get()||lootOpen.get()||engine.config.launcherEnabled||now<engine.alerts.toastUntil||engine.config.quickLeaveChip&&engine.social.party.canLeave,now);
        size.x=engine.config.width;size.y=engine.config.height;
    }
    /** The engine key code is resolved once per change; draw only compares against it. */
    function resolveGameKey():Void {
        var c=engine.config;var wanted=c.panelKey+"/"+c.panelMods;
        if(gameKeyFor==wanted)return;gameKeyFor=wanted;
        gameKey=c.panelMods==0?NativeKeys.gameCode(c.panelKey):-1;
    }
    /** The panel key works in either pointer mode: ImGui's key state, with the engine's own key state as a second signal. */
    function keyHit():Bool {
        if(now<toggleAt)return false;var c=engine.config;
        var hit=keyTableOk?KeyCapture.pressed(c.panelKey,c.panelMods):ImGui.isKeyPressed(ImGuiKey.F5,false);
        if(!hit&&gameKey>0&&!ImGui.isAnyItemActive()&&KeyCapture.mods()==0){try hit=hxd.Key.isPressed(gameKey) catch(_:Dynamic){}}
        if(hit)toggleAt=now+0.25;
        return hit;
    }
    /** Key clashes are looked up once per change, never per frame. */
    function observeKey():Void {
        var c=engine.config;var wanted=c.panelKey+"/"+c.panelMods;
        if(keyClashFor==wanted||!open.get())return;
        keyClashFor=wanted;var own=KeyBinding.knownOwner(c.panelKey,c.panelMods);
        var game=NativeKeys.clash(c.panelKey,c.panelMods);
        keyClash=game!=""?"Farever also binds this key to "+game+".":(own!=""?own+" uses this key.":"");
        settings.keyWarning=keyClash;
    }
    function close(allWindows:Bool=false):Void {open.set(false);Scope.cancelPopups=true;UiActionQueue.reset();browse.clear();post.clear();settings.clear();messenger.clear();people.clear();strip.clear();KeyCapture.cancel();if(allWindows){lootOpen.set(false);loot.clearTransientState();}}
    function activate(tab:Int):Void {if(activeTab!=tab){activeTab=tab;KeyCapture.cancel();post.clear();settings.cancelConfirm();strip.clear();}}

    function toggle():Void {if(open.get()||lootOpen.get())close(true);else{open.set(true);engine.alerts.acknowledge();}}
    public function draw():Void {
        palette.push();ImGui.pushFont(ImGui.getFont(),16*engine.config.textScale);var failure:Dynamic=null;
        try {
            var c=engine.config;
            if(KeyCapture.finished)KeyCapture.finished=false;
            else if(engine.state.available&&!KeyCapture.listening&&keyHit())toggle();
            if(launcher.draw())toggle();drawToast();
            if(open.get()){drawMain();if(!open.get())close();else Scope.cancelPopups=false;}
            if(lootOpen.get()){drawLootWindow();if(!lootOpen.get())loot.clearTransientState();Scope.cancelPopups=false;}
            if(engine.state.available)ToastManager.draw();
        }catch(e:Dynamic)failure=e;
        ImGui.popFont();palette.pop();input.finishFrame(open.get()||lootOpen.get());if(failure!=null)throw failure;
    }
    function drawMain():Void {
        if(nextSize){
            size.x=Geometry.clamp(size.x,minimum.x,maximum.x);size.y=Geometry.clamp(size.y,minimum.y,maximum.y);
            position.x=Geometry.clamp(engine.config.windowX<0?(screenW-size.x)*0.5:engine.config.windowX,0,screenW-size.x);position.y=Geometry.clamp(engine.config.windowY<0?(screenH-size.y)*0.5:engine.config.windowY,0,screenH-size.y);
            ImGui.setNextWindowPos(position,ImGuiCond.Always);ImGui.setNextWindowSize(size,ImGuiCond.Always);nextSize=false;
        }
        ImGui.setNextWindowSizeConstraints(minimum,maximum);
        UiChrome.pushCelShade();
        var shown=ImGui.begin("SimpleLFG###SimpleLFG.Main",open,ImGuiWindowFlags.NoSavedSettings|ImGuiWindowFlags.NoCollapse|ImGuiWindowFlags.MenuBar|(engine.state.cursorFree?0:ImGuiWindowFlags.NoInputs));
        ImGui.beginDisabled(!engine.state.cursorFree);
        var error:Dynamic=null;try if(shown)drawBody() catch(e:Dynamic)error=e;
        ImGui.endDisabled();ImGui.end();UiChrome.popCelShade();if(error!=null)throw error;
    }
    function drawBody():Void {
        ImGui.getWindowSize(measured);ImGui.getWindowPos(measuredPosition);
        var changed=false;
        if(Math.abs(measured.x-engine.config.width)>1){engine.config.width=measured.x;size.x=measured.x;changed=true;}
        if(Math.abs(measured.y-engine.config.height)>1){engine.config.height=measured.y;changed=true;}
        if(Math.abs(measuredPosition.x-position.x)>1||Math.abs(measuredPosition.y-position.y)>1){engine.config.windowX=measuredPosition.x;engine.config.windowY=measuredPosition.y;changed=true;}
        position.x=measuredPosition.x;position.y=measuredPosition.y;
        if(changed)engine.markDirty(now);
        if(forceBrowse){activate(0);forceBrowse=false;}
        MenuKit.bar(menuBody);
        openWindowMenu();
        pollShortcuts();
        drawNav();
        if(engine.reminderReady)chrome.status("Ready to repost - posting remains manual.",1);
        if(engine.status.indexOf("settings")>=0||engine.status.indexOf("Settings")>=0)chrome.status(engine.status,1);
        chrome.gap(4);
        switch(activeTab){case 0:browse.draw();case 1:post.draw();case 2:settings.draw();case 3:messenger.draw();case 4:people.draw();}
        drawQuickInvite();drawLeavePrompt();drawInfoPopups();
    }

    // ---- navigation row --------------------------------------------------------------------------

    function drawNav():Void {
        var scale=engine.config.textScale;navSize.x=Math.max(84,96*scale);navSize.y=Math.max(28,30*scale);
        ImGui.getContentRegionAvail(navAvailable);var startX=ImGui.getCursorPosX();
        var logoWidth=drawLogo(scale);
        if(navAvailable.x<560*scale){
            tabChoice.set(navOrder.indexOf(activeTab));ImGui.setNextItemWidth(180*scale);
            if(Scope.choice("##mainNavigation",tabChoice,navNames))activate(navOrder[tabChoice.get()]);
        }else for(i in 0...navOrder.length){
            if(i>0)ImGui.sameLine(0,6);
            var tab=navOrder[i];
            if(UiChrome.navButton(tab==3?messageLabel:navLabels[i],activeTab==tab,navSize))activate(tab);
        }
        ImGui.sameLine(0,6);
        if(UiChrome.ghostButton("Boss loot###navLoot",navSize))openLoot();
        // The strip shares the row only when it fits to the right of the last chip; otherwise it takes its own right-aligned row.
        var chips=navOrder.length+1;
        var used=logoWidth+(navAvailable.x<560*scale?180*scale+6+navSize.x:chips*navSize.x+(chips-1)*6);
        var stripWidth=strip.width(scale);var target=startX+navAvailable.x-stripWidth+6;
        if(target>startX+used+16)ImGui.sameLine(target);
        else{chrome.gap(6);ImGui.setCursorPosX(Math.max(startX+8,target));}
        strip.draw(navSize.y+6);
    }
    /** Right-click on the title bar, menu bar or any empty space opens a short window menu; rows and fields keep their own menus. */
    function openWindowMenu():Void {
        if(!KeyCapture.listening&&!Scope.cancelPopups&&ImGui.isWindowHovered(imgui.Enums.ImGuiHoveredFlags.RootAndChildWindows)&&!ImGui.isAnyItemHovered()&&ImGui.isMouseClicked(1,false))ImGui.openPopup("##windowMenu");
        simplelfg.ContextMenuSystem.draw("##windowMenu",windowMenuBody);
    }
    function drawWindowMenu():Void {
        var c=engine.config;
        if(MenuKit.item("Fit to design proportions"))fitDesign();
        if(MenuKit.item("Reset size and position"))settings.resetGeometry=true;
        ImGui.separator();
        if(MenuKit.item("Close window",KeyBinding.label(c.panelKey,c.panelMods)))open.set(false);
    }
    /** Keeps the current width where the screen allows and restores the designed 1180:740 shape. */
    function fitDesign():Void {
        var fit=Geometry.designFit(measured.x>0?measured.x:engine.config.width,maximum.x,maximum.y,minimum.x,minimum.y);
        engine.config.width=fit.w;engine.config.height=fit.h;size.x=fit.w;size.y=fit.h;nextSize=true;engine.markDirty(now);
    }
    /** Transparent wordmark at the left of the tab row; click for About. Skipped when the window is small, so tabs keep their room. */
    function drawLogo(scale:Float):Float {
        var tex=artwork.textures[LauncherArt.WORDMARK];
        if(!engine.config.showLogo||tex==(0:hl.I64)||navAvailable.x<760*scale||measured.y<560)return 0;
        logoSize.y=54*scale;logoSize.x=logoSize.y*artwork.widths[LauncherArt.WORDMARK]/artwork.heights[LauncherArt.WORDMARK];
        ImGui.getCursorPos(logoPos);
        ImGui.image(tex,logoSize,uv0,uv1);
        if(ImGui.isItemClicked(0))aboutPrompt=true;
        ImGui.sameLine(0,14);ImGui.setCursorPosY(logoPos.y+(logoSize.y-navSize.y)*0.5);
        return logoSize.x+14;
    }
    function openLoot():Void {loot.openForTargets(browse.selectedTargets());lootOpen.set(true);lootNextSize=true;}
    /** Ctrl+1..5 switch pages. Only while this window has focus and nothing is being typed. */
    function pollShortcuts():Void {
        if(KeyCapture.listening||!ImGui.isWindowFocused(imgui.Enums.ImGuiFocusedFlags.RootAndChildWindows)||ImGui.isAnyItemActive())return;
        if(!ImGui.isKeyDown(ImGuiKey.LeftCtrl)&&!ImGui.isKeyDown(ImGuiKey.RightCtrl))return;
        for(i in 0...navOrder.length)if(ImGui.isKeyPressed(ImGuiKey._1+i,false)){activate(navOrder[i]);return;}
    }

    // ---- menu bar --------------------------------------------------------------------------------

    function drawMenus():Void {
        MenuKit.menu("File",fileBody);MenuKit.menu("View",viewBody);MenuKit.menu("Party",partyBody);MenuKit.menu("Help",helpBody);
        var live=engine.relay.sessionId!="";
        var text=(engine.state.cursorFree?"":"Pointer locked: free the cursor to click   ")+(live?"Relay connected":(StringTools.startsWith(engine.relayStatus,"Cross-server listings connected")?"Relay: listings only, no messaging session":"Relay offline"))+"   "+KeyBinding.label(engine.config.panelKey,engine.config.panelMods);
        ImGui.calcTextSize(text,false,-1,navText);
        ImGui.getContentRegionAvail(navAvailable);
        if(navAvailable.x>navText.x+16){
            ImGui.setCursorPosX(ImGui.getCursorPosX()+navAvailable.x-navText.x-8);
            ImGui.textColored(ThemePalette.status(engine.state.cursorFree&&engine.relay.sessionId!=""?ThemePalette.STATUS_SUCCESS:ThemePalette.STATUS_WARN),text);
        }
    }
    function drawFileMenu():Void {
        var c=engine.config;
        if(MenuKit.item("New listing...","Ctrl+2"))activate(1);
        if(MenuKit.item("Save post as template","",false,c.draft.activity!=""&&c.templates.length<5))engine.saveTemplate(now);
        ImGui.separator();
        if(MenuKit.item("Fit window to design proportions"))fitDesign();
        if(MenuKit.item("Reset window size and position"))settings.resetGeometry=true;
        ImGui.separator();
        if(MenuKit.item("Close",KeyBinding.label(c.panelKey,c.panelMods)))open.set(false);
    }
    function drawViewMenu():Void {
        for(i in 0...navOrder.length)if(MenuKit.item(navNames[i],"Ctrl+"+(i+1),activeTab==navOrder[i]))activate(navOrder[i]);
        ImGui.separator();
        if(MenuKit.item("Boss loot window"))openLoot();
        ImGui.separator();
        if(MenuKit.item("Show logo","",engine.config.showLogo)){engine.config.showLogo=!engine.config.showLogo;engine.markDirty(now);}
        MenuKit.menu("Text size",textSizeBody);MenuKit.menu("Theme",themeBody);
    }
    function drawTextSizeMenu():Void {
        for(i in 0...scales.length)if(MenuKit.item(scaleNames[i],"",Math.abs(engine.config.textScale-scales[i])<0.01)){engine.config.textScale=scales[i];engine.markDirty(now);}
    }
    function drawThemeMenu():Void {
        var c=engine.config;
        for(name in themeNames)if(MenuKit.item(name,"",c.theme==name&&!c.highContrast)){Palette.preset(c,name);c.highContrast=false;engine.markDirty(now);}
        ImGui.separator();
        if(MenuKit.item("High contrast","",c.highContrast)){c.highContrast=!c.highContrast;engine.markDirty(now);}
    }
    function drawPartyMenu():Void {
        partyMenuWanted=true;
        var p=engine.social.party;
        MenuKit.item(strip.summary(),"",false,false);
        ImGui.separator();
        if(MenuKit.item("Leave party...","",false,p.canLeave))leavePrompt=true;
        MenuKit.menu("Invite to party",inviteBody,p.canInvite);
        ImGui.separator();
        if(MenuKit.item("Copy my friend code","",false,engine.social.code!=""))UiActionQueue.copy(engine.social.code);
        if(MenuKit.item("Add friend by code..."))activate(4);
        if(MenuKit.item("Friends and party"))activate(4);
    }
    function drawInviteMenu():Void drawInviteChoices();
    /** Nearby friends first (they share your realm), then friends elsewhere with their zone, then other nearby players. */
    function drawInviteChoices():Void {
        var shown=inviteSection("Nearby friends",0)+inviteSection("Friends elsewhere",1)+inviteSection("Nearby players",2);
        if(shown==0)MenuKit.item("Nobody online to invite",null,false,false);
    }
    function inviteSection(title:String,kind:Int):Int {
        var count=0;
        for(person in engine.social.people){
            if(!person.online||inPartyUid(person.uid))continue;
            var match=kind==0?person.friend&&person.realm:(kind==1?person.friend&&!person.realm:!person.friend&&person.realm);
            if(!match)continue;
            if(count==0)ImGui.separatorText(title);
            if(count++>=12)break;
            if(MenuKit.item(person.name+"##invite_"+person.uid,kind==1&&person.detail!=null?person.detail:""))engine.enqueue(engine.socialAction("invite",person.uid,person.name));
        }
        return count>12?12:count;
    }
    function drawQuickInvite():Void {
        if(quickInvite){quickInvite=false;ImGui.openPopup("##quickInvite");}
        if(!ImGui.beginPopup("##quickInvite"))return;
        var error:Dynamic=null;
        try {if(Scope.cancelPopups)ImGui.closeCurrentPopup();else{partyMenuWanted=true;chrome.subHeader("Invite to party");drawInviteChoices();}}catch(e:Dynamic)error=e;
        ImGui.endPopup();if(error!=null)throw error;
    }
    function inPartyUid(uid:String):Bool {for(m in engine.social.party.members)if(m.uid==uid)return true;return false;}
    function drawHelpMenu():Void {
        if(MenuKit.item("Keyboard shortcuts"))shortcutsPrompt=true;
        if(MenuKit.item("About SimpleLFG"))aboutPrompt=true;
    }

    // ---- popups ----------------------------------------------------------------------------------

    function drawLeavePrompt():Void {
        if(leavePrompt){leavePrompt=false;ImGui.openPopup("Leave party?###leavePrompt");}
        if(!ImGui.beginPopupModal("Leave party?###leavePrompt",null,ImGuiWindowFlags.AlwaysAutoResize|ImGuiWindowFlags.NoSavedSettings))return;
        var error:Dynamic=null;try {if(Scope.cancelPopups)ImGui.closeCurrentPopup();else leaveBody();}catch(e:Dynamic)error=e;
        ImGui.endPopup();if(error!=null)throw error;
    }
    function drawLeaveBody():Void {
        chrome.note("Leave your current party? You can be invited back, but the leader has to do it.",false);
        chrome.gap(8);
        if(chrome.button("Leave party###confirmLeaveParty",true,120)){engine.enqueue(engine.socialAction("leaveParty"));ImGui.closeCurrentPopup();}
        ImGui.sameLine(0,8);if(chrome.button("Stay###cancelLeaveParty",false,120))ImGui.closeCurrentPopup();
    }
    function drawInfoPopups():Void {
        if(shortcutsPrompt){shortcutsPrompt=false;ImGui.openPopup("Keyboard shortcuts###shortcuts");}
        if(aboutPrompt){aboutPrompt=false;ImGui.openPopup("About###about");}
        if(ImGui.beginPopup("Keyboard shortcuts###shortcuts")){
            var error:Dynamic=null;try {if(Scope.cancelPopups)ImGui.closeCurrentPopup();else shortcutsBody();}catch(e:Dynamic)error=e;
            ImGui.endPopup();if(error!=null)throw error;
        }
        if(ImGui.beginPopup("About###about")){
            var error:Dynamic=null;try {if(Scope.cancelPopups)ImGui.closeCurrentPopup();else aboutBody();}catch(e:Dynamic)error=e;
            ImGui.endPopup();if(error!=null)throw error;
        }
    }
    function drawShortcutsBody():Void {
        chrome.subHeader("Keyboard shortcuts");
        Scope.properties("##shortcutRows",drawShortcutRows);
    }
    function drawShortcutRows():Void {
        var c=engine.config;
        shortcutRow("Open or close SimpleLFG",KeyBinding.label(c.panelKey,c.panelMods));
        shortcutRow("Switch page","Ctrl+1 to Ctrl+5");
        shortcutRow("Search listings","Ctrl+F");
        shortcutRow("Move selection","Up / Down");
        shortcutRow("Whisper selected","Enter");
        shortcutRow("Hide selected listing","Delete");
        shortcutRow("Close menu or popup","Esc");
    }
    function shortcutRow(action:String,keys:String):Void {Scope.row(action);ImGui.textUnformatted(keys);}
    function drawAboutBody():Void {
        var wordmark=artwork.textures[LauncherArt.WORDMARK];
        if(wordmark!=(0:hl.I64)){logoSize.x=180;logoSize.y=180*artwork.heights[LauncherArt.WORDMARK]/artwork.widths[LauncherArt.WORDMARK];ImGui.image(wordmark,logoSize,uv0,uv1);}
        chrome.subHeader(VERSION);
        chrome.note("Recruiting board, private messages and Farever friend and party tools.",false);
        chrome.note(engine.relayStatus,false);
        chrome.note("Posting, whispering and every social request stay manual; the other player always accepts.",false);
    }

    // ---- other windows ---------------------------------------------------------------------------

    function drawLootWindow():Void {
        lootMinimum.x=Math.min(640,maximum.x);lootMinimum.y=Math.min(420,maximum.y);
        if(lootNextSize){
            lootSize.x=Math.min(820,maximum.x);lootSize.y=Math.min(620,maximum.y);
            lootPosition.x=Math.max(0,Math.min(maximum.x-lootSize.x,position.x+size.x+12));
            lootPosition.y=Math.max(0,Math.min(maximum.y-lootSize.y,position.y));
            ImGui.setNextWindowPos(lootPosition,ImGuiCond.Always);ImGui.setNextWindowSize(lootSize,ImGuiCond.Always);lootNextSize=false;
        }
        ImGui.setNextWindowSizeConstraints(lootMinimum,maximum);
        UiChrome.pushCelShade();
        var shown=ImGui.begin("Boss loot###SimpleLFG.Loot",lootOpen,ImGuiWindowFlags.NoSavedSettings|ImGuiWindowFlags.NoCollapse|(engine.state.cursorFree?0:ImGuiWindowFlags.NoInputs));
        ImGui.beginDisabled(!engine.state.cursorFree);
        var error:Dynamic=null;
        try {if(shown){ImGui.getWindowSize(lootSize);ImGui.getWindowPos(lootPosition);loot.draw();}}catch(e:Dynamic)error=e;
        ImGui.endDisabled();ImGui.end();UiChrome.popCelShade();if(error!=null)throw error;
    }
    function drawToast():Void {
        if(!engine.state.available||now>=engine.alerts.toastUntil)return;
        toastSize.x=Math.min(390,screenW-24);toastSize.y=164*engine.config.textScale;
        toastPosition.x=Math.max(0,screenW-toastSize.x-20);toastPosition.y=Math.max(0,screenH-toastSize.y-110);
        ImGui.setNextWindowPos(toastPosition);ImGui.setNextWindowSize(toastSize);
        var flags=ImGuiWindowFlags.NoTitleBar|ImGuiWindowFlags.NoResize|ImGuiWindowFlags.NoMove|ImGuiWindowFlags.NoSavedSettings|ImGuiWindowFlags.NoFocusOnAppearing;
        if(!engine.state.cursorFree)flags|=ImGuiWindowFlags.NoInputs;
        ImGui.pushStyleColor(ImGuiCol.WindowBg,palette.title);
        var shown=ImGui.begin("##SimpleLFG.Alert",null,flags);var error:Dynamic=null;
        try if(shown){
            chrome.status(engine.alerts.title,3);Scope.wrapped(engine.alerts.body);
            if(engine.state.cursorFree&&chrome.button("View group##viewAlert")){open.set(true);forceBrowse=true;browse.view(engine.alerts.listingKey);engine.alerts.acknowledge();}
        }catch(e:Dynamic)error=e;
        ImGui.end();ImGui.popStyleColor();if(error!=null)throw error;
    }
}
