package simplelfg;

import haxe.io.Input;

/** Incremental, bounded HTTP chunk/SSE decoder. Never buffers an entire stream. */
class RelayEventReader {
    var input:Input;var chunked=false;var remaining=0;var chunkEnd=false;var ended=false;
    public var status(default,null)=0;public var retryAfter(default,null)=0;
    public function new(input:Input){this.input=input;}
    function rawLine(max:Int):String {
        var out=new haxe.io.BytesBuffer();
        while(true){var c=input.readByte();if(c==10)break;if(out.length>=max)throw "Event line exceeds limit.";if(c!=13)out.addByte(c);}
        return out.getBytes().toString();
    }
    public function headers():Void {
        var parts=rawLine(1024).split(" ");
        if(parts.length<2||!~/^HTTP\/1\.[01]$/.match(parts[0])||!~/^[0-9]{3}$/.match(parts[1]))throw "Invalid event response.";
        status=Std.parseInt(parts[1]);var bytes=0;var contentType="";
        while(true){var line=rawLine(4096);bytes+=line.length+2;if(bytes>16384)throw "Event headers exceed limit.";if(line=="")break;
            var colon=line.indexOf(":");if(colon<1)throw "Invalid event header.";
            var name=line.substr(0,colon).toLowerCase();var value=StringTools.trim(line.substr(colon+1));
            if(name=="content-type")contentType=value.toLowerCase();
            if(name=="content-length"&&status==200)throw "Event stream must be incremental.";
            if(name=="transfer-encoding"){if(chunked||value.toLowerCase()!="chunked")throw "Invalid event framing.";chunked=true;}
            if(name=="content-encoding"&&value.toLowerCase()!="identity")throw "Compressed event stream rejected.";
            if(name=="retry-after"&&~/^[0-9]{1,8}$/.match(value))retryAfter=Std.int(Math.min(3600,Std.parseInt(value)));
        }
        if(status==200&&!StringTools.startsWith(contentType,"text/event-stream"))throw "Invalid event content type.";
    }
    function nextByte():Int {
        if(ended)throw new haxe.io.Eof();
        if(chunked&&remaining==0){
            if(chunkEnd){if(input.readByte()!=13||input.readByte()!=10)throw "Invalid event chunk ending.";}
            var size=rawLine(128).split(";")[0];if(!~/^[0-9a-fA-F]{1,6}$/.match(size))throw "Invalid event chunk.";
            remaining=Std.parseInt("0x"+size);if(remaining==0){ended=true;throw new haxe.io.Eof();}chunkEnd=true;
        }
        var value=input.readByte();if(chunked)remaining--;return value;
    }
    public function listen(emit:String->Void,alive:Void->Bool):Void {
        var event="";var bytes=0;
        while(alive()){
            var line=new haxe.io.BytesBuffer();
            while(true){var c=nextByte();if(c==10)break;if(line.length>=4096)throw "Event line exceeds limit.";if(c!=13)line.addByte(c);}
            var text=line.getBytes().toString();bytes+=text.length+1;if(bytes>16384)throw "Event exceeds limit.";
            if(text==""){if(event=="sync"||event=="listings"||event=="chat"||event=="expired")emit(event);event="";bytes=0;}
            else if(StringTools.startsWith(text,"event:"))event=StringTools.trim(text.substr(6));
        }
    }
}
