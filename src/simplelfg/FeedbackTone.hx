package simplelfg;

/** Presentation only: submission is informational, never a delivery success claim. */
class FeedbackTone {
    public var text(default,null):String="";public var kind(default,null):Int=3;
    public function new(){}
    public function observe(value:String):Void {
        if(value==text)return;text=value;var s=value.toLowerCase();
        kind=s.indexOf("submitted")>=0?3:(s.indexOf("saved")>=0?0:
            (s.indexOf("failed")>=0||s.indexOf("denied")>=0||s.indexOf("offline")>=0||s.indexOf("could not")>=0?2:
            (s.indexOf("expired")>=0||s.indexOf("wait")>=0||s.indexOf("cancelled")>=0||s.indexOf("enter")>=0||s.indexOf("remove")>=0?1:3)));
    }
}
