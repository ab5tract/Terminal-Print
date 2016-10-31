use v6;

use Terminal::Print;


#| A basic rectangular widget that can work in relative coordinates
class Widget {
    has $.x is required;
    has $.y is required;  # i
    has $.w is required;
    has $.h is required;

    has $.grid = Terminal::Print::Grid.new($!w, $!h);

    # Simply copies widget contents onto the current display grid for now,
    # optionally also printing updated contents to the screen
    method composite(Bool $print?) {
        my $from = $!grid.grid;
        my $cg   = T.current-grid;
        my $to   = $cg.grid;
        my $x2   = $!x + $!w - 1;
        my $out  = '';

        for ^$!h -> $y {
            for ^$!w -> $x {
                $to[$x + $!x][$y + $!y] = $from[$x][$y];
            }
            $out ~= $cg.span-string($!x, $x2, $y + $!y) if $print;  # )))
        }

        print $out if $print;
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
        # Compute length of completed portion of bar
        $!progress    = max(0, min($!max, $p));
        my $completed = $.w * $!progress div $!max;

        # Loop over bar thickness (height) setting color spans
        for ^$.h {
            $.grid.set-span-color(0, $completed - 1,   $_, "$!text-color on_$!completed");
            $.grid.set-span-color($completed, $.w - 1, $_, "$!text-color on_$!remaining");
        }

        # Overlay text
        my @lines = $!text.lines;
        my $top = ($.h - @lines) div 2;
        for @lines.kv -> $i, $line {
            $.grid.set-span-text(($.w - $line.chars) div 2, $top + $i, $line);
        }

        # Update screen
        self.composite(True);
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

sub wrap-text($w, $text, $prefix = '') {
    my @words = $text.words;
    my @lines = @words.shift;

    for @words -> $word {
        if $w < @lines[*-1].chars + 1 + $word.chars {
            push @lines, "$prefix$word";
        }
        else {
            @lines[*-1] ~= " $word";
        }
    }

    @lines
}


class PartyViewer is Widget {
    has @.party;

    #| Draw the current party state
    method show-state($expanded = -1) {
        # XXXX: Nicer bars
        # XXXX: Condition icons (poisoned, low health, etc.)
        $.grid.set-span-text(0, 0, '  NAME    CLASS     HEALTH MAGIC');

        my $y = 1;
        for @.party.kv -> $i, $pc {
            my $row = sprintf '%d %-7s %-9s %-6s %-6s', $i + 1, $pc<name>, $pc<class>,
                              '*' x $pc<hp>, '-' x $pc<mp>;
            $.grid.set-span-text(0, $y++, $row);

            if $i == $expanded {
                 $.grid.set-span-text(0, $y++, sprintf "  %-{$.w - 2}s", "Armor:  $pc<armor>, AC $pc<ac>");
                 $.grid.set-span-text(0, $y++, sprintf "  %-{$.w - 2}s", "Weapon: $pc<weapon>");
                 if $pc<spells> {
                     my $spells = 'Spells: ' ~ $pc<spells>.join(', ');
                     my @spells = wrap-text($.w - 2, $spells, '    ');
                     $.grid.set-span-text(0, $y++, sprintf "  %-{$.w - 2}s", $_) for @spells;
                 }
                 $.grid.set-span-text(0, $y++, sprintf "  %-{$.w - 2}s", '');
            }
        }

        # Make sure extra rows are cleared after collapsing
        $.grid.set-span-text(0, $y++, ' ' x $.w) for ^(min 5, $.h - $y);

        self.composite(True);
    }
}


class LogViewer is Widget {
    has @.log;
    has @.wrapped;
    has $.scroll-pos = 0;

    method add-entry($text) {
        @.log.push($text);
        my @lines = wrap-text($.w, $text, '    ');

        # Autoscroll if already at end
        $!scroll-pos += @lines if $.scroll-pos == @.wrapped;
        @.wrapped.append(@lines);

        my $top = max 0, $.scroll-pos - $.h + 1;
        for ^$.h {
            my $line = @.wrapped[$top + $_] // '';
            $.grid.set-span-text(0, $_, $line ~ ' ' x ($.w - $line.chars));
        }

        self.composite(True);
    }
}


#| Simulate a CRPG or Roguelike interface
sub MAIN(
    Bool :$ascii, #= Use only ASCII characters, no >127 codepoints
    Bool :$bench  #= Benchmark mode (run as fast as possible, with no sleeps or rate limiting)
    ) {

    my $short-sleep =  1 * !$bench;
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
    my $log-height  = h div 6;
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
        { :name<Fennic>,  :class<Ranger>,
          :ac<6>, :hp<5>, :max-hp<5>, :mp<3>, :max-mp<3>,
          :armor('Leaf Mail +2'),
          :weapon('Longbow +1'),
          :spells('Flaming Arrow', 'Summon Animal', 'Wall of Thorns',)
        },

        { :name<Galtar>,  :class<Cleric>,
          :ac<5>, :hp<4>, :max-hp<4>, :mp<4>, :max-mp<4>,
          :armor('Solar Breastplate'),
          :weapon('Holy Mace'),
          :spells('Cure Disease', 'Flame Strike', 'Heal', 'Protection from Evil', 'Solar Blast',)
        },

        { :name<Salnax>,  :class<Sorcerer>,
          :ac<2>, :hp<3>, :max-hp<3>, :mp<6>, :max-mp<6>,
          :armor('Robe of Shadows'),
          :weapon('Staff of Ice'),
          :spells('Acid Splash', 'Geyser', 'Fireball', 'Lightning Bolt', 'Magic Missle', 'Passwall',),
        },

        { :name<Torfin>,  :class<Barbarian>,
          :ac<7>, :hp<6>, :max-hp<6>, :mp<0>, :max-mp<0>,
          :armor('Dragon Hide'),
          :weapon('Dragonbane Greatsword'),
          :spells(()),
        },

        { :name<Trentis>, :class<Rogue>,
          :ac<3>, :hp<4>, :max-hp<4>, :mp<0>, :max-mp<0>,
          :armor('Silent Leather'),
          :weapon('Throwing Dagger +1'),
          :spells(()),
        };

    my $pv = PartyViewer.new(:x($h-break + 1), :y(1), :w($party-width), :h($v-break - 2), :@party);
    $pv.show-state;

    # Log/input
    my $lv = LogViewer.new(:x(1), :y($v-break + 1), :w(w - 2), :h($log-height));
    $lv.add-entry('Game state loaded.');

    # XXXX: Accordion character details down, back up, and then collapse
    $pv.show-state($_) && sleep $short-sleep for  ^@party;
    $pv.show-state($_) && sleep $short-sleep for (^@party).reverse;
    $pv.show-state;

    # XXXX: Popup help
    # XXXX: Pan game map
    # XXXX: Battle!
    # XXXX: Battle results splash

    # Final sleep
    sleep $long-sleep;

    # Return to our regularly scheduled not-gaming
    T.shutdown-screen;
}
