package simplelfg;

import simplelfg.Types.Listing;
import simplelfg.LootBrowser.LootLine;

/** Explicit column sorting; stable identity breaks equal keys. */
class SortPolicy {
    public static function text(a:String,b:String):Int {a=a.toLowerCase();b=b.toLowerCase();return a<b?-1:(a>b?1:0);}
    public static function listing(a:Listing,b:Listing,column:Int,ascending:Bool):Int {
        var n=column==0?text(a.target,b.target):(column==1?text(a.senderName,b.senderName):(a.seen>b.seen?-1:(a.seen<b.seen?1:0)));
        return n==0?text(a.key,b.key):(ascending?n:-n);
    }
    /** Board columns by name: context, target, type, player, party, source, age (newest first when ascending), message. */
    public static function board(a:Listing,b:Listing,field:String,ascending:Bool):Int {
        var n=switch(field){
            case "context":(a.contextDetected?0:1)-(b.contextDetected?0:1);
            case "target":text(a.target,b.target);
            case "type":text(a.kind,b.kind);
            case "player":text(a.senderName,b.senderName);
            case "party":text(a.composition,b.composition);
            case "source":text(a.isRemote?"cross":"game",b.isRemote?"cross":"game");
            case "message":text(a.text,b.text);
            default:a.seen>b.seen?-1:(a.seen<b.seen?1:0);
        }
        // Ties fall back to age then identity so equal rows never reshuffle between frames.
        if(n==0)n=a.seen>b.seen?-1:(a.seen<b.seen?1:0);
        return n==0?text(a.key,b.key):(ascending?n:-n);
    }
    public static function loot(a:LootLine,b:LootLine,column:Int,ascending:Bool):Int {
        var n=column==0?text(a.title,b.title):(column==1?text(a.rarity,b.rarity):text(a.itemType,b.itemType));
        return n==0?text(a.key,b.key):(ascending?n:-n);
    }
}
