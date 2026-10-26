package simplelfg;

/** Pure sizing policy shared by rendering and native-free geometry tests. */
class WorkspaceLayout {
    public static inline var GAP:Float=12;
    public var wide(default,null):Bool=false;
    public var width(default,null):Float=1;
    public var bodyHeight(default,null):Float=1;
    public var leftWidth(default,null):Float=1;
    public var rightWidth(default,null):Float=1;
    public var leftHeight(default,null):Float=1;
    public var rightHeight(default,null):Float=1;
    public var rightX(default,null):Float=0;
    public var rightY(default,null):Float=0;
    public var previewHeight(default,null):Float=0;
    public var actionHeight(default,null):Float=0;
    public var contentHeight(default,null):Float=0;
    public function new(){}
    public function update(w:Float,h:Float,scale:Float,post:Bool=false,leftContent:Float=300,rightContent:Float=260):Void {
        width=Math.max(1,w);h=Math.max(1,h);scale=Geometry.clamp(scale,0.85,1.5);
        actionHeight=post?34*scale+12:0;
        previewHeight=post?Math.min(84*scale,Math.max(36,h*0.27)):0;
        bodyHeight=Math.max(1,h-actionHeight-previewHeight-(post?24:0));
        var usable=Math.max(1,width-GAP);
        wide=width>=900 && usable*0.6>=440*scale && usable*0.4>=300*scale;
        leftWidth=wide?usable*0.6:width;rightWidth=wide?usable*0.4:width;
        leftHeight=wide?bodyHeight:Math.max(120,leftContent*scale);
        rightHeight=wide?bodyHeight:Math.max(120,rightContent*scale);
        rightX=wide?leftWidth+GAP:0;rightY=wide?0:leftHeight+GAP;
        contentHeight=wide?bodyHeight:leftHeight+GAP+rightHeight;
    }
    public static function columns(w:Float,min:Float,max:Int,gap:Float=8):Int return Std.int(Math.max(1,Math.min(max,Math.floor((w+gap)/(Math.max(1,min)+gap)))));
    public static function artBox(cellWidth:Float,scale:Float):Float return Math.max(1,Math.min(cellWidth,100*scale));
    public static function artHeight(cellWidth:Float,scale:Float,lineHeight:Float):Float return artBox(cellWidth,scale)+lineHeight+12;
}
