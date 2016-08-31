use v6;

use Terminal::Print;
use Test;

plan 2;
 
my $STOP-TIME = %*ENV<STOP_TIME> // 0;

lives-ok {
    draw( -> Promise $p {
        my $secondly = Supply.interval(1);
        $secondly.tap: { T.print-string(50, 25, DateTime.now(formatter => { sprintf "%02d:%02d:%02d",.hour,.minute,.second })) };
        my $ender = Supply.interval($STOP-TIME);
        # stop-time of 0 should short-circuit the "don't fire on first tick" anonymous state counter
        $ender.tap: { (!$STOP-TIME || $++) && $p.keep };
    });
}, "Lives through calling the draw sub";

ok T ~~ Terminal::Print, "T is a Terminal::Print object";
