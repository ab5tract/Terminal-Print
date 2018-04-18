use v6.d.PREVIEW;

use Terminal::Print <T>;
use Test;

plan 1;

my $STOP-TIME = %*ENV<STOP_TIME> // 0;


subtest {
    ok T ~~ Terminal::Print, "T is a Terminal::Print object";

    lives-ok {
        do draw( -> Promise $p {
            my $secondly = Supply.interval(1);
            my $ender = Supply.interval($STOP-TIME max .001);
            react {
                whenever $secondly { T.print-string(T.columns/2, T.rows/2, DateTime.now(formatter => { sprintf "%02d:%02d:%02d",.hour,.minute,.second })) }
                # stop-time of 0 should short-circuit the "don't fire on first tick" anonymous state counter
                whenever $ender { (!$STOP-TIME || $++) && done }
            }
            $p.keep;
        });
    }, "Lives through calling the draw sub";
}, "All the expected golf patterns behave as expected";
