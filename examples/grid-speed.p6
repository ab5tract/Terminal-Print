# ABSTRACT: Test raw speed of grid operations

use v6;
use Terminal::Print <T>;

T.initialize-screen;
my $grid = T.current-grid;
my $t0 = now;

my @colors = '', 'underline';

for @colors -> $color {
    for ^10_000 -> $i {
        my $string = ~$i;
        my $chars  = $string.chars;
        for ^20 -> $y {
            $grid.set-span($y, $y, $string, $color);
            print $grid.span-string($y, $y + $chars - 1, $y);
        }
    }
}

my $t1 = now;
T.shutdown-screen;
printf "Completed in %.3f seconds\n", $t1 - $t0;
