
use Terminal::Print;
use Term::ANSIColor;
my @colors = <red magenta yellow white>;

my $b = Terminal::Print.new;

$b.initialize-screen;

my @hearts;
for $b.grid-indices -> [$x,$y] {
    if $x %% 3 {
        $b[$x][$y] = colored('♥', @colors.roll);
        push @hearts, [$x,$y];
    }
}


for @hearts.pick( +@hearts ) -> [$x,$y] {
    $b[$x][$y].print-cell;
#    my $range = 0..0.010;
#    sleep 0.05 + $range.pick;   # longer hug
}

sleep 5;

$b.shutdown-screen;
