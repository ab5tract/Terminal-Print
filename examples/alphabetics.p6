# ABSTRACT: Show random pages of characters from various "alphabets"

use v6;
use Terminal::Print;

my $p = Terminal::Print.new();

$p.initialize-screen;

my @char-ranges = '■'..'◿','ぁ'..'ゟ','᠀'..'ᢨ','ᚠ'..'ᛰ','Ꭰ'..'Ᏼ','─'..'╿';
# my @char-ranges = '─'..'╿', 'ᚠ'..'ᛰ';

for @char-ranges.pick(*) -> @alphabet {
    $p.current-grid.clear;
    for $p.indices -> [$x,$y] {
        $p.change-cell($x, $y, @alphabet.roll)
            if $y %% 7 || ($x %% (1..5).roll || $y %% (1..6).roll);
    }
    print $p.current-grid.Str;
}

sleep 2;
$p.shutdown-screen;
