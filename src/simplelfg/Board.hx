package simplelfg;

import simplelfg.Types;

class Board {
    public static inline var LIMIT=200;
    public static inline var QUEUE_LIMIT=256;
    public var entries(default,null):Array<Listing>=[];
    public var history(default,null)=new SessionHistory();
    public var dropped(default,null):Int=0;
    public var revision(default,null):Int=0;
    var queue:Array<ChatEnvelope>=[];
    var parser:Parser;
    var lastExpiry:Int=-1;
    var lastExpirySetting:Int=-1;
    var contextRequired=false;
    var remoteHidden:Map<String,Float>=new Map();
    public function new(parser:Parser) this.parser=parser;
    public function enqueue(e:ChatEnvelope):Void {
        if(queue.length>=QUEUE_LIMIT) {queue.shift();dropped++;}
        queue.push(e);
    }
    public function clear():Void {entries.resize(0);queue.resize(0);remoteHidden.clear();history.clear();revision++;}
    public function clearRemote():Void {var old=entries.length;entries=[for(l in entries)if(!l.isRemote)l];if(old!=entries.length)revision++;}
    /** A complete validated snapshot refreshes existing rows and removes absent listings. */
    public function mergeRemote(rows:Array<Listing>,c:Config,now:Float):Void {
        entries=[for(l in entries)if(!l.isRemote)l];
        for(l in rows){
            if(now>=l.expiresAt||ignored(l.senderId,c,now))continue;
            l.hidden=remoteHidden.exists(l.key)&&remoteHidden.get(l.key)>now;if(entries.length>=LIMIT){dropped++;break;}entries.push(l);
        }
        revision++;
    }
    public function contains(key:String):Bool { for(l in entries) if(l.key==key && !l.hidden&&(!contextRequired||l.contextDetected)) return true; return false; }
    public function ignored(id:String,c:Config,now:Float):Bool {
        for(r in c.ignored) if(r.id==id && (r.until==0 || r.until>now)) return true;
        return false;
    }
    public function hide(key:String):Void {
        for(l in entries) if(l.key==key) {l.hidden=true;if(l.isRemote)remoteHidden.set(l.key,l.expiresAt);revision++;return;}
    }
    public function ignore(id:String,name:String,c:Config,now:Float,permanent:Bool=false):Void {
        c.ignored=[for(r in c.ignored) if(r.id!=id) r];
        if(c.ignored.length>=200) c.ignored.shift();
        c.ignored.push({id:id,name:name,until:permanent?0:now+1800});
        entries=[for(l in entries) if(l.senderId!=id) l];revision++;
    }
    public function prepare(c:Config):Void parser.prepare(c);
    public function update(c:Config,now:Float):Void {
        if(contextRequired!=c.requireRecruitingContext){contextRequired=c.requireRecruitingContext;revision++;}
        history.expire(now);
        for(key in remoteHidden.keys())if(remoteHidden.get(key)<=now)remoteHidden.remove(key);
        var second=Std.int(now);
        if(second!=lastExpiry || c.expirySeconds!=lastExpirySetting) {
            lastExpiry=second;lastExpirySetting=c.expirySeconds;
            var old=entries.length;
            entries=[for(l in entries) if((l.isRemote?now<l.expiresAt:now-l.seen<c.expirySeconds) && !ignored(l.senderId,c,now)) l];
            if(old!=entries.length) revision++;
        }
        // Bounded work per service frame, including while the window is closed.
        var budget=32;
        while(budget-->0 && queue.length>0) {
            var e=queue.shift();
            if(!SessionHistory.valid(e)||!ChannelPolicy.enabled(c,e.channel)||ignored(e.senderId,c,now))continue;
            history.add(e,now);
            if(now-e.receivedAt>=c.expirySeconds)continue;
            var l=parser.parse(e,c); if(l==null) continue;
            var previous:Listing=null;
            for(v in entries) if(v.key==l.key) {previous=v;break;}
            // Hiding is a lease on this listing until its original expiry, even if it reposts.
            if(previous!=null && previous.hidden) continue;
            if(previous!=null) entries.remove(previous);
            if(entries.length>=LIMIT) {entries.shift();dropped++;}
            entries.push(l);revision++;
        }
    }
    public function filtered(kind:String,activityId:String,query:String):Array<Listing> {
        var terms=SearchTerms.parse(query);
        var result=[for(l in entries) if(!l.hidden&&(!contextRequired||l.contextDetected) && (kind=="All"||l.kind==kind)
            && (activityId=="all"||l.activityId==activityId||l.matchedTargetIds.indexOf(activityId)>=0)
            && matchesQuery(l,terms)) l];
        result.sort((a,b)->a.seen>b.seen?-1:(a.seen<b.seen?1:0));
        return result;
    }
    static function matchesQuery(l:Listing, terms:Array<String>):Bool {
        if(terms.length==0)return true;
        return SearchTerms.matches([l.target,l.activity,l.text,l.senderName,l.playerClass],terms);
    }
}
