package simplelfg;

/** Selection never changes the board into a vertical stack. */
class BrowseLayout {
    public var sidebar(default,null):Float=0;
    public var board(default,null):Float=1;
    public var overlay(default,null):Bool=false;
    public function new(){}
    public function update(width:Float,scale:Float,selected:Bool):Void {
        width=Math.max(1,width);scale=Geometry.clamp(scale,0.85,1.5);
        sidebar=selected?Math.min(380*scale,Math.max(1,width-16)):0;
        overlay=selected&&width-sidebar-12<440*scale;
        board=selected&&!overlay?Math.max(1,width-sidebar-12):width;
    }
    public static function expandedWidth(base:Float,viewport:Float,scale:Float):Float return Math.min(viewport,base+380*scale+12);
}
