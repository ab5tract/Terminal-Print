use v6;

use lib './lib';
use Terminal::Print;

my $t = Terminal::Print.new;

$t.initialize-screen;

my @indices = $t.grid-indices;

my @chars = '─'..'╿';
my @columns = ^$t.max-columns;

my @xs = @columns.pick(*).rotor(5, :partial);

while +@xs {
    my @x-range = |@xs.pop;
    await do for @x-range -> $i {
        start {
            for ^$t.max-rows -> $y {
                my $string-printed;
                until (^20).roll == 0 and $string-printed {
                    $t.print-cell($i, $y, @chars.roll);
                    $string-printed = True;
                }
            }
        }
    }
}

$t.shutdown-screen;
