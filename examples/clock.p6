
use Terminal::Print;
# use Terminal::Print::Animation;

# my $figlet = q:x{which figlet} ?? True !! False;
my $figlet = False;

my $t = Terminal::Print.new;
#
my $base-x = ($t.columns / 2).floor;
my $base-y = ($t.rows / 2).floor;

$t.initialize-screen;

my $end-time = DateTime.now.later( :20seconds );
my $exit = Promise.new;
my $s = Supply.interval(1);
my $old-string = '';
$s.tap: {
    my $now = DateTime.now(formatter => { sprintf "%02d:%02d:%02d",.hour,.minute,.second });
    my $fig-now;
    if $figlet {
        $fig-now = qq:x[figlet -f bubble $now];
    }
    if $now <= $end-time {
        my $string = $fig-now ?? $fig-now !! $now;
        # $old-string stays unset unless $figlet is true
        if $old-string {
            $t.print-string($base-x, $base-y, $old-string);
        }
                # width of the time string is 8, so we subtract 4 to center
        $t.print-string($base-x - 4, $base-y, $string);
        if $figlet {
            $old-string = $string;
            $old-string ~~ s:g/\S/ /;
        }
    } else {
        $t.shutdown-screen;
        $exit.keep;
    }
};

class Circle {
    has $.c is required = 60;
    has $.r = ($!c / (2 * π)).round;
    has $.t;
    has $.ratio;

    method draw($x0 is copy, $y0 is copy, $char ) {
        my $f = 1 - $!r;
        my $ddF_x = 0;
        my $ddF_y = -2 * $!r;
        my ($x, $y) = 0, $!r;
        $x0 -= ($x0 / $!ratio).ceiling - 4*$!r + 32 + 6;
        $y0 += ($y0 / $!ratio).ceiling - $!r - 24 - 1;
        self.set-cell($x0, $y0 + $!r, $char);
        self.set-cell($x0, $y0 - $!r, $char);
        self.set-cell($x0 + $!r, $y0, $char);
        self.set-cell($x0 - $!r, $y0, $char);
        while $x < $y {
            if $f >= 0 {
                $y--;
                $ddF_y += 2;
                $f += $ddF_y;
            }
            $x++;
            $ddF_x += 2;
            $f += $ddF_x + 1;
            self.set-cell($x0 + $x, $y0 + $y, $char);
            self.set-cell($x0 - $x, $y0 + $y, $char);
            self.set-cell($x0 + $x, $y0 - $y, $char);
            self.set-cell($x0 - $x, $y0 - $y, $char);
            self.set-cell($x0 + $y, $y0 + $x, $char);
            self.set-cell($x0 - $y, $y0 + $x, $char);
            self.set-cell($x0 + $y, $y0 - $x, $char);
            self.set-cell($x0 - $y, $y0 - $x, $char);
        }
    }

    method set-cell($x, $y, $char) {
        # $!t(($x * $!ratio).ceiling, ($y / $!ratio).ceiling, $char);
        $!t($x * $!ratio, $y, $char);
    }
}

$t.initialize-screen;

# my $c = 60;
# my $r = $c / (2 * π);
# say $r.round;
#
# my $theta = 0;
# my $step = 360 / $c;
# repeat until $theta >= 360 {
#     my $x = ($base-x + ($r * cos($theta) * 1.4).floor);
#     my $y = ($base-y - ($r * sin($theta)).floor); #.ceiling;
#     $t($x, $y, 'O');
#     $theta += $step;
# }

my $c = Circle.new: c => 80, ratio => 1.8, :$t;
$c.draw($base-x, $base-y + $c.r, '*');

# for -$r..$r -> $x {
#     for -$r..$r -> $y {
#
#     }
# }

# sleep 5;

await $exit;

$t.shutdown-screen;
