import simplelfg.WorkspaceLayout;
import simplelfg.Config;
import simplelfg.Types.Draft;
import simplelfg.UiState.Confirmation;
import simplelfg.UiState.TemplateRows;
import simplelfg.FeedbackTone;

class LayoutTest {
    static var checks=0;
    static function check(v:Bool,label:String):Void {checks++;if(!v)throw label;}
    static function main():Void {
        var cases:Array<Dynamic>=[];
        for(dims in [{w:520,h:360},{w:720,h:480},{w:960,h:640},{w:1200,h:800}])for(scale in [0.85,1.0,1.5])for(post in [false,true]){
            var l=new WorkspaceLayout();var w:Float=dims.w-24;var h:Float=dims.h-100*scale;
            l.update(w,h,scale,post);
            check(l.bodyHeight>0&&l.leftWidth>0&&l.rightWidth>0,"positive workspace dimensions");
            check(l.bodyHeight+l.actionHeight+l.previewHeight+(post?24:0)<=h+0.001,"reserved preview and action areas fit");
            check(l.leftWidth<=w&&l.rightX+l.rightWidth<=w+0.001,"panes fit horizontally");
            check(l.wide?Math.abs(l.rightX-l.leftWidth-12)<0.001:l.rightY==l.leftHeight+12,"gutter and compact stack");
            check(l.wide?l.rightY==0:l.contentHeight>l.bodyHeight,"compact content remains scrollable");
            if(l.wide){check(l.leftWidth>=440*scale&&l.rightWidth>=300*scale,"font-scaled minima");check(Math.abs(l.leftWidth/(w-12)-0.6)<0.001,"60/40 split");}
            // This is the exact role-cluster column policy, also used in PostPanel.
            var controlWidth=Math.max(1,l.leftWidth-24-132-12);
            var cols=WorkspaceLayout.columns(controlWidth,92*scale,3,12);
            check(cols>=1&&cols<=3,"role columns bounded");
            check(cols==1||(controlWidth-12*(cols-1))/cols>=92*scale-0.001,"role groups fit their cells");
            var browse=new simplelfg.BrowseLayout();browse.update(w,scale,false);
            check(browse.board==w&&browse.sidebar==0,"unselected board uses all width");
            browse.update(w,scale,true);check(browse.sidebar>0&&browse.sidebar<=w,"sidebar fits");
            check(browse.overlay||browse.board+browse.sidebar+12<=w+0.001,"selected panes never stack or escape");
            // Overlays are intentionally overlapping; only the top drawer participates in this spatial fixture.
            var cells:Array<Dynamic>=[];var ids:Array<String>=[];var height=200.0;
            if(browse.overlay){cells.push({id:"drawer",x:w-browse.sidebar,y:0.0,width:browse.sidebar,height:height,row:0,textBounds:{x:w-browse.sidebar+4,y:4.0,width:browse.sidebar-8,height:16.0}});ids.push("drawer");}
            else {cells.push({id:"board",x:0.0,y:0.0,width:browse.board,height:height,row:0,textBounds:{x:4.0,y:4.0,width:browse.board-8,height:16.0}});ids.push("board");cells.push({id:"details",x:browse.board+12,y:0.0,width:browse.sidebar,height:height,row:0,textBounds:{x:browse.board+16,y:4.0,width:browse.sidebar-8,height:16.0}});ids.push("details");}
            cases.push({name:dims.w+"x"+dims.h+"@"+scale+"-"+post,width:w,contentHeight:height,gap:12,columns:browse.overlay?1:2,minCellWidth:200*scale,textLimited:true,rows:[{kind:"cells",y:0.0,height:height}],cells:cells,expectedIds:ids});
        }
        var l=new WorkspaceLayout();l.update(899,500,1);check(!l.wide,"below usable-width breakpoint");l.update(900,500,1);check(l.wide,"at usable-width breakpoint");l.update(900,500,1.5);check(!l.wide,"large fonts require compact layout");l.update(1140,500,1.5);check(l.wide,"large fonts gain desktop panes when minima fit");
        check(new Config().width==1440&&new Config().height==900,"new installation default");
        var old=Config.decode('{"geometryVersion":1,"width":720,"height":480}');check(old.width==1440&&old.height==900,"legacy geometry enlarged once");
        var missing=Config.decode('{}');check(missing.width==1440&&missing.height==900,"missing geometry uses new default");
        var confirmation=new Confirmation();check(!confirmation.press("one"),"first delete only arms");check(!confirmation.press("two"),"different target never confirms old target");check(confirmation.press("two"),"second click confirms exact target");confirmation.press("one");confirmation.clear();check(!confirmation.press("one"),"closing or navigation cancels confirmation");
        var a=new Draft();var b=new Draft();var c=new Draft();var index=new TemplateRows();index.update([a,b,c]);var second=index.rows[1].id;
        index.update([b,c]);check(index.rows[0].id==second,"deletion before selection preserves template identity");index.update([c,b]);check(index.rows[1].id==second,"reordering preserves template identity");
        var copy=b.copy();index.update([b,copy]);check(index.rows[0].id!=index.rows[1].id,"identical template copies have distinct IDs");
        a.activity="Target##not-a-widget";index.update([a]);check(index.rows[0].label.indexOf("##")<0,"template labels cannot alter widget IDs");
        var hashes=new Draft();hashes.activity="Target###suffix";index.update([hashes]);check(index.rows[0].label.indexOf("##")<0,"triple hashes cannot create a hidden template ID");
        var tone=new FeedbackTone();tone.observe("Post submitted; delivery not confirmed");check(tone.kind==3,"submission is informational");tone.observe("Template saved");check(tone.kind==0,"saved status");tone.observe("Offline player");check(tone.kind==2,"failed whisper status");tone.observe("Listing expired");check(tone.kind==1,"expired status");
        if(Sys.args().length>0)sys.io.File.saveContent(Sys.args()[0],haxe.Json.stringify({cases:cases}));
        Sys.println("PASS "+checks+" layout, migration, confirmation and identity checks");
    }
}
