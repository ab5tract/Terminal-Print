use v6;

use Terminal::Print;


#| A basic rectangular widget that can work in relative coordinates
class Widget {
    has $.x is required;
    has $.y is required;  # i
    has $.w is required;
    has $.h is required;

    method print-string($x, $y, $str, $color = Empty) {
        T.print-string($!x + $x, $!y + $y, $str, |$color);  # ++
    }
}


#| A left-to-right colored progress bar
class ProgressBar is Widget {
    has $.max        = 100;
    has $.progress   = 0;
    has $.completed  = 'blue';
    has $.remaining  = 'red';
    has $.text-color = 'white';
    has $.text       = '';

    #| Set the current progress level and update the screen
    method set-progress($p) {
        $!progress = max(0, min($!max, $p));
        my $completed =  $.w * $!progress div $!max;
        my $left      = ($.w - $!text.chars) div 2;
        my $bar = ' ' x $left ~ $!text ~ ' ' x ($.w - $left - $!text.chars);

        # Loop if bar is thick (tall)
        for ^$.h {
            self.print-string(0,          $_, substr($bar, 0, $completed), "$!text-color on_$!completed");
            self.print-string($completed, $_, substr($bar,    $completed), "$!text-color on_$!remaining");
        }
    }
}


#| Center a (possibly-multiline) string in a viewport rectangle
sub print-centered($x1, $y1, $x2, $y2, $string) {
    my @lines = $string.lines;
    my $x = $x1 + ($x2 - $x1 - max(@lines>>.chars)) / 2;
    my $y = $y1 + ($y2 - $y1 - @lines) / 2;
    T.print-string($x, $y, $string);
}

my %hline = ascii  => '-', double => '═',
            light1 => '─', light2 => '╌', light3 => '┄', light4 => '┈',
            heavy1 => '━', heavy2 => '╍', heavy3 => '┅', heavy4 => '┉';

my %vline = ascii  => '|', double => '║',
            light1 => '│', light2 => '╎', light3 => '┆', light4 => '┊',
            heavy1 => '┃', heavy2 => '╏', heavy3 => '┇', heavy4 => '┋';

my %weight = ascii  => 'ascii', double => 'double',
             light1 => 'light', light2 => 'light',
             light3 => 'light', light4 => 'light',
             heavy1 => 'heavy', heavy2 => 'heavy',
             heavy3 => 'heavy', heavy4 => 'heavy';

my %corners = ascii  => < + + + + >,
              double => < ╔ ╗ ╚ ╝ >,
              light  => < ┌ ┐ └ ┘ >,
              heavy  => < ┏ ┓ ┗ ┛ >;

#| Draw a horizontal line
sub draw-hline($y, $x1, $x2, $style = 'double') {
    T.print-string($x1, $y, %hline{$style} x ($x2 - $x1 + 1));
}

#| Draw a vertical line
sub draw-vline($x, $y1, $y2, $style = 'double') {
    T.print-cell($x, $_, %vline{$style}) for $y1..$y2;
}

#| Draw a box
sub draw-box($x1, $y1, $x2, $y2, $style = Empty) {
    # Draw sides in order: left, right, top, bottom
    draw-vline($x1, $y1 + 1, $y2 - 1, |$style);
    draw-vline($x2, $y1 + 1, $y2 - 1, |$style);
    draw-hline($y1, $x1 + 1, $x2 - 1, |$style);
    draw-hline($y2, $x1 + 1, $x2 - 1, |$style);

    # Draw corners
    my @corners = |%corners{%weight{$style}};
    T.print-cell($x1, $y1, @corners[0]);
    T.print-cell($x2, $y1, @corners[1]);
    T.print-cell($x1, $y2, @corners[2]);
    T.print-cell($x2, $y2, @corners[3]);
}


