use v6;

use Terminal::Print;


#| Timing measurements
my @timings;

#| Keep track of timing measurements
sub record-time($desc, $start, $end = now) {
    @timings.push: %( :$start, :$end, :delta($end - $start), :$desc );
}

#| Show all timings so far
sub show-timings($verbosity) {
    return unless $verbosity >= 1;

    # Gather summary info
    my %count;
    my %total;
    for @timings {
        %count{.<desc>}++;
        %total{.<desc>} += .<delta>;
    }

    # Details of every timing
    if $verbosity >= 2 {
        my $raw-format = "%7.3f %6.3f  %s\n";
        say '  START SECONDS DESCRIPTION';
        printf $raw-format, .<start> - $*INITTIME, .<delta>, .<desc> for @timings;
        say '';
    }

    # Summary of timings by description, sorted by total time taken
    my $summary-format = "%6d %7.3f %7.3f  %s\n";
    say " COUNT   TOTAL AVERAGE  DESCRIPTION";
    for %total.sort(-*.value) -> (:$key, :$value) {
        printf $summary-format, %count{$key}, $value, $value / %count{$key}, $key;
    }
}


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
        my $t0   = now;
        my $from = $!grid.grid;
        my $cg   = T.current-grid;
        my $to   = $cg.grid;
        my $x2   = $!x + $!w - 1;
        my $out  = '';

        for ^$!h -> $y {
            my $from-row = $from[$y];
            my $to-row   = $to[$y + $!y];

            $to-row[$_ + $!x] = $from-row[$_] for ^$!w;

            $out ~= $cg.span-string($!x, $x2, $y + $!y) if $print;  # ))
        }

        print $out if $print;

        record-time("Composite $.w x $.h {self.^name}", $t0);
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
    has $!initialized;

    #| Set the current progress level and update the screen
    method set-progress($p) {
        my $t0 = now;

        # Overlay text on first initialization
        unless $!initialized {
            my @lines = $!text.lines;
            my $top = ($.h - @lines) div 2;
            for @lines.kv -> $i, $line {
                $.grid.set-span-text(($.w - $line.chars) div 2, $top + $i, $line);
            }
            $!initialized = True;
        }

        # Compute length of completed portion of bar
        $!progress    = max(0, min($!max, $p));
        my $completed = $.w * $!progress div $!max;

        # Loop over bar thickness (height) setting color spans
        $.grid.set-span-color(0, $completed - 1,   $_, "$!text-color on_$!completed") for ^$.h;
        $.grid.set-span-color($completed, $.w - 1, $_, "$!text-color on_$!remaining") for ^$.h;

        record-time("Draw $.w x $.h {self.^name}", $t0);

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


my %tiles = '' => '',  '.' => '⋅', '#' => '█',   # Layout: empty, floor, wall
           '-' => '─', '|' => '│', '/' => '╱',   # Doors: closed, closed, open
           '@' => '@';                           # Where party is 'at'

class MapViewer is Widget {
    has $.map-x is required;
    has $.map-y is required;  # i
    has $.map-w is required;
    has $.map-h is required;
    has @.map   is required;

    has $.party-x is required is rw;
    has $.party-y is required is rw;

    has $.ascii;
    has $.color-bits;

    method draw() {
        my $t0 = now;

        # Make sure party (plus a comfortable radius around them) is still visible
        my $radius = 3;
        $!map-x = max(min($.map-x, $.party-x - $radius), $.party-x + $radius + 1 - $.w);
        $!map-y = max(min($.map-y, $.party-y - $radius), $.party-y + $radius + 1 - $.h);  # ==

        # Main map, panned to correct location
        my $marker = $.color-bits > 4 ?? %( :char('+'), :color('242')) !! '+';

        my $t1 = now;
        $.grid.grid = [ [ ' ' xx $.w ] xx $.h ];
        for ^$.h -> $y {
            my $row = @!map[$!map-y + $y];  # ++
            my $marker-row = ($!map-y + $y) %% 10;  # ++

            for ^$.w -> $x {
                my $mapped = $row[$!map-x + $x] // '';
                   $mapped = %tiles{$mapped} unless $.ascii;
                my $marked = $marker-row && !$mapped && ($!map-x + $x) %% 10;
                $.grid.change-cell($x, $y, $mapped) if $mapped;
                $.grid.change-cell($x, $y, $marker) if $marked;
            }
        }

        # Party location
        my $t2 = now;
        my $px = $.party-x - $.map-x;
        my $py = $.party-y - $.map-y;  # ;;
        if 0 <= $px < $.w && 0 <= $py < $.h {
            $.grid.change-cell($px, $py, '@');
        }

        # Party's light source glow
        # XXXX: This naively lights up areas the glow couldn't actually reach
        my $t3      = now;
        my $r_num   = $radius.Num;
        my $radius2 = $radius * $radius;
        for (-$radius) .. $radius -> $dy {
            my $y = $py + $dy;

            for (-$radius) .. $radius -> $dx {
                my $x = $px + $dx;

                my $dist2 = $dy * $dy + $dx * $dx;
                next if $dist2 >= $radius2;

                # Calculates a sqrt dropoff, which looks better than realism
                # Oddness of following lines brought to you by micro-optimization
                my $brightness = 5e0 * (1e0 - $dist2.sqrt / $r_num).sqrt;
                   $brightness = $brightness > 2e0 ?? $brightness.ceiling !! 2;
                my $color      = 16 + 42 * $brightness;  # 16 + 36 * r + 6 * g + b
                # $.grid.change-cell($x, $y, ~$brightness);  # DEBUG: show brightness levels
                $.grid.set-span-color($x, $x, $y, $.color-bits > 4 ?? ~$color       !!
                                                  $brightness  > 3 ?? 'bold yellow' !! 'yellow');
            }
        }

        my $t4 = now;
        record-time("Draw $.w x $.h {self.^name} -- setup", $t0, $t1);
        record-time("Draw $.w x $.h {self.^name} -- fill",  $t1, $t2);
        record-time("Draw $.w x $.h {self.^name} -- party", $t2, $t3);
        record-time("Draw $.w x $.h {self.^name} -- glow",  $t3, $t4);
        record-time("Draw $.w x $.h {self.^name}", $t0, $t4);

        # Update screen
        self.composite(True);
    }
}


class PartyViewer is Widget {
    has @.party;

    #| Draw the current party state
    method show-state($expanded = -1) {
        my $t0 = now;

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

        record-time("Draw $.w x $.h {self.^name}", $t0);

        self.composite(True);
    }
}


class LogViewer is Widget {
    has @.log;
    has @.wrapped;
    has $.scroll-pos = 0;

    method add-entry($text) {
        my $t0 = now;

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

        record-time("Draw $.w x $.h {self.^name}", $t0);

        self.composite(True);
    }
}


#| Create the initial map state
sub make-map($map-w, $map-h) {
    my $t0 = now;

    my @map = [ '' xx $map-w ] xx $map-h;

    my sub map-room($x1, $y1, $w, $h) {
        # Top and bottom walls
        for ^$w -> $x {
            @map[$y1][$x1 + $x] = '#';
            @map[$y1 + $h - 1][$x1 + $x] = '#';
        }

        # Left and right walls
        for 0 ^..^ ($h - 1) -> $y {
            @map[$y1 + $y][$x1] = '#';
            @map[$y1 + $y][$x1 + $w - 1] = '#';
        }

        # Floor
        for 0 ^..^ ($h - 1) -> $y {
            for 0 ^..^ ($w - 1) -> $x {
                @map[$y1 + $y][$x1 + $x] = '.';
            }
        }
    }

    # Rooms
    map-room(0, 0, 16, 7);
    map-room(20, 2, 8, 4);
    map-room(0, 10, 8, 12);

    # Corridors
    @map[4][$_] = '.' for 16..20;
    @map[$_][6] = '.' for  6..10;

    # Doors
    @map[4][15] = '/';
    @map[12][7] = '|';
    @map[19][7] = '|';
    @map[5][26] = '-';

    record-time("Create $map-w x $map-h map array", $t0);

    @map
}


#| Create the initial character party
sub make-party() {
    my $t0 = now;

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

    record-time("Create {+@party}-member party", $t0);

    @party;
}


#| Simulate a CRPG or Roguelike interface
sub MAIN(
    Bool :$ascii, #= Use only ASCII characters, no >127 codepoints
    Bool :$bench, #= Benchmark mode (run as fast as possible, with no sleeps or rate limiting)
    Int  :$color-bits = 4 #= Enable extended colors (8 = 256-color, 24 = 24-bit RGB)
    ) {

    my $short-sleep =  1 * !$bench;
    my $long-sleep  = 10 * !$bench;

    # Start up the fun!
    my $t0 = now;
    T.initialize-screen;
    record-time("Initialize {w} x {h} screen", $t0);

    # XXXX: Title screen
    # XXXX: Draw rubble below/to sides of title?
    $t0 = now;
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
    record-time("Draw {w} x {h} title screen", $t0);

    # XXXX: Loading bar
    my $bar = ProgressBar.new(:x((w - 50) div 2), :y(h * 2/3), :w(50), :h(3),
                              :text('L O A D I N G'));
    $bar.set-progress($_) for 0..100;

    # XXXX: Transition animation?

    # XXXX: Basic UI
    # XXXX: What about clearing grid?
    $t0 = now;
    T.clear-screen;
    record-time("Clear {w} x {h} screen", $t0);

    # Basic 3-viewport layout (map, party stats, log/input)
    $t0 = now;
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
    record-time("Lay out {w} x {h} game screen", $t0);

    # Map
    my $map-w = 300;
    my $map-h = 200;
    my $map  := make-map($map-w, $map-h);
    my $mv    = MapViewer.new(:x(1), :y(1), :w($h-break - 1), :h($v-break - 1),
                              :party-x(6), :party-y(8), :$ascii, :$color-bits,
                              :map-x(3), :map-y(3), :$map-w, :$map-h, :$map);
    $mv.draw;

    # Characters
    my $party := make-party;
    my $pv = PartyViewer.new(:x($h-break + 1), :y(1), :w($party-width), :h($v-break - 2), :$party);
    $pv.show-state;

    # Log/input
    my $lv = LogViewer.new(:x(1), :y($v-break + 1), :w(w - 2), :h($log-height));
    $lv.add-entry('Game state loaded.');

    # XXXX: Accordion character details down, back up, and then collapse
    $pv.show-state($_) && sleep $short-sleep for  ^$party;
    $pv.show-state($_) && sleep $short-sleep for (^$party).reverse;
    $pv.show-state;

    # XXXX: Popup help

    # XXXX: Move party around, panning game map as necessary
    sub move-party($dx, $dy) {
        $mv.party-x += $dx;
        $mv.party-y += $dy;  # ++
        $mv.draw;
    }

    move-party( 0, -1) for ^2;
    move-party(-1, -1) for ^5;
    move-party( 1,  0) for ^5;
    move-party( 1,  1) for ^3;
    move-party( 1,  0) for ^12;

    # XXXX: Battle!
    # XXXX: Battle results splash

    # Final sleep
    sleep $long-sleep;

    # Return to our regularly scheduled not-gaming
    $t0 = now;
    T.shutdown-screen;
    record-time("Shut down {w} x {h} screen", $t0);

    # Show timing results
    record-time('TOTAL TIME', $*INITTIME);
    show-timings(1) if $bench;
}
