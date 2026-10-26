package simplelfg;

import simplelfg.RelayTransport;
import sys.thread.Mutex;

/** A single short-lived worker drains a bounded queue. Never calls Engine/UI/game code. */
class RelayWorkerTransport implements RelayTransport {
    var baseUrl:String;var mutex=new Mutex();var jobs:Array<RelayRequest>=[];var results:Array<RelayResult>=[];var running=false;
    var retryUntil:Float=0;var failures=0;
    public function new(baseUrl:String){this.baseUrl=baseUrl;}
    public function submit(request:RelayRequest):Bool {
        mutex.acquire();
        if(jobs.length>=8){mutex.release();return false;}
        jobs.push(request);
        if(!running){
            running=true;
            try sys.thread.Thread.create(work) catch(_:Dynamic){jobs.resize(0);running=false;mutex.release();return false;}
        }
        mutex.release();return true;
    }
    public function drain():Array<RelayResult> {mutex.acquire();var next=results;results=[];mutex.release();return next;}
    public function hasResults():Bool {mutex.acquire();var ready=results.length>0;mutex.release();return ready;}
    public function cancel():Void {mutex.acquire();jobs.resize(0);results.resize(0);mutex.release();}
    function work():Void {
        while(true){
            mutex.acquire();var request=jobs.shift();if(request==null){running=false;mutex.release();return;}mutex.release();
            var result:RelayResult;
            if(Sys.time()<retryUntil)result={generation:request.generation,kind:request.kind,status:429,body:"",error:"Relay cooldown; wait before retrying.",retryAfter:Std.int(Math.ceil(retryUntil-Sys.time()))};
            else {
                result=execute(baseUrl,request);
                if(result.error!=""){
                    failures=Std.int(Math.min(6,failures+1));
                    var delay=result.retryAfter==null?0:result.retryAfter;
                    if(result.status==429||result.status==503||result.status==0||result.status>=500)
                        retryUntil=Sys.time()+Math.max(delay,Math.min(60,Math.pow(2,failures)));
                }else failures=0;
            }
            mutex.acquire();if(results.length>=16)results.shift();results.push(result);mutex.release();
        }
    }
    public static function execute(base:String,request:RelayRequest):RelayResult {
        var result:RelayResult={generation:request.generation,kind:request.kind,status:0,body:"",error:""};var socket:sys.net.Socket=null;
        try {
            var connection=connect(base);socket=connection.socket;var host=connection.host;
            var body=request.body==null?null:haxe.io.Bytes.ofString(request.body);
            var headers=(body==null?"GET ":"POST ")+request.path+" HTTP/1.1\r\nHost: "+host+"\r\nUser-Agent: SimpleLFG/0.1.12-test\r\nAccept: application/json\r\nConnection: close\r\n";
            if(request.token!=null&&request.token!=""){
                if(!~/^[0-9a-f]{32}\.[0-9a-f]{64}$/.match(request.token))throw "Invalid session credential.";
                headers+="Authorization: Bearer "+request.token+"\r\n";
            }
            if(body!=null)headers+="Content-Type: application/json\r\nContent-Length: "+body.length+"\r\n";
            socket.output.writeString(headers+"\r\n");if(body!=null)socket.output.writeFullBytes(body,0,body.length);
            var response=RelayHttpReader.read(socket.input);result.status=response.status;result.body=response.body;result.retryAfter=response.retryAfter;
            if(result.status<200||result.status>=300)result.error="Relay HTTP "+result.status+(result.status==403?" (request denied)":(result.status==429?" (rate limit; wait before retrying)":""));
        }catch(e:Dynamic){result.error="Relay connection failed: "+Config.clean(Std.string(e),140);}
        if(socket!=null)try socket.close() catch(_:Dynamic){};
        return result;
    }
    public static function connect(base:String):{socket:sys.net.Socket,host:String} {
        var url=~/^(https?):\/\/([a-zA-Z0-9.-]+)(?::([0-9]{1,5}))?\/?$/;
        if(!url.match(base))throw "Invalid relay endpoint.";
        var secure=url.matched(1)=="https";var host=url.matched(2);var port=url.matched(3)==null?(secure?443:80):Std.parseInt(url.matched(3));
        if(!secure&&host!="127.0.0.1"&&host!="localhost")throw "Relay requires HTTPS.";
        if(port<1||port>65535)throw "Invalid relay port.";
        var socket:sys.net.Socket;
        if(secure){var tls=new sys.ssl.Socket();tls.verifyCert=true;tls.setHostname(host);socket=tls;}else socket=new sys.net.Socket();
        try {socket.setTimeout(8);socket.connect(new sys.net.Host(host),port);}catch(e:Dynamic){try socket.close() catch(_:Dynamic){};throw e;}
        return {socket:socket,host:host};
    }
}