#| Draw the current party state in the party viewport with upper left at $x, $y
sub show-party-state($x, $y, @party, $expanded?) {
    # XXXX: Nicer bars
    # XXXX: Condition icons (poisoned, low health, etc.)
    T.print-string($x, $y + 0, '  NAME    CLASS     HEALTH MAGIC');

    for @party.kv -> $i, $pc {
        my $row = sprintf '%d %-7s %-9s %-6s %-6s', $i + 1, $pc<name>, $pc<class>,
                              '*' x $pc<health>, '-' x $pc<magic>;
        T.print-string($x, $y + $i + 1, $row);
    }
}


#| Simulate a CRPG or Roguelike interface
sub MAIN(
    Bool :$ascii, #= Use only ASCII characters, no >127 codepoints
    Bool :$bench  #= Benchmark mode (run as fast as possible, with no sleeps or rate limiting)
    ) {

    my $short-sleep = .1 * !$bench;
    my $long-sleep  = 10 * !$bench;

    # Start up the fun!
    T.initialize-screen;

    # XXXX: Title screen
    # XXXX: Draw rubble below/to sides of title?
    my $standard = q:to/STANDARD/;
         ____        _                    __      _    _    _             _       
        |  _ \ _   _(_)_ __  ___    ___  / _|    / \  | | _| |_ __ _ _ __(_) __ _ 
        | |_) | | | | | '_ \/ __|  / _ \| |_    / _ \ | |/ / __/ _` | '__| |/ _` |
        |  _ <| |_| | | | | \__ \ | (_) |  _|  / ___ \|   <| || (_| | |  | | (_| |
        |_| \_\\\\__,_|_|_| |_|___/  \___/|_|   /_/   \_\_|\_\\\\__\__,_|_|  |_|\__,_|
        STANDARD

    my $pagga = q:to/PAGGA/;
        ░█▀▄░█░█░▀█▀░█▀█░█▀▀░░░█▀█░█▀▀░░░█▀█░█░█░▀█▀░█▀█░█▀▄░▀█▀░█▀█░
        ░█▀▄░█░█░░█░░█░█░▀▀█░░░█░█░█▀▀░░░█▀█░█▀▄░░█░░█▀█░█▀▄░░█░░█▀█░
        ░▀░▀░▀▀▀░▀▀▀░▀░▀░▀▀▀░░░▀▀▀░▀░░░░░▀░▀░▀░▀░░▀░░▀░▀░▀░▀░▀▀▀░▀░▀░
        PAGGA

    print-centered(0, 0, w, h * 3/4, $ascii ?? $standard !! $pagga);

    # XXXX: Loading bar
    my $bar = ProgressBar.new(:x((w - 50) div 2), :y(h * 2/3), :w(50), :h(3),
                              :text('L O A D I N G'));
    $bar.set-progress($_) for 0..100;

    # XXXX: Transition animation?

    # XXXX: Basic UI
    # XXXX: What about clearing grid?
    T.clear-screen;

    # Basic 3-viewport layout (map, party stats, log/input)
    my $party-width = 34;
    my $log-height  =  8;
    my $h-break     = w - $party-width - 2;
    my $v-break     = h - $log-height  - 2;

    my $style = $ascii ?? 'ascii' !! 'double';
    draw-box(0, 0, w - 1, h - 1, $style);
    draw-hline($v-break, 1, w - 2, $style);
    draw-vline($h-break, 1, $v-break - 1, $style);

    # Draw intersections if in full Unicode mode
    unless $ascii {
        T.print-cell(0, $v-break, '╠');
        T.print-cell(w, $v-break, '╣');
        T.print-cell($h-break, 0, '╦');
        T.print-cell($h-break, $v-break, '╩');
    }

    # Map
    print-centered(1, 1, $h-break - 1, $v-break - 1, 'THIS IS THE MAP AREA');

    # Characters
    my @party =
        { :name<Fennic>,  :class<Ranger>,    :health<5>, :magic<3> },
        { :name<Galtar>,  :class<Cleric>,    :health<4>, :magic<4> },
        { :name<Salnax>,  :class<Sorcerer>,  :health<3>, :magic<6> },
        { :name<Torfin>,  :class<Barbarian>, :health<6>, :magic<0> },
        { :name<Trentis>, :class<Rogue>,     :health<4>, :magic<0> };

    show-party-state($h-break + 1, 1, @party);

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
