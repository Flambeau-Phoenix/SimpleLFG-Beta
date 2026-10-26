package simplelfg;

import simplelfg.RelayTransport;
import sys.thread.Mutex;

/** A separate cancellable worker; all UI/cache updates remain on observation. */
class RelayEventStream {
    var base:String;var mutex=new Mutex();var epoch=0;var socket:sys.net.Socket=null;var results:Array<RelayResult>=[];
    public function new(base:String){this.base=base;}
    public function hasResults():Bool {mutex.acquire();var ready=results.length>0;mutex.release();return ready;}
    public function drain():Array<RelayResult> {mutex.acquire();var rows=results;results=[];mutex.release();return rows;}
    public function cancel():Void {
        mutex.acquire();epoch++;
        // Interrupt the OS read only. The worker exclusively frees its TLS context.
        if(socket!=null)try socket.shutdown(true,true) catch(_:Dynamic){};
        socket=null;results.resize(0);mutex.release();
    }
    function current(id:Int):Bool {mutex.acquire();var valid=id==epoch;mutex.release();return valid;}
    function publish(id:Int,generation:Int,kind:String,status:Int=200,error:String="",retryAfter:Int=0):Void {
        mutex.acquire();
        if(id==epoch){
            if(results.length>=8){results.resize(0);results.push({generation:generation,kind:"event_sync",status:200,body:"",error:""});}
            results.push({generation:generation,kind:kind,status:status,body:"",error:error,retryAfter:retryAfter});
        }
        mutex.release();
    }
    public function start(generation:Int,token:String):Void {
        cancel();var id=epoch;
        sys.thread.Thread.create(function(){
            var opened:sys.net.Socket=null;
            try {
                if(!~/^[0-9a-f]{32}\.[0-9a-f]{64}$/.match(token))throw "Invalid event credential.";
                var connection=RelayWorkerTransport.connect(base);opened=connection.socket;
                mutex.acquire();if(id==epoch)socket=opened;mutex.release();
                if(current(id)){
                    opened.setTimeout(25);
                    opened.output.writeString("GET /api/lfg/events HTTP/1.1\r\nHost: "+connection.host+"\r\nAuthorization: Bearer "+token+"\r\nAccept: text/event-stream\r\nUser-Agent: SimpleLFG/0.1.12-test\r\nConnection: close\r\n\r\n");
                    var reader=new RelayEventReader(opened.input);reader.headers();
                    if(reader.status!=200)publish(id,generation,"event_closed",reader.status,"Live updates unavailable.",reader.retryAfter);
                    else {
                        publish(id,generation,"event_open");
                        reader.listen(function(kind){publish(id,generation,"event_"+kind);},function(){return current(id);});
                        publish(id,generation,"event_closed",0,"Live updates disconnected.");
                    }
                }
            }catch(_:Dynamic){publish(id,generation,"event_closed",0,"Live updates disconnected; retrying.");}
            mutex.acquire();if(opened!=null)try opened.close() catch(_:Dynamic){};
            if(id==epoch)socket=null;mutex.release();
        });
    }
}
