use v6;
use lib './lib';

use Terminal::Print;

my $p = Terminal::Print.new;

$p.initialize-screen;

#say $p.grid-indices.perl;

#my @char-ranges = '■'..'◿','ぁ'..'ゟ','᠀'..'ᢨ','ᚠ'..'ᛰ','Ꭰ'..'Ᏼ','─'..'╿';
my @alphabet = '─'..'╿';
#for @char-ranges[0].pick(*) -> $alphabet {
for ^10 {
    for $p.grid-indices -> [$x,$y] {
        if $x %% (0..5).roll || $y %% (0..6).roll || $y %% 7 {
            #my $t = now;
            $p[$x][$y] = @alphabet.roll;
            #my $u = now;
            $p.print-cell($x,$y);
            #print "\e[1;1H\e[32m{ $u - $t }\n\e[33m{ now - $u }\e[0m";
        }
    }
    #    sleep 5;
    $p.clear-screen;
}

$p.shutdown-screen;
