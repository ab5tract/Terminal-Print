use v6;

use Terminal::Print;
use Test;

plan 1;
 
my $STOP-TIME = %*ENV<STOP_TIME> // 0;


subtest {
    ok T ~~ Terminal::Print, "T is a Terminal::Print object";
    
    lives-ok {
        do draw( -> Promise $p {
            my $secondly = Supply.interval(1);
            $secondly.tap: { T.print-string(T.columns/2, T.rows/2, DateTime.now(formatter => { sprintf "%02d:%02d:%02d",.hour,.minute,.second })) };
            my $ender = Supply.interval($STOP-TIME);
            # stop-time of 0 should short-circuit the "don't fire on first tick" anonymous state counter
            $ender.tap: { (!$STOP-TIME || $++) && $p.keep };
        });
    }, "Lives through calling the draw sub";
}, "All the expected golf patterns behave as expected";
