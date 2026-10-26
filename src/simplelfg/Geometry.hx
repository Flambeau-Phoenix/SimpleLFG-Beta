package simplelfg;

class Geometry {
    public static function fitScale(w:Float,h:Float,box:Float):Float return w<=0||h<=0?0:Math.max(0,box)/Math.max(w,h);
    public static function clamp(v:Float,lo:Float,hi:Float):Float return Math.max(lo,Math.min(Math.max(lo,hi),v));
    public static function x(c:Config,screenWidth:Float):Float return clamp(c.windowX<0?(screenWidth-c.width)*0.5:c.windowX,0,screenWidth-Math.min(c.width,screenWidth));
    public static function y(c:Config,screenHeight:Float):Float return clamp(c.windowY<0?(screenHeight-c.height)*0.5:c.windowY,0,screenHeight-Math.min(c.height,screenHeight));
    public static function launcherX(c:Config,w:Float):Float return clamp(w-448-44,0,w-44);
    public static function launcherY(c:Config,h:Float):Float return clamp(h-16-44,0,h-44);
}
