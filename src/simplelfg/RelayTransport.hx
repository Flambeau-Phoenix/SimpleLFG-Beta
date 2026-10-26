package simplelfg;

typedef RelayRequest = { var generation:Int; var kind:String; var path:String; var body:Null<String>; @:optional var token:String; }
typedef RelayResult = { var generation:Int; var kind:String; var status:Int; var body:String; var error:String; @:optional var retryAfter:Int; }

/** Only immutable request/response primitives cross the worker boundary. */
interface RelayTransport {
    public function submit(request:RelayRequest):Bool;
    public function drain():Array<RelayResult>;
    public function hasResults():Bool;
    public function cancel():Void;
}
