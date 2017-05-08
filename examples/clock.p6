# ABSTRACT: An animated clock

use v6;
use Terminal::Print;

my $figlet = (q:x{which figlet} || q:x{which toilet}).trim;
my $base-x = w div 2;
my $base-y = h div 2;
my $radius = min($base-x, $base-y * 2) - 1;  #=

sub print-centered($cx, $cy, $string) {
    return unless $string;

    my @lines = $string.lines;
    my $width = @lines».chars.max;
    my $x = $cx -  $width div 2;
    my $y = $cy - +@lines div 2;
    T.print-string($x, $y, $string);
}

sub print-seconds($cx, $cy, $r, $time) {
    my $sec = $time.second.Int;
    my $rad = τ * $sec / 60;
    my $x   = $cx + $r * sin($rad);
    my $y   = $cy - $r * cos($rad) / 2;

    if $sec %% 5 {
        T.clear-screen if $sec == 0;
        T.print-string($x - 1, $y, $sec.fmt('%02d'));
    }
    else {
        T.print-string($x, $y, '*');
    }
}

T.initialize-screen;

my $end-time = DateTime.now.later( :1minutes );
my $exit = Promise.new;
my $s = Supply.interval(1);
$s.tap: {
    state $clear-string = '';
    my $now = DateTime.now(formatter => { sprintf '%d:%02d', .hour, .minute });
    if $now <= $end-time {
        print-seconds($base-x, $base-y, $radius, $now);

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

await $exit;
