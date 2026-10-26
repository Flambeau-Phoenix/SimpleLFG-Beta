package simplelfg;

import haxe.io.Input;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;

/** Bounded HTTP/1.1 reader. EOF in a partial header fails instead of spinning. */
class RelayHttpReader {
    public static function read(input:Input):{status:Int,body:String,retryAfter:Int} {
        var used=0;var deadline=Sys.time()+16;
        function line():String {
            var bytes=new BytesBuffer();
            while(true){
                if(Sys.time()>deadline||used++>=16384)throw "Relay headers exceed their limit.";
                var c=input.readByte();if(c==10)break;if(c!=13)bytes.addByte(c);
            }
            return bytes.getBytes().toString();
        }
        var first=line();var parts=first.split(" ");
        if(parts.length<2||!~/^HTTP\/1\.[01]$/.match(parts[0])||!~/^[0-9]{3}$/.match(parts[1]))throw "Invalid relay HTTP status.";
        var status=Std.parseInt(parts[1]);var length:Null<Int>=null;var chunked=false;var retryAfter=0;
        while(true){var header=line();if(header=="")break;var colon=header.indexOf(":");if(colon<1)throw "Invalid relay header.";
            var name=header.substr(0,colon).toLowerCase();var value=StringTools.trim(header.substr(colon+1));
            if(name=="content-length"){
                if(length!=null||!~/^[0-9]{1,8}$/.match(value))throw "Invalid relay content length.";
                length=Std.parseInt(value);if(length>RelayProtocol.MAX_RESPONSE)throw "Relay response exceeds its size limit.";
            }
            if(name=="transfer-encoding"){if(value.toLowerCase()!="chunked")throw "Unsupported relay encoding.";chunked=true;}
            if(name=="content-encoding"&&value.toLowerCase()!="identity")throw "Unexpected compressed relay response.";
            if(name=="retry-after"&&~/^[0-9]{1,8}$/.match(value))retryAfter=Std.int(Math.min(3600,Std.parseInt(value)));
        }
        if(chunked&&length!=null)throw "Conflicting relay body framing.";
        var body=new BytesBuffer();var buffer=Bytes.alloc(4096);
        function exact(count:Int):Void {
            if(count<0||body.length+count>RelayProtocol.MAX_RESPONSE)throw "Relay response exceeds its size limit.";
            while(count>0){if(Sys.time()>deadline)throw "Relay read timed out.";var n=input.readBytes(buffer,0,Std.int(Math.min(buffer.length,count)));if(n<=0)throw "Incomplete relay response.";body.addBytes(buffer,0,n);count-=n;}
        }
        if(chunked){
            while(true){var size=line().split(";")[0];if(!~/^[0-9a-fA-F]{1,6}$/.match(size))throw "Invalid relay chunk.";var count=Std.parseInt("0x"+size);
                if(count==0){while(line()!=""){}break;}
                exact(count);if(input.readByte()!=13||input.readByte()!=10)throw "Invalid relay chunk ending.";
            }
        }else if(length!=null)exact(length);
        else {
            while(true){if(Sys.time()>deadline)throw "Relay read timed out.";var n=0;try n=input.readBytes(buffer,0,buffer.length) catch(_:haxe.io.Eof)break;
                if(n<=0)break;if(body.length+n>RelayProtocol.MAX_RESPONSE)throw "Relay response exceeds its size limit.";body.addBytes(buffer,0,n);
            }
        }
        return {status:status,body:body.getBytes().toString(),retryAfter:retryAfter};
    }
}
