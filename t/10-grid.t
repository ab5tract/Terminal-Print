#use lib 'lib';

#chdir('t');
#plan 3;

## our little corpus slurper
#sub slurp-corpus($topic) {
#    "corpus/$topic".IO.slurp;
#}

use Test;
use Terminal::Print;

my $b = Terminal::Print.new;

my $SLEEP_TIME = %*ENV<SLEEP_TIME> // 0.1;

plan 1;

subtest {
    plan 3;

    lives-ok {
        for $b.indices -> [$x, $y] {
            $b.change-cell($x, $y, '♥');
        }
    }, "Can .change-cell a grid to be full of hearts, one at a time";
    
    lives-ok {
        $b.initialize-screen;
        print ~$b;
        sleep $SLEEP_TIME;
        $b.shutdown-screen;
    }, "Can print the current grid";
    
    lives-ok {
        my @colors = <magenta red yellow blue green cyan>;
        $b.initialize-screen;
        for $b.indices -> [$x, $y] {
            $b.print-cell: $x, $y, %( :char('♥'), :color(@colors.roll) );
        }
        sleep $SLEEP_TIME;
        $b.shutdown-screen;
    }, "Can print a screen full of multi colored hearts";
}, "Basic screen of hearts can be generated in the expected fashion";
