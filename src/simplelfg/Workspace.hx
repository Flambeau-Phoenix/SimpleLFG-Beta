package simplelfg;

import imgui.ImGui;
import imgui.Structs.ImVec2;

/** Two framed panes on desktop; a single scrolling canvas at compact widths. */
class Workspace {
    var chrome:Chrome;var left:Void->Void;var right:Void->Void;var body:Void->Void;
    var canvasId:String;var leftId:String;var rightId:String;
    var canvas=new ImVec2();var available=new ImVec2();var pane=new ImVec2();
    var scale:Float=1;var leftContent:Float;var rightContent:Float;
    public var layout(default,null)=new WorkspaceLayout();
    public function new(chrome:Chrome,id:String,left:Void->Void,right:Void->Void,leftContent:Float=360,rightContent:Float=300){
        this.chrome=chrome;this.left=left;this.right=right;this.leftContent=leftContent;this.rightContent=rightContent;
        canvasId=id+".canvas";leftId=id+".left";rightId=id+".right";body=drawPanes;
    }
    public function draw(scale:Float,height:Float=-1):Void {
        this.scale=scale;ImGui.getContentRegionAvail(available);canvas.x=0;canvas.y=Math.max(1,height<0?available.y:height);
        chrome.canvas(canvasId,canvas,body);
    }
    function drawPanes():Void {
        ImGui.getContentRegionAvail(available);layout.update(available.x,canvas.y,scale,false,leftContent,rightContent);
        pane.x=layout.leftWidth;pane.y=layout.leftHeight;chrome.card(leftId,pane,left);
        if(layout.wide)ImGui.sameLine(0,12);else chrome.gap(12);
        pane.x=layout.rightWidth;pane.y=layout.rightHeight;chrome.card(rightId,pane,right);
    }
}
