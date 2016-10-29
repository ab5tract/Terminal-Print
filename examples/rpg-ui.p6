use v6;

use Terminal::Print;


#| A left-to-right colored progress bar
class ProgressBar {
    has $.x is required;
    has $.y is required;  # i
    has $.w is required;

    has $.max        = 100;
    has $.progress   = 0;
    has $.completed  = 'blue';
    has $.remaining  = 'red';
    has $.text-color = 'white';
    has $.text       = '';

    #| Set the current progress level and update the screen
    method set-progress($p) {
        $!progress = max(0, min($!max, $p));
        my $completed =  $!w * $!progress div $!max;
        my $left      = ($!w - $!text.chars) div 2;
        my $bar = ' ' x $left ~ $!text ~ ' ' x ($!w - $left - $!text.chars);

        T.print-string($!x,              $!y, substr($bar, 0, $completed), "$!text-color on_$!completed");
        T.print-string($!x + $completed, $!y, substr($bar,    $completed), "$!text-color on_$!remaining");
    }
}


#| Center a (possibly-multiline) string in a viewport rectangle
sub print-centered($x1, $y1, $x2, $y2, $string) {
    my @lines = $string.lines;
    my $x = $x1 + ($x2 - $x1 - max(@lines>>.chars)) / 2;
    my $y = $y1 + ($y2 - $y1 - @lines) / 2;
    T.print-string($x, $y, $string);
}


#| Draw a horizontal line
sub draw-hline($y, $x1, $x2) {
    T.print-string($x1, $y, '-' x ($x2 - $x1 + 1));
}

#| Draw a vertical line
sub draw-vline($x, $y1, $y2) {
    T.print-cell($x, $_, '|') for $y1..$y2;
}

#| Draw a box
sub draw-box($x1, $y1, $x2, $y2) {
    # Draw sides in order: left, right, top, bottom
    draw-vline($x1, $y1 + 1, $y2 - 1);
    draw-vline($x2, $y1 + 1, $y2 - 1);
    draw-hline($y1, $x1 + 1, $x2 - 1);
    draw-hline($y2, $x1 + 1, $x2 - 1);

    # Draw corners
    T.print-cell($x1, $y1, '+');
    T.print-cell($x2, $y1, '+');
    T.print-cell($x1, $y2, '+');
    T.print-cell($x2, $y2, '+');
}


#| Draw the current party state in the party viewport with upper left at $x, $y
sub show-party-state($x, $y, @party, $expanded?) {
    # for @party.kv
}


#| Simulate a CRPG or Roguelike interface
sub MAIN(
    Bool :$bench  #= Benchmark mode (run as fast as possible, with no sleeps or rate limiting)
    ) {

    my $short-sleep = .1 * !$bench;
    my $long-sleep  = 10 * !$bench;

    # Start up the fun!
    T.initialize-screen;

    # XXXX: Title screen
    print-centered(0, 0, w, h - 4, 'R U I N S   O F   A K T A R I A');

    # XXXX: Loading bar
    my $bar = ProgressBar.new(:x((w - 50) / 2), :y(h / 2), :w(50), :text('L O A D I N G'));
    $bar.set-progress($_) for 0..100;

    # XXXX: Transition animation?

    # XXXX: Basic UI
    # XXXX: What about clearing grid?
    T.clear-screen;

    # Basic 3-viewport layout (map, party stats, log/input)
    my $party-width = 40;
    my $log-height  =  8;
    my $h-break     = w - $party-width - 2;
    my $v-break     = h - $log-height  - 2;

    draw-box(0, 0, w - 1, h - 1);
    draw-hline($v-break, 1, w - 2);
    draw-vline($h-break, 1, $v-break - 1);

    # Map
    print-centered(1, 1, $h-break - 1, $v-break - 1, 'THIS IS THE MAP AREA');

    # Characters
    # XXXX: Nicer bars
    # XXXX: Condition icons (poisoned, low health, etc.)
    T.print-string($h-break + 1, 1, '   NAME     CLASS      HEALTH   MAGIC');
    T.print-string($h-break + 1, 2, '1  Fennic   Ranger     ******   ---');
    T.print-string($h-break + 1, 3, '2  Galtar   Cleric     *****    ----');
    T.print-string($h-break + 1, 4, '3  Salnax   Sorcerer   ****     ------');
    T.print-string($h-break + 1, 5, '4  Torfin   Barbarian  *******  ');
    T.print-string($h-break + 1, 6, '5  Trentis  Rogue      *****    ');

    # Log/input
    T.print-string(1, $v-break + 1, 'Game state loaded.');
    T.print-string(1, $v-break + 2, '> ');

    # XXXX: Accordion character details
    # XXXX: Popup help
    # XXXX: Pan game map
    # XXXX: Battle!
    # XXXX: Battle results splash

    # Final sleep
    sleep $long-sleep;

    # Return to our regularly scheduled not-gaming
    T.shutdown-screen;
}
