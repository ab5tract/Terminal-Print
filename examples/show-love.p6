use lib './lib';

use Terminal::Print;
my @colors = <red magenta yellow white>;

my $b = Terminal::Print.new;
$b.initialize-screen;

for $b.indices.pick(*) -> [$x,$y] {
    next unless $x %% 3;
    $b.print-cell: $x, $y, %( char => '♥', color => @colors.roll );
}

sleep 2;
$b.shutdown-screen;

### Golfed version!
# perl6 -Ilib -MTerminal::Print -e 'd({for in.grep({$_[0]%%3}).pick(*) ->[$x,$y]{cl($x,$y,"♥",fgc.roll)};slp(2);$^p.keep });'
### Fancier!
# perl6 -MTerminal::Print -e 'd({ while $++ < 4 { for my @in = in.grep({$_[0] %% 3}).pick(*) -> [$x,$y] { cl($x,$y,"♥", fgc.roll) }; for @in.reverse -> [$x,$y] { cl($x,$y," ") }; }; $^p.keep })'
