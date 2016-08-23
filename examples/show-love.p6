use lib './lib';

use Terminal::Print;
# use Terminal::ANSIColor;
my @colors = <red magenta yellow white>;

my $b = Terminal::Print.new;

$b.initialize-screen;

for $b.grid-indices.pick(*) -> [$x,$y] {
    next unless $x %% 3;
    $b.print-cell: $x, $y, %( char => '♥', color => @colors.roll);
}

sleep 5;

$b.shutdown-screen;
