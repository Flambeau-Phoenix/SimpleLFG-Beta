package simplelfg;

import simplelfg.Types.Activity;

class Catalogue {
    public static var items(default,null):Array<Activity>=[];
    public static function load():Void items=TargetDefaults.activities();
}
