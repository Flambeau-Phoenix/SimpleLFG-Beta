#include "extra_policy.h"
#include <cstdio>
#include <cstdlib>
#include <initializer_list>
static int checks = 0;
static void check(bool value, const char *label) { ++checks; if (!value) { std::fprintf(stderr, "FAIL: %s\n", label); std::exit(1); } }
int main() {
    ExtraBarsPolicy p;
    p.configure(88,49,1,true,1,false,false);
    check(!p.event(49,true,false,false), "Naked key remains native immediately");
    check(!p.event(88,true,false,false), "Hold prefix stays native");
    check(!p.event(49,true,true,false), "Prefix cannot steal a native-down key repeat");
    check(!p.event(49,false,false,false), "Native-down receives its up");
    check(p.event(49,true,false,false) && p.take(1), "Held prefix takes only exact fresh assigned key");
    check(!p.take(1), "Queue entry consumed once");
    check(!p.event(50,true,false,false), "Other number keys remain native");
    check(p.event(49,true,true,false) && !p.take(1), "Owned OS repeats suppressed without another request");
    check(!p.event(88,false,false,false) && !p.active(), "Prefix release exits immediately");
    check(p.event(49,true,true,false), "Release prefix mid-press cannot leak repeat to native");
    check(p.event(49,false,false,false), "Owned up swallowed even after prefix release");
    check(!p.event(49,true,false,false), "Next naked press passes immediately");
    p.event(49,false,false,false);
    p.configure(88,49,2,true,2,false,false);
    check(!p.event(88,true,false,false) && p.active(), "Toggle enters bars");
    check(!p.event(88,true,true,false) && p.active(), "Prefix repeat cannot flip toggle");
    p.event(88,false,false,false);
    check(p.event(49,true,false,false), "Toggle exact key suppressed");
    check(!p.event(88,true,false,false) && !p.active(), "Second prefix tap returns native page");
    check(p.event(49,false,false,false), "Toggle-off still pairs owned up");
    check(!p.event(49,true,false,false), "Toggle-off key remains native immediately");
    p.event(49,false,false,false); p.event(88,false,false,false);
    p.event(88,true,false,false); p.event(88,false,false,false);
    check(!p.event(49,true,false,true), "Ctrl/Alt/Shift chord remains native in bars page");
    check(!p.event(49,true,true,false), "Dropping modifier cannot adopt held native key");
    check(!p.event(49,false,false,false), "Native modifier chord keeps paired up");
    p.event(49,true,false,false);
    p.cancel();
    check(!p.take(2), "Editing/gate reset discards queued request");
    check(p.event(49,false,false,false), "Opening editor mid-press retains only paired-release ownership");
    p.configure(88,49,2,true,2,true,false);
    check(p.recovering && !p.event(49,true,false,false), "Held keys cannot resume after editing");
    p.event(49,false,false,false);
    p.configure(88,49,2,true,2,false,true);
    check(p.recovering, "Modifier release required for rearming");
    p.configure(88,49,2,true,2,false,false);
    check(!p.recovering && !p.active(), "Clean release rearms with native page");
    p.event(88,true,false,false); p.event(88,false,false,false); p.event(49,true,false,false);
    p.configure(88,50,2,true,3,true,false);
    check(!p.take(2) && !p.take(3), "Assignment/generation change drops queued use");
    check(p.event(49,false,false,false), "Changing assignment preserves old-key up pairing");
    p.configure(88,50,2,true,3,false,false);
    p.event(88,true,false,false); p.event(88,false,false,false);
    check(!p.event(49,true,false,false) && p.event(50,true,false,false), "Only replacement assignment suppressed");
    p.focusLost();
    check(!p.hasBlocked() && !p.take(3) && !p.active(), "Focus reset clears tracking and queue");
    p.configure(88,49,2,true,4,false,false);
    p.event(88,true,false,false); p.event(88,false,false,false);
    check(!p.event(13,true,false,false) && !p.active(), "Chat-open key cancels bars before native dispatch");
    for (int prefix : {5,6,88,67,9,20}) {
        ExtraBarsPolicy q; q.configure(prefix,49,1,true,1,false,false);
        q.event(prefix,true,false,false);
        check(q.event(49,true,false,false) && q.take(1), "Every allowed prefix supports Hold");
        check(q.event(49,false,false,false), "Every allowed prefix pairs key-up");
    }
    for (int prefix : {16,17,18,91,92,0}) {
        ExtraBarsPolicy q; q.configure(prefix,49,2,true,1,false,false);
        check(!q.eligible && !q.event(49,true,false,false), "Forbidden prefixes cannot suppress native");
    }
    for (int key : {13,27,16,17,18,91,92,117,123,256}) {
        ExtraBarsPolicy q; q.configure(88,key,2,true,1,false,false);
        check(!q.eligible, "System/editor keys cannot become bar suppression targets");
    }
    ExtraBarsPolicy burst; burst.configure(88,49,1,true,1,false,false); burst.event(88,true,false,false);
    for (int i=0; i<40; ++i) { burst.event(49,true,false,false); burst.event(49,false,false,false); }
    check(burst.queued == 32, "Queue remains bounded under a burst");
    for (int i=0; i<32; ++i) check(burst.take(1), "Bounded request order drains");
    check(!burst.take(1), "No synthetic retry after draining");
    burst.cancel();
    check(!burst.event(49,true,false,false), "Disabled bars never suppress naked keys");
    ExtraBarsPolicy multi;
    int table[256] = {}; table[49] = 11; table[50] = 22; table[51] = 33; table[52] = 44;
    multi.configureMany(88,table,2,true,10,false,false);
    check(!multi.event(49,true,false,false), "Multiple bindings: naked key still native"); multi.event(49,false,false,false);
    multi.event(88,true,false,false); multi.event(88,false,false,false);
    for (int vk : {49,50,51,52}) {
        check(multi.event(vk,true,false,false), "Every active mapped key suppressed");
        check(multi.event(vk,true,true,false), "Every mapped repeat suppressed");
        check(multi.event(vk,false,false,false), "Every mapped up paired");
    }
    for (int token : {11,22,33,44}) check(multi.takeToken(10)==token, "Queue preserves exact cross-bar slot token order");
    check(!multi.takeToken(10) && !multi.event(53,true,false,false), "Only assigned keys routed; no synthetic retry");
    multi.event(53,false,false,false); multi.event(49,true,false,false);
    table[49] = 55; multi.configureMany(88,table,2,true,10,true,false);
    check(!multi.takeToken(10) && !multi.active(), "Same-generation routing-table change cancels stale tokens");
    check(multi.event(49,false,false,false), "Old assigned down still pairs its up");
    multi.configureMany(88,table,1,true,11,false,false); multi.event(88,true,false,false);
    check(multi.event(49,true,false,false) && multi.takeToken(11)==55, "Hold routes replacement token");
    multi.event(49,false,false,false); multi.event(88,false,false,false);
    check(!multi.event(50,true,false,false), "Prefix release restores every mapped native key"); multi.event(50,false,false,false);
    table[17] = 9; multi.configureMany(88,table,2,true,12,false,false);
    check(!multi.eligible, "A forbidden entry fails the entire native table closed");
    table[17] = 0; table[88] = 3; multi.configureMany(88,table,2,true,12,false,false);
    check(!multi.eligible, "Prefix cannot also become a routed bar key");
    table[88] = 0; table[49] = -1; multi.configureMany(88,table,2,true,12,false,false);
    check(!multi.eligible, "Negative native tokens rejected");
    int empty[256] = {}; multi.configureMany(88,empty,2,true,12,false,false);
    check(!multi.eligible, "Empty routing table never suppresses");
    ExtraBarsPolicy always;
    int direct[256]={}; direct[49]=91; direct[88]=92;
    always.configureMany(0,direct,3,true,40,false,false);
    check(always.active(),"Always Active arms without a prefix");
    check(always.event(49,true,false,false),"Always mapped plain key consumed");
    check(always.event(49,true,true,false),"Always repeats retain ownership");
    check(always.takeToken(40)==91 && !always.takeToken(40),"Always one request per physical press");
    check(always.event(49,false,false,false),"Always paired release");
    check(!always.event(50,true,false,false),"Always unassigned key native"); always.event(50,false,false,false);
    check(!always.event(88,true,false,true),"Always modified shortcut native"); always.event(88,false,false,true);
    check(always.event(88,true,false,false) && always.takeToken(40)==92,"Remembered prefix usable as an Always cell key");
    always.cancel(); check(always.event(88,false,false,false),"Capture transition preserves consumed release");
    always.configureMany(0,direct,3,true,41,true,false);
    check(!always.active() && !always.takeToken(40),"Always held-key recovery and stale queue");
    always.configureMany(0,direct,3,true,41,false,false);
    check(always.active(),"Always resumes only after release");
    always.event(49,true,false,false); always.focusLost();
    check(!always.active() && !always.takeToken(41),"Focus loss cancels Always queue");
    always.configureMany(0,direct,3,true,42,false,false);
    check(always.active(),"Always re-arms after focus recovery");
    always.configureMany(0,direct,3,false,42,false,false); check(!always.active(),"Gameplay gate disables Always");
    always.configureMany(88,direct,3,true,42,false,false); check(!always.eligible,"Always requires zero native prefix");
    std::printf("ExtraBars native routing: %d checks PASS\n", checks);
}
