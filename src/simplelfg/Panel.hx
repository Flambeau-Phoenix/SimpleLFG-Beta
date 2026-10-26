package simplelfg;

import imgui.ImGui;
import imgui.Structs.ImVec2;
import imgui.Enums.ImGuiKey;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Enums.ImGuiCond;
import imgui.ref.BoolRef;

/** Window lifetime, geometry and shared-style scope; workspaces own their editors. */
class Panel {
    var engine:Engine;var native:NativeChat;
    var palette=new Palette();var input=new InputController();var chrome:Chrome;
    var artwork=new LauncherArt();
    var browse:BrowsePanel;var post:PostPanel;var loot:LootPanel;var settings:SettingsPanel;var launcher:Launcher;
    var sidebar:SidebarGeometry;var messenger:MessengerPanel;var messageLabel="Messages##messages";
    var lootOpen=new BoolRef(false);var lootNextSize=true;var lootSize=new ImVec2(820,620);var lootPosition=new ImVec2();
    var lootMinimum=new ImVec2(640,420);
    var navAvailable=new ImVec2();var navText=new ImVec2();
    var open=new BoolRef(false);var forceBrowse=false;var nextSize=true;var now:Float=0;
    var size=new ImVec2();var position=new ImVec2();var measured=new ImVec2();var measuredPosition=new ImVec2();
    var minimum=new ImVec2(520,360);var maximum=new ImVec2(1800,1200);
    var toastPosition=new ImVec2();var toastSize=new ImVec2(350,150);
    var screenW:Float=0;var screenH:Float=0;
    var activeTab:Int=0;
    public function new(engine:Engine,native:NativeChat){
        this.engine=engine;this.native=native;chrome=new Chrome(palette);
        browse=new BrowsePanel(engine,chrome);post=new PostPanel(engine,chrome);loot=new LootPanel(chrome,engine.config);
        messenger=new MessengerPanel(engine,chrome);settings=new SettingsPanel(engine,chrome);launcher=new Launcher(engine,artwork);
        sidebar=new SidebarGeometry(engine.config.width);
        size.x=engine.config.width;size.y=engine.config.height;
    }
    public function observe(time:Float):Void {
        engine.relayVisible=open.get();
        now=time;palette.observe(engine.config);
        maximum.x=Math.max(1,native.screenWidth);maximum.y=Math.max(1,native.screenHeight);
        minimum.x=Math.min(520,maximum.x);minimum.y=Math.min(360,maximum.y);
        if(engine.config.migrated){
            engine.config.width=Geometry.clamp(engine.config.width,minimum.x,maximum.x);engine.config.height=Geometry.clamp(engine.config.height,minimum.y,maximum.y);
            engine.config.windowX=Geometry.x(engine.config,native.screenWidth);engine.config.windowY=Geometry.y(engine.config,native.screenHeight);
            engine.config.migrated=false;engine.markDirty(now);
        }
        if(screenW!=native.screenWidth||screenH!=native.screenHeight){screenW=native.screenWidth;screenH=native.screenHeight;nextSize=true;size.x=engine.config.width;size.y=engine.config.height;}
        if(settings.resetGeometry){settings.resetGeometry=false;browse.clear();sidebar=new SidebarGeometry(engine.config.width);nextSize=true;size.x=engine.config.width;size.y=engine.config.height;}
        if(engine.sessionChanged||!engine.state.available){if(open.get()||lootOpen.get())close(true);}
        if(engine.sessionChanged){browse.clear();post.clear();settings.clear();messenger.clear();}
        if(engine.requestedRelayPeer!=""){activeTab=3;open.set(true);}
        messenger.observe();if(open.get()&&activeTab==3)engine.relayMessages.read();
        messageLabel=engine.relayMessages.unread>0?"Messages ("+engine.relayMessages.unread+")##messages":"Messages##messages";
        browse.observe(time,open.get()&&activeTab==0);post.observe(time);loot.observe(lootOpen.get());settings.observe(time);launcher.observe(time,screenW,screenH);
        if(engine.alerts.soundRequested){if(engine.state.available)input.playSound();engine.alerts.soundRequested=false;}
        input.observe(engine.state.available,engine.state.cursorFree,open.get()||lootOpen.get()||engine.config.launcherEnabled||now<engine.alerts.toastUntil,now);
        if(sidebar.update(open.get()&&activeTab==0&&browse.hasSelection(),maximum.x,engine.config.textScale)){size.x=sidebar.width;nextSize=true;}
        size.x=sidebar.width;size.y=engine.config.height;
    }
    function close(allWindows:Bool=false):Void {open.set(false);Scope.cancelPopups=true;browse.clear();post.clear();settings.clear();if(allWindows){lootOpen.set(false);loot.clearTransientState();}}
    function activate(tab:Int):Void {if(activeTab!=tab){activeTab=tab;post.clear();settings.cancelConfirm();}}

