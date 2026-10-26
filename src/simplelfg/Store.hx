package simplelfg;

/** Sole filesystem owner. No chat messages are serialized. */
class Store {
    public var error(default,null):String="";
    public var path(default,null):String;
    var recoverable:Bool=true;
    public function new(path:String="hlx/config/simplelfg/config.json") this.path=path;
    public function load():Config {
        var source=path;
        if(!sys.FileSystem.exists(source)) {
            if(sys.FileSystem.exists(path+".bak")) {source=path+".bak";error="Recovered settings from the previous save.";}
            else return new Config();
        }
        try {
            var raw=sys.io.File.getContent(source);
            // Preserve malformed originals before any future write.
            try haxe.Json.parse(raw) catch(_:Dynamic) {
                sys.io.File.copy(source,path+".invalid");
                error="Invalid settings preserved as config.json.invalid; using defaults.";
                return new Config();
            }
            return Config.decode(raw);
        } catch(e:Dynamic) {
            recoverable=false;error="Could not read settings; saving is disabled to protect the original.";
            return new Config();
        }
    }
    public function save(c:Config):Bool {
        if(!recoverable) return false;
        var tmp=path+".tmp";
        try {
            var dir=haxe.io.Path.directory(path);
            if(dir!="" && !sys.FileSystem.exists(dir)) sys.FileSystem.createDirectory(dir);
            sys.io.File.saveContent(tmp,c.encode());
            // Windows HL rename cannot replace an existing file. Retain a recoverable
            // prior save and restore it if the second rename fails.
            var backup=path+".bak";
            if(sys.FileSystem.exists(path)) {
                if(sys.FileSystem.exists(backup)) sys.FileSystem.deleteFile(backup);
                sys.FileSystem.rename(path,backup);
            }
            try sys.FileSystem.rename(tmp,path) catch(e:Dynamic) {
                if(!sys.FileSystem.exists(path) && sys.FileSystem.exists(backup)) sys.FileSystem.rename(backup,path);
                throw e;
            }
            error="";return true;
        } catch(_:Dynamic) {error="Settings could not be saved. Check folder permissions.";return false;}
    }
}
