import simplelfg.Board;
import simplelfg.Config;
import simplelfg.Parser;
import simplelfg.SearchTerms;
import simplelfg.Types.Listing;

class LaunchIntegrationTest {
    static var checks=0;
    static function ok(value:Bool,message:String):Void {checks++;if(!value)throw message;}
    static function main():Void {
        var config=new Config();
        var board=new Board(new Parser([]));
        var row=new Listing();
        row.key="fixture";row.senderId="fixture";row.senderName="Test Host";
        row.target="Crabgantua's Gorge";row.activity=row.target;row.activityId="fixture";
        row.text="Heroic chill farm";row.playerClass="Mage";
        row.kind="LFM";row.contextDetected=true;row.isRemote=true;row.seen=100;row.expiresAt=1000;
        board.mergeRemote([row],config,100);
        for(query in ["gorge mage","MAGE   heroic", "farm host gorge", "mage, gorge"])
            ok(board.filtered("All","all",query).length==1,"all words match across listing fields: "+query);
        ok(board.filtered("All","all","gorge rogue").length==0,"a missing term rejects the listing");
        ok(board.filtered("All","all","   ").length==1,"blank query retains visible listings");
        ok(board.filtered("LFG","all","mage").length==0,"query does not bypass intent filter");
        ok(board.filtered("All","other","mage").length==0,"query does not bypass activity filter");
        row.text=StringTools.lpad("x","x",512);
        ok(board.filtered("All","all","gorge mage host").length==1,"long note does not discard class or sender metadata");
        board.hide(row.key);
        ok(board.filtered("All","all","mage").length==0,"query does not expose hidden rows");
        var aliases=["Synthetic Activity",StringTools.lpad("x","x",512),"lateralias"];
        ok(SearchTerms.matches(aliases,SearchTerms.parse("activity lateralias")),"late aliases remain searchable beyond combined 512 chars");
        ok(!SearchTerms.matches(aliases,SearchTerms.parse("lateralias absent")),"activity terms all remain required");
        Sys.println("PASS "+checks+" launch integration checks");
    }
}
