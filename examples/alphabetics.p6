use v6;
use lib './lib';

use Terminal::Print;

my $p = Terminal::Print.new;

$p.initialize-screen;

#say $p.grid-indices.perl;

#my @char-ranges = '■'..'◿','ぁ'..'ゟ','᠀'..'ᢨ','ᚠ'..'ᛰ','Ꭰ'..'Ᏼ','─'..'╿';
my $alphabet = '─'..'╿';
#for @char-ranges[0].pick(*) -> $alphabet {
for ^10 {
    for $p.grid-indices -> [$x,$y] {
        if $x %% (0..5).roll || $y %% (0..6).roll {
            $p[$x][$y] = $alphabet.roll;
            $p.print-cell($x,$y);
        } elsif $y %% 7 { 
            $p[$x][$y] = $alphabet.roll;
            $p.print-cell($x,$y);
        }
    }
    #    sleep 5;
    $p.clear-screen;
}

$p.shutdown-screen;
