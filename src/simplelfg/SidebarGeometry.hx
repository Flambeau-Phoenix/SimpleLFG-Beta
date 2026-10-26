package simplelfg;

/** Automatic expansion is transient; only explicit user resizing changes baseWidth. */
class SidebarGeometry {
    public var baseWidth:Float;
    public var width(default,null):Float;
    public var expanded(default,null):Bool=false;
    var manualExpanded=false;
    public function new(base:Float){baseWidth=base;width=base;}
    public function update(selected:Bool,viewport:Float,scale:Float):Bool {
        var next=selected&&!(expanded&&manualExpanded)?BrowseLayout.expandedWidth(baseWidth,viewport,scale):Math.min(baseWidth,viewport);
        if(!selected)manualExpanded=false;
        var changed=Math.abs(next-width)>1||expanded!=selected;width=next;expanded=selected;return changed;
    }
    public function resize(measured:Float):Void {
        if(Math.abs(measured-width)<=1)return;
        // A user resize replaces the automatic width, so closing does not undo it.
        baseWidth=measured;width=measured;if(expanded)manualExpanded=true;
    }
}
