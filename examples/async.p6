use v6;

use lib './lib';
use Terminal::Print;

my $t = Terminal::Print.new;   # TODO: take named parameter for grid name of default grid

$t.initialize-screen;

my @indices = $t.grid-indices;

my @alphabet = 'j'..'z';

my @rotor = (^$t.rows).rotor(10, :partial)>>.Array;
my $thread = 0;

# just a coinflipper, at the moment.
sub choosey() { <1 2 3>.roll %% 2 }

await do for @rotor -> @ys {
    my $char := @alphabet.pick;
    my $p = start {
        my @xs = ^3 .pick %% 2  ?? (^$t.columns).reverse
                                !! ^$t.columns;
        my @ys-rev := @ys.reverse;
        for @xs -> $x {
            my @yss := choosey()    ?? @ys-rev
                                    !! @ys;
            for @yss -> $y {
                $t.print-cell($x, $y, choosey() ?? $char !! $char.uc);
            }
        }
    }
    $p
}

$t.shutdown-screen;
