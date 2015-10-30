use v6;
use lib './lib';

use Terminal::Print;

my $p = Terminal::Print.new;

$p.initialize-screen;

#say $p.grid-indices.perl;

my @char-ranges = '■'..'◿','ぁ'..'ゟ','᠀'..'ᢨ';

for @char-ranges.pick(*) -> $alphabet {
    for $p.grid-indices -> [$x,$y] {
        next if $x %% (1..5).roll || $y %% (1..6);
        $p[$x][$y] = $alphabet.roll(1);
        $p.print-cell($x,$y);
    }
    sleep 5;
    $p.clear-screen;
}

$p.shutdown-screen;