    function toggle():Void {if(open.get()||lootOpen.get())close(true);else{open.set(true);engine.alerts.acknowledge();}}
    public function draw():Void {
        palette.push();ImGui.pushFont(ImGui.getFont(),16*engine.config.textScale);var failure:Dynamic=null;
        try {
            if(engine.state.available&&ImGui.isKeyPressed(ImGuiKey.F5,false))toggle();
            if(launcher.draw())toggle();drawToast();
            if(open.get()){drawMain();if(!open.get())close();else Scope.cancelPopups=false;}
            if(lootOpen.get()){drawLootWindow();if(!lootOpen.get())loot.clearTransientState();Scope.cancelPopups=false;}
        }catch(e:Dynamic)failure=e;
        ImGui.popFont();palette.pop();if(failure!=null)throw failure;
    }
    function drawMain():Void {
        if(nextSize){
            size.x=Geometry.clamp(size.x,minimum.x,maximum.x);size.y=Geometry.clamp(size.y,minimum.y,maximum.y);
            position.x=Geometry.clamp(engine.config.windowX<0?(screenW-size.x)*0.5:engine.config.windowX,0,screenW-size.x);position.y=Geometry.clamp(engine.config.windowY<0?(screenH-size.y)*0.5:engine.config.windowY,0,screenH-size.y);
            ImGui.setNextWindowPos(position,ImGuiCond.Always);ImGui.setNextWindowSize(size,ImGuiCond.Always);nextSize=false;
        }
        ImGui.setNextWindowSizeConstraints(minimum,maximum);
        var shown=ImGui.begin("SimpleLFG###SimpleLFG.Main",open,ImGuiWindowFlags.NoSavedSettings|ImGuiWindowFlags.NoCollapse|(engine.state.cursorFree?0:ImGuiWindowFlags.NoInputs));
        ImGui.beginDisabled(!engine.state.cursorFree);
        var error:Dynamic=null;try if(shown)drawBody() catch(e:Dynamic)error=e;
        ImGui.endDisabled();ImGui.end();if(error!=null)throw error;
    }
    function drawBody():Void {
        ImGui.getWindowSize(measured);ImGui.getWindowPos(measuredPosition);
        var changed=false;
        if(Math.abs(measured.x-sidebar.width)>1){sidebar.resize(measured.x);engine.config.width=sidebar.baseWidth;size.x=measured.x;changed=true;}
        if(Math.abs(measured.y-engine.config.height)>1){engine.config.height=measured.y;changed=true;}
        if(Math.abs(measuredPosition.x-position.x)>1||Math.abs(measuredPosition.y-position.y)>1){engine.config.windowX=measuredPosition.x;engine.config.windowY=measuredPosition.y;changed=true;}
        position.x=measuredPosition.x;position.y=measuredPosition.y;
        if(changed)engine.markDirty(now);
        if(forceBrowse){activate(0);forceBrowse=false;}
        ImGui.getContentRegionAvail(navAvailable);var startX=ImGui.getCursorPosX();
        if(chrome.nav("Browse##browse",activeTab==0))activate(0);
        ImGui.sameLine();if(chrome.nav("Post##post",activeTab==1))activate(1);
        ImGui.sameLine();if(chrome.nav("Settings##settings",activeTab==2))activate(2);
        ImGui.sameLine();if(chrome.nav(messageLabel,activeTab==3))activate(3);
        ImGui.calcTextSize("Boss loot",false,-1,navText);
        ImGui.sameLine(Math.max(ImGui.getCursorPosX()+8,startX+navAvailable.x-navText.x-20));
        if(chrome.button("Boss loot##loot")){
            loot.openForTargets(browse.selectedTargets());lootOpen.set(true);lootNextSize=true;
        }
        if(engine.reminderReady)chrome.status("Ready to repost - posting remains manual.",1);
        if(engine.status.indexOf("settings")>=0||engine.status.indexOf("Settings")>=0)chrome.status(engine.status,1);
        chrome.gap(8);
        switch(activeTab){case 0:browse.draw();case 1:post.draw();case 2:settings.draw();case 3:messenger.draw();}
    }
    function drawLootWindow():Void {
        lootMinimum.x=Math.min(640,maximum.x);lootMinimum.y=Math.min(420,maximum.y);
        if(lootNextSize){
            lootSize.x=Math.min(820,maximum.x);lootSize.y=Math.min(620,maximum.y);
            lootPosition.x=Math.max(0,Math.min(maximum.x-lootSize.x,position.x+size.x+12));
            lootPosition.y=Math.max(0,Math.min(maximum.y-lootSize.y,position.y));
            ImGui.setNextWindowPos(lootPosition,ImGuiCond.Always);ImGui.setNextWindowSize(lootSize,ImGuiCond.Always);lootNextSize=false;
        }
        ImGui.setNextWindowSizeConstraints(lootMinimum,maximum);
        var shown=ImGui.begin("Boss loot###SimpleLFG.Loot",lootOpen,ImGuiWindowFlags.NoSavedSettings|ImGuiWindowFlags.NoCollapse|(engine.state.cursorFree?0:ImGuiWindowFlags.NoInputs));
        ImGui.beginDisabled(!engine.state.cursorFree);
        var error:Dynamic=null;
        try {if(shown){ImGui.getWindowSize(lootSize);ImGui.getWindowPos(lootPosition);loot.draw();}}catch(e:Dynamic)error=e;
        ImGui.endDisabled();ImGui.end();if(error!=null)throw error;
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
