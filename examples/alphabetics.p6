use v6;
use lib './lib';

use Terminal::Print;

my $p = Terminal::Print.new(cursor-profile => 'universal');

$p.initialize-screen;

# my @char-ranges = '■'..'◿','ぁ'..'ゟ','᠀'..'ᢨ','ᚠ'..'ᛰ','Ꭰ'..'Ᏼ','─'..'╿';
my @char-ranges = '─'..'╿', 'ᚠ'..'ᛰ';

for @char-ranges.pick(*) -> @alphabet {
    for $p.indices -> [$x,$y] {
        $p.print-cell($x, $y, @alphabet.roll)
            if $y %% 7 || ($x %% (1..5).roll || $y %% (1..6).roll);
    }
    $p.clear-screen;
}

$p.shutdown-screen;
