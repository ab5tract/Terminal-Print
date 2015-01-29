use Test;
use lib 'lib';

plan 7;

use Terminal::Print; pass "Import Terminal::Print";

use Term::ANSIColor;

my @colors = <red magenta yellow white>;

my $b;
lives_ok { $b = Terminal::Print.new; }, "Can create a Terminal::Print object";

lives_ok { do { sleep 1; $b.initialize-screen;  $b.shutdown-screen; } }, "Can initialize and shutdown screen";

lives_ok {
    do {
        sleep 1;
        $b.initialize-screen;
        for $b.grid-indices -> [$x,$y] {
            # pretty, .. but slow.
#            $b[$x][$y] = colored('♥', @colors.roll);
            $b[$x][$y] = '♥';
            $b[$x][$y].print-cell;
        }
        sleep 1;
        $b.shutdown-screen;
    }
}, "Can print a screen full of hearts one at a time";

lives_ok {
    do {
        sleep 1;
        $b.initialize-screen;
        print ~$b.grid-object(0);
        sleep 1;
        $b.shutdown-screen;
    }
}, "Can print the whole screen by stringifying the default grid object";

lives_ok {
    do {
        sleep 1;
        $b.initialize-screen;
        $b.print-grid(0);
        sleep 1;
        $b.shutdown-screen;
    }
}, "Can print the whole screen by using .print-screen with a grid index";

lives_ok {
    $b.add-grid('4s');
}, "Can add a (named) grid";

