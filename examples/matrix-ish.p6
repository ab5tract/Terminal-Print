use v6;

use lib './lib';
use Terminal::Print;

my $t = Terminal::Print.new;

$t.initialize-screen;

my @indices = $t.grid-indices;

#my @chars = '─'..'╿';
my @chars = 'ァ'..'ヿ';
my @columns = ^$t.columns;

my @xs = @columns.pick(*).grep(* %% 6).rotor(5, :partial);

while +@xs {
    my @x-range = |@xs.pop;
    await do for @x-range -> $x {
        start {
            for ^$t.rows -> $y {
                my $string-printed;
                last if ^21 .roll == 7;
                until ^42 .roll == 0 and $string-printed {
                    unless ^5 .roll == 3 {
                        $t.print-cell($x, $y, @chars.roll);
                        $string-printed = True;
                    }
                }
            }
        }
    }
}

$t.shutdown-screen;
