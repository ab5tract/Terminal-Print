# ABSTRACT: Asynchronous race across the display

use v6;
use Terminal::Print;


T.initialize-screen;

my @indices = T.indices;

my @alphabet = 'j'..'z';

my @rotor = (^T.rows).rotor(10, :partial)>>.Array;
my $thread = 0;

# just a coinflipper, at the moment.
sub choosey() { <1 2 3>.roll %% 2 }

await do for @rotor -> @ys {
    my $char := @alphabet.pick;
    my $p = start {
        my @xs = ^3 .pick %% 2  ?? (^T.columns).reverse
                                !! ^T.columns;
        my @ys-rev := @ys.reverse;
        for @xs -> $x {
            my @yss := choosey()    ?? @ys-rev
                                    !! @ys;
            for @yss -> $y {
                T.print-cell($x, $y, choosey() ?? $char !! $char.uc);
            }
        }
    }
    $p
}

T.shutdown-screen;
