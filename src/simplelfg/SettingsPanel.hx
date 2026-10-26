package simplelfg;

import imgui.ImGui;
import imgui.ref.BoolRef;
import imgui.ref.IntRef;
import imgui.ref.FloatRef;
import imgui.Structs.ImVec2;
import simplelfg.UiState.Confirmation;
import simplelfg.ui.NumberField;

private class SettingsRow {
    public var id:String;public var text:String;public var copyText:String;
    public function new(id:String,text:String,?value:String){this.id=id;this.text=text;copyText=value==null?text:value;}
}
class SettingsPanel {
    var engine:Engine;var chrome:Chrome;var workspace:Workspace;
    var category=new IntRef(0);var categories=["General##general","Privacy##privacy","Alerts##alerts","Filters##filters","Appearance##theme"];
    var categoryNames=["General","Privacy and contacts","Alerts","Filters","Appearance"];
    var phraseKinds=["LFG phrases","LFM phrases","Run / boss context","Excluded phrases","Target aliases"];
    var key=new IntRef(5);var expiry=new IntRef(5);var scale=new FloatRef(1);var opacity=new FloatRef(1);
    var channels:Array<BoolRef>=[for(_ in ChannelPolicy.names)new BoolRef()];var contrast=new BoolRef();var launcher=new BoolRef();var quickLeave=new BoolRef();var requireContext=new BoolRef();
    var alerts=new BoolRef();var sound=new BoolRef();
    var steamId=new TextBuffer(33);var relayEnabled=new BoolRef();var shareSteam=new BoolRef();
    var shareConfirmation=false;
    var fareverCode=new TextBuffer(64);var shareFarever=new BoolRef();var fareverConfirmation=false;
    var word=new TextBuffer(96);var wordKind=new IntRef(0);var watchCustom=new TextBuffer(128);var activities=new ActivityChoices();
    var colorBuffers:Array<hl.Bytes>=[];var colorNames=["Accent","Window","Panel","Text"];var colorIds=["accent","window","panel","text"];
    var presets=["Midnight","Slate","Warm","Custom"];var presetChoice=new IntRef(0);var confirm=new Confirmation();
    var words:Array<SettingsRow>=[];var watches:Array<SettingsRow>=[];var knownWatches:Map<String,BoolRef>=new Map();
    var ignored:Array<SettingsRow>=[];var newPhrase:Bool=false;var restoreWords:Bool=false;var addWatch:Bool=false;
    var aliasTarget=new IntRef(0);var aliasChoicesBody:Void->Void;var requestedAliasTarget:Int=0;var phraseSearch=new TextBuffer(96);var targetNames:String="";var pendingMerge=false;var pendingCopy:String=null;var selectedPhrase:String="";
    var requestedPhrase:String="";var requestedKind:Int=0;var requestedWatch:String="";
    var pending=true;var revision=-1;var now:Float=0;
    var propertyBody:Void->Void;var privacyBody:Void->Void;
    var available=new ImVec2();
    public var resetGeometry=false;
    public var listeningForKey(default,null)=false;
    public var keyWarning="";
    var keyIndex=new IntRef(0);var keyMods=new IntRef(0);var startCapture=false;
    var modChoices=["No modifier","Ctrl","Shift","Ctrl+Shift","Alt","Ctrl+Alt","Shift+Alt","Ctrl+Shift+Alt"];
    public function new(engine:Engine,chrome:Chrome){
        this.engine=engine;this.chrome=chrome;
        workspace=new Workspace(chrome,"##Settings",drawControls,drawCompanion,480,380);
        aliasChoicesBody=drawAliasChoices;propertyBody=drawProperties;privacyBody=drawPrivacyProperties;
        for(i in 0...4)colorBuffers.push(new hl.Bytes(16));for(a in Catalogue.items)knownWatches.set(a.id,new BoolRef());
    }
    public function clear():Void {confirm.clear();word.set("");watchCustom.set("");shareConfirmation=false;fareverConfirmation=false;}
    public function cancelConfirm():Void {confirm.clear();shareConfirmation=false;fareverConfirmation=false;}
    public function observe(time:Float):Void {
        now=time;activities.observe();var c=engine.config;
        if(startCapture){startCapture=false;KeyCapture.begin();}
        if(KeyCapture.listening&&KeyCapture.poll()){c.panelKey=KeyCapture.resultName;c.panelMods=KeyCapture.resultMods;changed();}
        listeningForKey=KeyCapture.listening;
        // Collection mutations and default construction run on explicit requests in service.
        if(newPhrase){newPhrase=false;var s=requestedPhrase;if(requestedKind==4){if(s!=""&&c.targetAliases.length<512&&Catalogue.items.length>0){var target=Catalogue.items[Std.int(Geometry.clamp(requestedAliasTarget,0,Catalogue.items.length-1))];var duplicate=false;for(a in c.targetAliases)if(a.targetId==target.id&&a.phrase.toLowerCase()==s.toLowerCase())duplicate=true;if(!duplicate){c.targetAliases.push({targetId:target.id,name:target.name,phrase:s});word.set("");changed();}}}else{var list=requestedKind==0?c.lfgWords:(requestedKind==1?c.lfmWords:(requestedKind==2?c.contextWords:c.excludedWords));if(s!=""&&list.length<256&&[for(x in list)x.toLowerCase()].indexOf(s.toLowerCase())<0){list.push(s);word.set("");changed();}}}
        if(restoreWords){restoreWords=false;var defaults=new Config();c.lfgWords=defaults.lfgWords;c.lfmWords=defaults.lfmWords;c.contextWords=defaults.contextWords;c.excludedWords=defaults.excludedWords;c.targetAliases=defaults.targetAliases;changed();}
        if(pendingMerge){pendingMerge=false;c.mergeDefaults();changed();}
        if(pendingCopy!=null){ImGui.setClipboardText(pendingCopy);pendingCopy=null;}
        if(addWatch){addWatch=false;var target=requestedWatch;var id="custom:"+target;if(target!=""&&c.watchActivities.length<64&&c.watchActivities.indexOf(id)<0){c.watchActivities.push(id);watchCustom.set("");changed();}}
        if(!pending&&revision==engine.settingsRevision)return;pending=false;revision=engine.settingsRevision;
        key.set(c.hotkey);keyIndex.set(Std.int(Math.max(0,KeyBinding.indexOf(c.panelKey))));keyMods.set(c.panelMods);expiry.set(Std.int(c.expirySeconds/60));scale.set(c.textScale);opacity.set(c.opacity);for(i in 0...channels.length)channels[i].set(ChannelPolicy.enabled(c,ChannelPolicy.names[i]));requireContext.set(c.requireRecruitingContext);contrast.set(c.highContrast);
        steamId.set(c.steamId);relayEnabled.set(c.relayEnabled);shareSteam.set(c.shareSteamPublic);
        fareverCode.set(c.fareverOwner==engine.state.playerId?c.fareverCode:"");shareFarever.set(c.shareFareverPublic);
        launcher.set(c.launcherEnabled);quickLeave.set(c.quickLeaveChip);alerts.set(c.alertsEnabled);sound.set(c.alertSound);presetChoice.set(presets.indexOf(c.theme));
        for(i in 0...4){var value=i==0?c.accent:(i==1?c.background:(i==2?c.surface:c.foreground));var b=colorBuffers[i];b.setF32(0,((value>>16)&255)/255);b.setF32(4,((value>>8)&255)/255);b.setF32(8,(value&255)/255);}
        if(wordKind.get()==4)words=[for(a in c.targetAliases)new SettingsRow("alias_"+haxe.crypto.Sha256.encode(a.targetId+"/"+a.phrase),a.phrase+" -> "+a.name,a.phrase)];
        else words=[for(s in phraseList())new SettingsRow("phrase_"+wordKind.get()+"_"+haxe.crypto.Sha256.encode(s),s)];
        var query=phraseSearch.get().toLowerCase();if(query!="")words=[for(row in words)if(row.text.toLowerCase().indexOf(query)>=0)row];
        watches=[];for(id in c.watchActivities){var label=id;for(a in Catalogue.items)if(a.id==id)label=a.name;if(StringTools.startsWith(id,"custom:"))label=id.substr(7);watches.push(new SettingsRow(id,label));}
        ignored=[for(r in c.ignored)new SettingsRow(r.id,r.name+(r.until==0?" (permanent)":" (timed)"))];
        for(a in Catalogue.items)knownWatches.get(a.id).set(c.watchActivities.indexOf(a.id)>=0);
    }
    function phraseList():Array<String> return wordKind.get()==0?engine.config.lfgWords:(wordKind.get()==1?engine.config.lfmWords:(wordKind.get()==2?engine.config.contextWords:engine.config.excludedWords));
    function changed():Void engine.markDirty(now);
    function chooseCategory(i:Int):Void {if(category.get()!=i){category.set(i);confirm.clear();}}
    public function draw():Void {
        ImGui.getContentRegionAvail(available);
        if(available.x>=900*engine.config.textScale){for(i in 0...categories.length){if(i>0)ImGui.sameLine();if(chrome.nav(categories[i],category.get()==i))chooseCategory(i);}}
        else{ImGui.setNextItemWidth(200);var old=category.get();if(Scope.choice("##settingsCategory",category,categoryNames)&&old!=category.get())confirm.clear();}
        chrome.gap(8);workspace.draw(engine.config.textScale);
    }
    function drawControls():Void {
        switch(category.get()){
            case 0:chrome.header("General");Scope.properties("##generalProperties",propertyBody);
                chrome.gap();if(chrome.confirm("Reset window###confirm",confirm,"resetWindow")){var c=engine.config;c.windowX=-1;c.windowY=-1;c.width=1180;c.height=740;resetGeometry=true;changed();}
                chrome.note("Your draft, templates, ignored players and contacts are saved automatically.");
            case 1:chrome.header("Privacy and contacts");Scope.properties("##privacyProperties",privacyBody);
                if(shareConfirmation){
                    chrome.note("Sharing makes your Steam code visible on public listings. You can whisper people or use private messages instead; no Steam code is required.");
                    if(chrome.disabledButton("Share publicly##confirmSteamSharing",!SteamContact.valid(engine.config.steamId))){engine.config.shareSteamPublic=true;shareSteam.set(true);shareConfirmation=false;changed();}
                    if(chrome.button("Keep private##cancelSteamSharing"))shareConfirmation=false;
                }
                if(fareverConfirmation){
                    chrome.note("Sharing makes your Farever code public on cross-server listings. Private sharing is available in Messages.");
                    if(chrome.disabledButton("Share Farever publicly##confirmFarever",engine.social.code=="")){engine.config.shareFareverPublic=true;engine.config.fareverOwner=engine.state.playerId;shareFarever.set(true);fareverConfirmation=false;changed();}
                    if(chrome.button("Keep Farever private##cancelFarever"))fareverConfirmation=false;
                }
                chrome.note("Cross-server posts are public. Select Cross-server in Post to publish; local posts stay in game chat. Private messages use an automatically issued session.");
            case 4:chrome.header("Appearance");Scope.properties("##themeProperties",propertyBody);
                chrome.gap();if(chrome.confirm("Reset theme###confirm",confirm,"resetTheme")){Palette.preset(engine.config,"Midnight");engine.config.textScale=1;engine.config.opacity=1;engine.config.highContrast=false;changed();}
            case 3:drawPhrases();
            case 2:chrome.header("Watched targets");Scope.properties("##alertProperties",propertyBody);chrome.gap();
                if(watches.length==0)chrome.empty("No watched activities. Choose catalogue entries or add a custom target.");
                for(row in watches){var remove=chrome.actionRow(row.text,confirm.target==row.id?"Confirm?###remove":"Remove###remove",row.id);if(remove&&confirm.press(row.id)){engine.config.watchActivities.remove(row.id);changed();}}

        }
    }
    function drawProperties():Void {
        var c=engine.config;
        switch(category.get()){
            case 0:
                Scope.row("Panel key");drawKeyRow();
                Scope.row("Pick a key");drawKeyPicker();
                Scope.row("Leave-party chip");if(ImGui.checkbox("Show beside the LFG button while in a party##quickLeave",quickLeave)){c.quickLeaveChip=quickLeave.get();changed();}
                Scope.row("LFG button");if(ImGui.checkbox("Enable LFG button##launcher",launcher)){c.launcherEnabled=launcher.get();changed();}
                for(i in 0...channels.length){Scope.row(ChannelPolicy.names[i]);if(Scope.checkbox(ChannelPolicy.names[i],"Monitor",channels[i])){if(channels[i].get()){if(c.monitoredChannels.indexOf(ChannelPolicy.names[i])<0)c.monitoredChannels.push(ChannelPolicy.names[i]);}else c.monitoredChannels.remove(ChannelPolicy.names[i]);changed();}}
                Scope.row("Expiry (min)");if(ImGui.inputInt("##expiry",expiry)){c.expirySeconds=Std.int(Geometry.clamp(expiry.get(),1,30))*60;expiry.set(Std.int(c.expirySeconds/60));changed();}
            case 4:
                Scope.row("Preset");if(Scope.choice("##preset",presetChoice,presets)){var name=presets[presetChoice.get()];if(name=="Custom")c.theme=name;else Palette.preset(c,name);changed();}
                for(i in 0...4){Scope.row(colorNames[i]);var edit=Scope.color(colorIds[i],colorBuffers[i]);if(edit){var b=colorBuffers[i];var v=(Std.int(Geometry.clamp(b.getF32(0),0,1)*255)<<16)|(Std.int(Geometry.clamp(b.getF32(4),0,1)*255)<<8)|Std.int(Geometry.clamp(b.getF32(8),0,1)*255);switch(i){case 0:c.accent=v;case 1:c.background=v;case 2:c.surface=v;case 3:c.foreground=v;}c.theme="Custom";changed();}}
                Scope.row("Opacity");if(NumberField.draw("##opacity",opacity,0.65,1,"%.2f")){c.opacity=opacity.get();changed();}
                Scope.row("Text scale");if(NumberField.draw("##scale",scale,0.85,1.5,"%.2f")){c.textScale=scale.get();changed();}
                Scope.row("High contrast");if(ImGui.checkbox("Enabled##contrast",contrast)){c.highContrast=contrast.get();changed();}
            case 2:
                Scope.row("Group alerts");if(ImGui.checkbox("Enabled##alerts",alerts)){c.alertsEnabled=alerts.get();changed();}
                Scope.row("Sound");if(ImGui.checkbox("Enabled##sound",sound)){c.alertSound=sound.get();changed();}
            default:
        }
    }
    function drawPrivacyProperties():Void {
        var c=engine.config;
                Scope.row("Steam ID / Code");
                chrome.note("Steam contact (numeric; separate from Farever)");
                if(UiText.input("##steamId","Optional - Steam ID or Friend Code",steamId)){
                    c.steamId=Config.clean(steamId.get(),32);
                    shareConfirmation=false;c.shareSteamPublic=false;shareSteam.set(false);
                    changed();
                }
                Scope.row("Cross-server");if(ImGui.checkbox("Enable listings and messages##relayEnabled",relayEnabled)){c.relayEnabled=relayEnabled.get();changed();}
                Scope.row("Farever game code");Scope.wrapped(engine.social.gameCode==""?"Not available yet":engine.social.gameCode);
                Scope.row("Manual Farever code");if(UiText.input("##manualFarever","XXXX-XXXX-XXXX (optional)",fareverCode)){
                    c.fareverCode=Config.clean(fareverCode.get(),32);c.fareverOwner=engine.state.playerId;c.shareFareverPublic=false;fareverConfirmation=false;changed();
                }
                if(c.fareverCode!=""&&!FareverContact.valid(c.fareverCode))chrome.status("Farever codes contain 12 letters or digits.",1);
                Scope.row("Farever contact");if(chrome.button("Use game code##useGameCode")){c.fareverCode="";c.fareverOwner=engine.state.playerId;c.shareFareverPublic=false;fareverCode.set("");changed();}
                if(chrome.disabledButton("Copy Farever code##settingsCopyFarever",engine.social.code==""))pendingCopy=engine.social.code;
                Scope.row("Farever privacy");if(ImGui.checkbox("Show Farever code publicly##shareFarever",shareFarever)){
                    if(shareFarever.get()){shareFarever.set(false);fareverConfirmation=true;}else{c.shareFareverPublic=false;fareverConfirmation=false;changed();}
                }
                Scope.row("Steam privacy");if(ImGui.checkbox("Show code on public listings##shareSteam",shareSteam)){
                    if(shareSteam.get()){shareSteam.set(false);shareConfirmation=true;}
                    else{c.shareSteamPublic=false;shareConfirmation=false;changed();}
                }
                if(c.steamId!=""){
                    Scope.row("Steam contact");if(chrome.button("Copy Steam ID##copyMySteamId"))pendingCopy=c.steamId;
                    if(!SteamContact.valid(c.steamId))chrome.status("Use a numeric Steam ID or Friend Code (1-20 digits).",1);
                }
    }
    function drawKeyRow():Void {
        var c=engine.config;
        ImGui.alignTextToFramePadding();
        if(listeningForKey){chrome.status("Press a key or chord; Esc cancels",1);ImGui.sameLine(0,8);if(chrome.button("Cancel##cancelKeyCapture"))KeyCapture.cancel();return;}
        ImGui.textUnformatted(KeyBinding.label(c.panelKey,c.panelMods));
        ImGui.sameLine(0,10);if(chrome.button("Rebind##rebindKey"))startCapture=true;
        ImGui.sameLine(0,6);if(chrome.disabledButton("Reset to F5##resetKey",c.panelKey=="F5"&&c.panelMods==0)){c.panelKey="F5";c.panelMods=0;changed();}
        if(keyWarning!="")chrome.status(keyWarning,1);
    }
    function drawKeyPicker():Void {
        var names=KeyBinding.all();
        ImGui.setNextItemWidth(130);
        if(Scope.choice("##panelKeyName",keyIndex,names))applyKey(names[keyIndex.get()],keyMods.get());
        ImGui.sameLine(0,8);ImGui.setNextItemWidth(150);
        if(Scope.choice("##panelKeyMods",keyMods,modChoices))applyKey(names[keyIndex.get()],keyMods.get());
    }
    /** Menu index equals the saved modifier bits (Ctrl 1, Shift 2, Alt 4). Keys that would swallow typing need a modifier. */
    function applyKey(name:String,mods:Int):Void {
        var c=engine.config;
        if(KeyBinding.valid(name,mods)){c.panelKey=name;c.panelMods=mods;}
        else{c.panelKey=name;c.panelMods=KeyBinding.CTRL;keyMods.set(KeyBinding.CTRL);}
        changed();
    }
    function drawPhrases():Void {
        chrome.header("Recognition filters");
        if(ImGui.checkbox("Require recruiting context##requireContext",requireContext)){engine.config.requireRecruitingContext=requireContext.get();changed();}
        ImGui.setNextItemWidth(-1);
        if(Scope.choice("##phraseKind",wordKind,phraseKinds)){pending=true;confirm.clear();}
        ImGui.setNextItemWidth(-1);if(UiText.input("##phraseSearch","Search phrases or targets",phraseSearch))pending=true;
        if(pending){chrome.note("Updating phrase list...");return;}
        if(words.length==0)chrome.empty("No phrases in this list. Add one in the phrase editor.");
        for(row in words){
            var remove=chrome.actionRow(row.text,confirm.target==row.id?"Confirm?###remove":"Remove###remove",row.id);
            if(chrome.rowRightClicked){if(selectedPhrase!=row.id)confirm.clear();selectedPhrase=row.id;ImGui.openPopup(row.id);}
            if(ImGui.beginPopup(row.id)){var error:Dynamic=null;try {if(Scope.cancelPopups)ImGui.closeCurrentPopup();else{if(ImGui.menuItem("Copy phrase"))pendingCopy=row.copyText;if(ImGui.menuItem("Remove phrase")){selectedPhrase=row.id;confirm.clear();confirm.press(row.id);}}}catch(e:Dynamic)error=e;ImGui.endPopup();if(error!=null)throw error;}
            if(remove&&confirm.press(row.id))removePhrase(row);
        }
    }
    function drawCompanion():Void {
        switch(category.get()){
            case 0:
                chrome.header("Ignored players");if(ignored.length==0)chrome.empty("No ignored players.");
                for(row in ignored){var remove=chrome.actionRow(row.text,"Unignore##remove",row.id);if(chrome.button("Make permanent##permanent",false,0,false,row.id)){for(r in engine.config.ignored)if(r.id==row.id)r.until=0;changed();}if(remove){engine.config.ignored=[for(r in engine.config.ignored)if(r.id!=row.id)r];changed();}}
            case 4:
                chrome.header("Theme preview");chrome.subHeader("Sample listing");Scope.wrapped("Heroic dungeon group forming");chrome.note("Example Player | All | 1m");
                chrome.button("Whisper preview##preview");chrome.status("Available",0);chrome.status("Cooldown / reminder",1);chrome.status("Action failed",2);chrome.status("Information",3);
                chrome.gap(12);chrome.note("Popup and title surfaces remain opaque. Changes are scoped to this addon.");
            case 3:
                chrome.header("Phrase editor");if(wordKind.get()==4){ImGui.setNextItemWidth(-1);Scope.combo("##aliasTarget",Catalogue.items[aliasTarget.get()].name,aliasChoicesBody);}
                ImGui.setNextItemWidth(-1);UiText.input("##newPhrase","Literal word or phrase",word);
                if(chrome.button("Add phrase##add")){requestedPhrase=Config.clean(word.get(),48);requestedKind=wordKind.get();requestedAliasTarget=aliasTarget.get();newPhrase=true;}
                chrome.gap();if(chrome.button("Merge expanded defaults##merge"))pendingMerge=true;
                if(chrome.confirm("Restore all defaults###confirm",confirm,"resetPhrases"))restoreWords=true;
                chrome.note("Matching ignores case and respects word boundaries. Punctuation is literal; LF#M is the numbered-slot exception. Exclusions take precedence.");
                chrome.note("Boss mentions are included by default. Require recruiting context to hide non-contextual matches. Edits affect new messages.");
            case 2:
                chrome.header("Activity catalogue");ImGui.setNextItemWidth(-1);
                if(UiText.input("##watchSearch","Search activities",activities.search))activities.changed();
                for(row in activities.rows){var ref=knownWatches.get(row.activity.id);var edit=Scope.checkbox(row.id,row.activity.name,ref);if(edit){if(ref.get()){confirm.clear();if(engine.config.watchActivities.indexOf(row.activity.id)<0)engine.config.watchActivities.push(row.activity.id);changed();}else if(confirm.press(row.activity.id)){engine.config.watchActivities.remove(row.activity.id);changed();}else ref.set(true);}}
                if(activities.rows.length==0)chrome.empty("No activities match this search.");
                chrome.gap();ImGui.setNextItemWidth(-1);UiText.input("##customWatch","Custom activity to watch",watchCustom);if(chrome.button("Watch custom##watch")){requestedWatch=Parser.normalized(watchCustom.get());addWatch=true;}
                chrome.note("LFM matches only. Reposts stay silent; alerts never send chat or invitations. Sound plays only while Farever is foreground.");

        }
    }
    function drawAliasChoices():Void {
        ImGui.setNextItemWidth(-1);if(UiText.input("##aliasTargetSearch","Search target catalogue",activities.search))activities.changed();
        for(row in activities.rows)if(Scope.selectable(row.id,row.activity.name)){aliasTarget.set(Catalogue.items.indexOf(row.activity));}
        if(activities.rows.length==0)chrome.empty("No matching targets.");
    }
    function removePhrase(row:SettingsRow):Void {
        if(wordKind.get()==4){engine.config.targetAliases=[for(a in engine.config.targetAliases)if("alias_"+haxe.crypto.Sha256.encode(a.targetId+"/"+a.phrase)!=row.id)a];}
        else phraseList().remove(row.text);changed();
    }
}
