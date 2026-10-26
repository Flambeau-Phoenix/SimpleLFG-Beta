package simplelfg.ui;

import imgui.ImGui;
import imgui.ImGui.ImGuiListClipper;
import imgui.Enums.ImGuiFocusedFlags;
import imgui.Enums.ImGuiKey;
import imgui.Enums.ImGuiSelectableFlags;
import imgui.Enums.ImGuiSortDirection;
import imgui.Enums.ImGuiTableColumnFlags;
import imgui.Enums.ImGuiTableFlags;
import imgui.Structs.ImVec2;

typedef TableColumn={var label:String;var width:Float;var fixed:Bool;var sortable:Bool;@:optional var defaultSort:Bool;}

/**
 * Sortable, clipped, single-selection table shared by every list in the panel.
 * The model stays with the caller: rows are indices, cells are drawn by callback, and a sort
 * request is reported through `takeSort()` so the caller re-sorts its own rows in observation.
 * Callbacks are retained by the owner, so a frame allocates nothing here.
 */
class DataTable {
    public var sortColumn(default,null):Int=-1;
    public var ascending(default,null):Bool=true;
    /** Vertical padding that centres a one-line control inside a row. */
    static inline var CELL_PAD_X:Float=6;
    public var padY(default,null):Float=0;
    public var rowHeight:Float;
    var id:String;var menuId:String;var columns:Array<TableColumn>;
    var rowId:Int->String;var cell:Int->Int->Void;var isSelected:Int->Bool;var pick:Int->Void;var menu:Int->Void;var activate:Int->Void;
    var size=new ImVec2();var rowSize=new ImVec2();var at=new ImVec2();var zero=new ImVec2();
    var clipper:ImGuiListClipper;var count=0;var menuRow=-1;var sortChanged=false;var scrollTo=-1;
    var rowBody:Int->Void;var menuBody:Void->Void;var bodyDraw:Void->Void;
    public function new(id:String,columns:Array<TableColumn>,rowHeight:Float,rowId:Int->String,cell:Int->Int->Void,isSelected:Int->Bool,pick:Int->Void,?menu:Int->Void,?activate:Int->Void){
        this.id=id;this.columns=columns;this.rowHeight=rowHeight;this.rowId=rowId;this.cell=cell;this.isSelected=isSelected;this.pick=pick;this.menu=menu;this.activate=activate;
        menuId=id+".menu";rowBody=drawRow;menuBody=drawMenu;bodyDraw=drawBody;
        clipper=ImGui.ImGuiListClipper_ImGuiListClipper();
    }
    public function takeSort():Bool {var v=sortChanged;sortChanged=false;return v;}
    public function setSort(column:Int,asc:Bool):Void {sortColumn=column;ascending=asc;}
    public function reveal(row:Int):Void scrollTo=row;
    /** Arrow keys move the selection while the surrounding window has focus and no field is being edited. */
    public function navigate(current:Int,rows:Int):Int {
        if(rows<=0||!ImGui.isWindowFocused(ImGuiFocusedFlags.ChildWindows)||ImGui.isAnyItemActive())return current;
        var next=current;
        if(ImGui.isKeyPressed(ImGuiKey.DownArrow,true))next=current<0?0:Std.int(Math.min(rows-1,current+1));
        else if(ImGui.isKeyPressed(ImGuiKey.UpArrow,true))next=current<0?0:Std.int(Math.max(0,current-1));
        else if(ImGui.isKeyPressed(ImGuiKey.Enter,false)&&current>=0&&activate!=null){activate(current);return current;}
        if(next!=current){pick(next);scrollTo=next;}
        return next;
    }
    public function draw(width:Float,height:Float,rows:Int,emptyText:String):Void {
        count=rows;size.x=width;size.y=height;
        if(rows<=0){drawEmpty(emptyText);return;}
        var flags=ImGuiTableFlags.RowBg|ImGuiTableFlags.BordersOuter|ImGuiTableFlags.BordersInnerH|ImGuiTableFlags.SizingStretchProp|ImGuiTableFlags.ScrollY|ImGuiTableFlags.Resizable|ImGuiTableFlags.Sortable|ImGuiTableFlags.NoSavedSettings;
        if(!ImGui.beginTable(id,columns.length,flags,size))return;
        var error:Dynamic=null;try bodyDraw() catch(e:Dynamic)error=e;
        ImGui.endTable();if(error!=null)throw error;
    }
    function drawEmpty(text:String):Void {
        UiChrome.gap(UiChrome.SP_M);
        ImGui.pushTextWrapPos(0);ImGui.textDisabled(text);ImGui.popTextWrapPos();
    }
    function drawBody():Void {
        for(i in 0...columns.length){
            var c=columns[i];
            var flags=(c.fixed?ImGuiTableColumnFlags.WidthFixed:ImGuiTableColumnFlags.WidthStretch)|(c.sortable?0:ImGuiTableColumnFlags.NoSort)|(c.defaultSort==true?ImGuiTableColumnFlags.DefaultSort|(ascending?0:ImGuiTableColumnFlags.PreferSortDescending):0);
            ImGui.tableSetupColumn(c.label,flags,c.width);
        }
        ImGui.tableSetupScrollFreeze(0,1);
        ImGui.tableHeadersRow();
        var specs=ImGui.tableGetSortSpecs();
        if(specs!=null&&ImGui.tableSortSpecsGetSpecsDirty(specs)){
            if(ImGui.tableSortSpecsGetSpecsCount(specs)>0){
                sortColumn=ImGui.tableSortSpecsGetColumnIndex(specs,0);
                ascending=ImGui.tableSortSpecsGetSortDirection(specs,0)==ImGuiSortDirection.Ascending;
            }else sortColumn=-1;
            sortChanged=true;ImGui.tableSortSpecsSetSpecsDirty(specs,false);
        }
        padY=Math.max(0,(rowHeight-ImGui.getTextLineHeight())*0.5);
        ImGui.ImGuiListClipper_Begin(clipper,count);
        if(scrollTo>=0&&scrollTo<count)ImGui.ImGuiListClipper_IncludeItemByIndex(clipper,scrollTo);
        var error:Dynamic=null;
        try {while(ImGui.ImGuiListClipper_Step(clipper))for(i in ImGui.ImGuiListClipper_get_DisplayStart(clipper)...ImGui.ImGuiListClipper_get_DisplayEnd(clipper))rowBody(i);}catch(e:Dynamic)error=e;
        ImGui.ImGuiListClipper_End(clipper);scrollTo=-1;
        if(error!=null)throw error;
        if(menu!=null)simplelfg.ContextMenuSystem.draw(menuId,menuBody,menuRow>=0&&menuRow<count);
    }
    function drawRow(i:Int):Void {
        ImGui.tableNextRow(0,rowHeight);ImGui.tableSetColumnIndex(0);
        rowSize.x=0;rowSize.y=rowHeight;
        var flags=ImGuiSelectableFlags.SpanAllColumns|ImGuiSelectableFlags.AllowOverlap|ImGuiSelectableFlags.AllowDoubleClick;
        if(ImGui.selectable(rowId(i),isSelected(i),flags,rowSize)){pick(i);if(activate!=null&&ImGui.isMouseDoubleClicked(0))activate(i);}
        if(menu!=null&&ImGui.isItemClicked(1)&&!simplelfg.Scope.cancelPopups){pick(i);menuRow=i;ImGui.openPopup(menuId);}
        if(scrollTo==i)ImGui.setScrollHereY(0.5);
        ImGui.getItemRectMin(at);at.x+=CELL_PAD_X;at.y+=padY;
        // Every cursor seek must be followed by a submitted item (Dear ImGui checks this), even when a cell draws nothing.
        ImGui.setCursorScreenPos(at);cell(i,0);ImGui.dummy(zero);
        for(c in 1...columns.length){ImGui.tableSetColumnIndex(c);ImGui.setCursorPosY(ImGui.getCursorPosY()+padY);cell(i,c);ImGui.dummy(zero);}
    }
    function drawMenu():Void menu(menuRow);
}
