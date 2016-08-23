use Test;
use lib 'lib';

chdir('t');
plan 3;

# our little corpus slurper
sub slurp-corpus($topic) {
    "corpus/$topic".IO.slurp;
}

use Terminal::Print;

my $b = Terminal::Print.new;

lives-ok {
    do {
        for $b.grid-indices -> [$x, $y] {
            $b.change-cell($x, $y, '♥');
        }
    }
}, "Can .change-cell a grid to be full of hearts, one at a time";

lives-ok {
    do {
        $b.initialize-screen;
        print ~$b;
        sleep 2;
        $b.shutdown-screen;
    }
}, "Can print the current grid";

lives-ok {
    my @colors = <magenta red yellow blue green cyan>;
    do {
        $b.initialize-screen;
        for $b.grid-indices -> [$x, $y] {
            $b.print-cell: $x, $y, %( :char('♥'), :color(@colors.roll) );
        }
        $b.shutdown-screen;
    }
}, "Can print a screen full of multi colored hearts";
