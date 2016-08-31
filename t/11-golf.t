use v6;

use Terminal::Print;
use Test;

#lives-ok do { draw( -> Promise $p {
#    my $secondly = Supply.interval(1);
#    $secondly.tap: { T.print-string(50, 25, DateTime.now(formatter => { sprintf "%02d:%02d:%02d",.hour,.minute,.second })) };
#
#    my $ender = Supply.interval(15);
#    $ender.tap: { $++ && $p.keep };
#}); }, "Lives through calling the draw sub";

initialize-screen;

T(50, 15, "hello!");

my $t = T;
sleep 5;

shutdown-screen;

dd $t;



#ok T ~~ Terminal::Print, "T is our homey, a Terminal::Print object";
