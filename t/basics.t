use Test;
use lib 'lib';

plan 17;

use Terminal::Print; pass "Import Terminal::Print";

use Terminal::ANSIColor;

my @colors = <red magenta yellow white>;

my $b;
lives-ok { $b = Terminal::Print.new; }, "Can create a Terminal::Print object";

lives-ok { do { sleep 1; $b.initialize-screen;  $b.shutdown-screen; } }, "Can initialize and shutdown screen";

lives-ok {
    do {
        sleep 1;
        $b.initialize-screen;
        for $b.grid-indices -> [$x,$y] {
            # pretty, .. but slow.
            #            $b[$x][$y] = colored('♥', @colors.roll);
            $b[$x][$y] = '♥';
            $b.print-cell($x,$y);
        }
        sleep 1;
        $b.shutdown-screen;
    }
}, "Can print a screen full of hearts one at a time";

lives-ok {
    do {
        sleep 1;
        $b.initialize-screen;
        print ~$b.grid-object(0);
        sleep 1;
        $b.shutdown-screen;
    }
}, "Can print the whole screen by stringifying the default grid object";

lives-ok {
    do {
        sleep 1;
        $b.initialize-screen;
        $b.print-grid(0);
        sleep 1;
        $b.shutdown-screen;
    }
}, "Can print the whole screen by using .print-screen with a grid index";

lives-ok {
    $b.add-grid('5s');
}, "Can add a (named) grid";

lives-ok {
    $b.clone-grid(0);
}, "Can clone a grid (index origin)";

lives-ok {
    $b.clone-grid(0,'hearts-again');
}, "Can clone a grid (index origin, named destination)";

lives-ok {
    $b.clone-grid('5s');
}, "Can clone a grid (named index)";

lives-ok {
    $b.clone-grid('5s','5s+2');
}, "Can clone a grid (named index, named destination)";

lives-ok {
    do {
        $b.initialize-screen;
        $b.print-grid('hearts-again');
        sleep 1;
        $b.shutdown-screen;
    }
}, "Cloned screen 'hearts-again' prints the same hearts again";

ok +$b.grids[*] == 6, 'There are the expected number of grids available through $b.grids';

ok $b.clone-grid(0,'h4') === $b.grids[*-1], ".clone-grid returns the clone itself";

lives-ok {
    do {
        $b.initialize-screen;
        $b.grid-object('hearts-again').grep-grid({$^x %% 3 and $^y %% 2 || $x %% 2 and $y %% 3 || so $x|$y %% 7}, :o);
        sleep 1;
        $b.shutdown-screen;
    }
}, "Printing individual hearts based on grep-grid";

lives-ok {
    do {
        $b.initialize-screen;
        sleep 1;
        $b.print-grid('hearts-again');
        sleep 1;
        $b.shutdown-screen;
    }
}, "print-grid('hearts-again') (aka the same grid) prints the same as the previous run";

lives-ok {
    do {
        $b.initialize-screen;
        sleep 1;
        $b.blit(0);
        sleep 1;
        $b.blit('hearts-again');
        sleep 1;
        $b.blit(0);
        sleep 0.5;
        $b.blit('hearts-again');
        sleep 0.5;
        $b.blit(0);
        sleep 0.5;
        $b.blit('hearts-again');
        sleep 0.5;
        $b.blit(0);
        sleep 0.5;
        $b.blit('hearts-again');
        sleep 0.5;
        $b.blit(0);
        sleep 0.5;
        $b.blit('hearts-again');
        sleep 1;
    }
}, "blitting between grids works";
