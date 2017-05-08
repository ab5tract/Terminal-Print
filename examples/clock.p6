# ABSTRACT: An animated clock

use v6;
use Terminal::Print;
# use Terminal::Print::Animation;

my $figlet = (q:x{which figlet} || q:x{which toilet}).trim;
my $base-x = w div 2;
my $base-y = h div 2;  # ==

sub print-centered($cx, $cy, $string) {
    return unless $string;

    my @lines = $string.lines;
    my $width = @lines».chars.max;
    my $x = $cx -  $width div 2;
    my $y = $cy - +@lines div 2;
    T.print-string($x, $y, $string);
}

T.initialize-screen;

my $end-time = DateTime.now.later( :1minutes );
my $exit = Promise.new;
my $s = Supply.interval(1);
$s.tap: {
    state $clear-string = '';
    my $now = DateTime.now(formatter => *.hh-mm-ss);
    if $now <= $end-time {
        if $figlet {
            my $fig-now = qq:x[$figlet -W -f standard $now];
            print-centered($base-x, $base-y, $clear-string);
            print-centered($base-x, $base-y, $fig-now);
            $clear-string = $fig-now.subst(/\S/, ' ', :g);
        }
        else {
            print-centered($base-x, $base-y, $now);  #,,
        }
    } else {
        T.shutdown-screen;
        $exit.keep;
    }
};

class Clock {
    has $.c is required = 60;
    has $.r = ($!c / (2 * π)).round;
    has $.ratio;
    has @.points;
    has $!index = 0;

    method fill($x0 is copy, $y0 is copy, $char ) {
        my $f = 1 - $!r;
        my $ddF_x = 0;
        my $ddF_y = -2 * $!r;
        my ($x, $y) = 0, $!r;
        $x0 -= $!r + 1;
        $y0 += ($!r/2).floor;
        # $x0 -= ($x0 / $!ratio).ceiling - 4*$!r + 32 + 6;
        # $y0 += ($y0 / $!ratio).ceiling - $!r - 24 - 1;
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
        # T.(($x * $!ratio).ceiling, ($y / $!ratio).ceiling, $char);
        # T.($x * $!ratio, $y / $!ratio, $char);
        @!points.push: [ ($x * $!ratio), ($y / $!ratio), $char ];
    }

    method draw-point() {
        state $total = +@!points;
        state $step-size = ($total / 60).floor;
        my $point = @!points[$!index];
        if $!index > 0 {
            my $last-point = @!points[$!index - 1];
            T.($last-point[0], $last-point[1], ' ');
        }
        T.($point[0], $point[1], %( char => $point[2], color => 'black on_cyan'));
        $!index += $step-size;
    }
}

my $c = Clock.new: c => 80, ratio => 1.4;
$c.fill($base-x, $base-y, '*');

$s.tap: {
    $c.draw-point();
};

await $exit;

T.shutdown-screen;
