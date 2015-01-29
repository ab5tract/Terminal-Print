
use Terminal::Print;

my $b = Terminal::Print.new;   # TODO: take named parameter for grid name of default grid

$b.initialize-screen;

for 1..^$b.max-columns -> $x {
    $b[$x-1][11].blank-cell;
    $b[$x][11] = '_';
    $b[$x][11].print-cell;
    sleep 0.05;
}

$b.shutdown-screen;
