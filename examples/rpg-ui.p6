use v6;

use Terminal::Print;


#| Multi-thread timing measurements
my @timings;
my $timings-supplier = Supplier.new;
my $timings-supply = $timings-supplier.Supply;
$timings-supply.act: { @timings.push: $^timing };

#| Keep track of timing measurements
sub record-time($desc, $start, $end = now) {
    $timings-supplier.emit: %( :$start, :$end, :delta($end - $start), :$desc,
                               :thread($*THREAD.id) );
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
        my $raw-format = "%7.3f %7.3f %6d  %s\n";
        say '  START SECONDS THREAD  DESCRIPTION';
        printf $raw-format, .<start> - $*INITTIME, .<delta>, .<thread>, .<desc> for @timings;
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
    has Int $.x is required is rw;
    has Int $.y is required is rw;
    has Int $.w is required;
    has Int $.h is required;

    has $.grid = Terminal::Print::Grid.new($!w, $!h);
    has $.parent;

    #| Return T::P::Grid object that this Widget will draw on
    method target-grid() {
        given $!parent {
            when Terminal::Print::Grid  { $!parent       }
            when Widget                 { $!parent.grid  }
            default                     { T.current-grid }
        }
    }

    # Simply copies widget contents onto another grid (by default the current
    # target grid), optionally also printing updated contents to the screen
    method composite(Bool $print?, :$to = self.target-grid) {
        my $t0 = now;

        # Ask the destination grid (a monitor) to do the copy for thread safety
        $print ?? $to.print-from($!grid, $!x, $!y)
               !! $to .copy-from($!grid, $!x, $!y);  # )

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

    has $!progress-supplier = Supplier.new;
    has $!progress-supply = $!progress-supplier.Supply;
    has $!initialized;

    # My kingdom for submethod TWEAK
    method init() {
        return if $!initialized;

        # Render initial text
        my @lines = $!text.lines;
        my $top = ($.h - @lines) div 2;
        for @lines.kv -> $i, $line {
            $.grid.set-span-text(($.w - $line.chars) div 2, $top + $i, $line);
        }

        # Update progress bar display whenever supply is updated
        $!progress-supply.act: -> (:$key, :$value) {
            self!update-progress: $!progress * ($key eq 'add') + $value
        };

        $!initialized = True;
    }

    #| Add an increment to the current progress level
    method add-progress($increment) {
        self.init unless $!initialized;

        $!progress-supplier.emit('add' => $increment);
    }

    #| Set the current progress level to an absolute value
    method set-progress($value) {
        self.init unless $!initialized;

        $!progress-supplier.emit('set' => $value);
    }

    #| Set the current progress level and update the screen
    method !update-progress($p) {
        my $t0 = now;

        self.init unless $!initialized;

        # Compute length of completed portion of bar
        $!progress    = max(0, min($!max, $p));
        my $completed = floor $.w * $!progress / $!max;

        # Loop over bar thickness (height) setting color spans
        $.grid.set-span-color(0, $completed - 1,   $_, "$!text-color on_$!completed") for ^$.h;
        $.grid.set-span-color($completed, $.w - 1, $_, "$!text-color on_$!remaining") for ^$.h;

        record-time("Draw $.w x $.h {self.^name}", $t0);

        # Update screen
        self.composite(True);
    }
}


#| Animate between keyframes
class KeyframeAnimation is Widget {
    has @.keyframes;
    has $.on-keyframe = Supplier.new;

    method speckle($delay = .01) {
        my $p = Promise.new;
        my $v = $p.vow;

        $.grid.copy-from(@!keyframes[0], 0, 0);
        self.composite(True);

        my @indices = $.grid.indices.pick(*);
        my $tap = Supply.interval($delay).tap: -> $frame {
            my $keyframe = 1 + $frame div +@indices;
            $!on-keyframe.emit($keyframe - 1) if $frame %% @indices;

            if $keyframe < @.keyframes {
                my ($x, $y) = @indices[$frame % @indices][0,1];

                $.grid.grid[$y][$x] = @!keyframes[$keyframe].grid[$y][$x];
                self.composite(True);

            }
            else {
                $!on-keyframe.done;
                $tap.close;
                $v.keep(True);
            }
        }

        $p;
    }
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
sub draw-hline($grid, $y, $x1, $x2, $style = 'double') {
    $grid.set-span-text($x1, $y, %hline{$style} x ($x2 - $x1 + 1));
}

#| Draw a vertical line
sub draw-vline($grid, $x, $y1, $y2, $style = 'double') {
    $grid.set-span-text($x, $_, %vline{$style}) for $y1..$y2;
}

#| Draw a box
sub draw-box($grid, $x1, $y1, $x2, $y2, $style = Empty) {
    # Draw sides in order: left, right, top, bottom
    draw-vline($grid, $x1, $y1 + 1, $y2 - 1, |$style);
    draw-vline($grid, $x2, $y1 + 1, $y2 - 1, |$style);
    draw-hline($grid, $y1, $x1 + 1, $x2 - 1, |$style);
    draw-hline($grid, $y2, $x1 + 1, $x2 - 1, |$style);

    # Draw corners
    my @corners = |%corners{%weight{$style}};
    $grid.set-span-text($x1, $y1, @corners[0]);
    $grid.set-span-text($x2, $y1, @corners[1]);
    $grid.set-span-text($x1, $y2, @corners[2]);
    $grid.set-span-text($x2, $y2, @corners[3]);
}

sub wrap-text($w, $text, $prefix = '', $first-prefix = '') {
    my @words = $text.words;
    my @lines = $first-prefix ~ @words.shift;

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
    has $.map   is required;
    has $.party is required;

    method draw($print = True) {
        my $t0 = now;

        # Make sure party (plus a comfortable radius around them) is still visible
        my $radius  = 3;
        my $party-x = $.party.map-x;
        my $party-y = $.party.map-y;
        $!map-x = max(min($.map-x, $party-x - $radius), $party-x + $radius + 1 - $.w);
        $!map-y = max(min($.map-y, $party-y - $radius), $party-y + $radius + 1 - $.h);  # ==

        # Main map, panned to correct location
        my $ascii      = $.parent.ascii;
        my $color-bits = $.parent.color-bits;

        my $marker = $color-bits > 4 ?? %( :char('+'), :color('242')) !! '+';

        my $t1 = now;
        $.grid.clear;
        for ^$.h -> $y {
            my $row = $!map.terrain[$!map-y + $y];  # ++
            my $marker-row = ($!map-y + $y) %% 10;  # ++

            for ^$.w -> $x {
                my $mapped = $row[$!map-x + $x] // '';
                   $mapped = %tiles{$mapped} unless $ascii;
                my $marked = $marker-row && !$mapped && ($!map-x + $x) %% 10;
                $.grid.change-cell($x, $y, $mapped) if $mapped;
                $.grid.change-cell($x, $y, $marker) if $marked;
            }
        }

        # Party location
        my $t2 = now;
        my $px = $party-x - $.map-x;
        my $py = $party-y - $.map-y;  # ;;
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
                $.grid.set-span-color($x, $x, $y, $color-bits > 4 ?? ~$color       !!
                                                  $brightness > 3 ?? 'bold yellow' !! 'yellow');
            }
        }

        my $t4 = now;
        record-time("Draw $.w x $.h {self.^name} -- setup", $t0, $t1);
        record-time("Draw $.w x $.h {self.^name} -- fill",  $t1, $t2);
        record-time("Draw $.w x $.h {self.^name} -- party", $t2, $t3);
        record-time("Draw $.w x $.h {self.^name} -- glow",  $t3, $t4);
        record-time("Draw $.w x $.h {self.^name}", $t0, $t4);

        # Update screen
        self.composite($print);
    }
}


class CharacterViewer is Widget {
    has $.character;
    has $.rows;
    has $.id;

    method render($state) {
        my $t0 = now;

        my $color = { highlight => 'bold white', lowlight => 'blue' }{$state} // '';
        my $body-row = "  %-{$.w - 2}s";

        # Render character stats into rows of the proper width
        # XXXX: Nicer bars
        # XXXX: Condition icons (poisoned, low health, etc.)
        my $hp-bar = sprintf('%-6s', '+' x $.character<max-hp>);
        my $mp-bar = sprintf('%-6s', '-' x $.character<max-mp>);
        $hp-bar = '*' x $.character<hp> ~ substr($hp-bar, $.character<hp>);
        $mp-bar = '=' x $.character<mp> ~ substr($mp-bar, $.character<mp>);

        my @rows = sprintf('%d %-7s %-9s %s %s ', $.id,
                           $.character<name>, $.character<class>,
                           $hp-bar, $mp-bar),
                   sprintf($body-row, "Armor:  $.character<armor>, AC $.character<ac>"),
                   sprintf($body-row, "Weapon: $.character<weapon>");

        if $.character<spells> -> @spells {
            my $spells = 'Spells: ' ~ @spells.join(', ');
            @rows.append: wrap-text($.w, $spells, '      ', '  ');
        }

        # Draw filled rows into the top of the widget in the proper color
        for @rows.kv -> $y, $row {
            $.grid.set-span(0, $y, $row, $color);
        }

        # Clear all remaining rows
        $!rows = +@rows;
        my $blank = ' ' x $.w;
        $.grid.set-span(0, $_, $blank, $color) for $!rows ..^ $.h;

        record-time("Draw $.w x $.h {self.^name}", $t0);
    }
}


class PartyViewer is Widget {
    has $.party;
    has @.cvs;

    #| Draw the current party state
    method show-state($print = True, :$expand = -1) {
        my $t0 = now;

        my @cvs = do for $.party.members.kv -> $i, $pc {
            CharacterViewer.new(:id($i + 1), :$.w, :h(7), :x(0), :y(0),
                                :parent(self), :character($pc));
        }
        record-time("Draw $.w x $.h {self.^name} -- create CVs", $t0);

        # Render as a header line followed by composited CharacterViewers
        $.grid.set-span-text(0, 0, '  NAME    CLASS     HEALTH MAGIC');
        my $y = 1;
        for @cvs.kv -> $i, $cv {
            my $state = $expand <  0  ?? 'normal'    !!
                        $expand == $i ?? 'highlight' !!
                                         'lowlight'  ;
            $cv.render($state);

            $cv.y = $y;
            $y   += $i == $expand ?? $cv.rows + 1 !! 1;

            $cv.composite;
        }

        # Make sure extra rows are cleared after collapsing
        $.grid.set-span(0, $y++, ' ' x $.w, '') for ^(min 5, $.h - $y);

        record-time("Draw $.w x $.h {self.^name}", $t0);

        self.composite($print);
    }
}


class LogViewer is Widget {
    has @.log;
    has @.wrapped;
    has $.scroll-pos = 0;

    method add-entry($text, $print = True) {
        my $t0 = now;

        @.log.push($text);
        my @lines = wrap-text($.w, $text, '    ');

        # Autoscroll if already at end
        $!scroll-pos += @lines if $.scroll-pos == @.wrapped;
        @.wrapped.append(@lines);

        my $top = max 0, $.scroll-pos - $.h;
        for ^$.h {
            my $line  = @.wrapped[$top + $_] // '';
            my $color = @.wrapped - $top - $_ <= @lines ?? 'bold white' !! '';
            $.grid.set-span(0, $_, $line ~ ' ' x ($.w - $line.chars), $color);
        }

        record-time("Draw $.w x $.h {self.^name}", $t0);

        self.composite($print);
        sleep .5 * @lines if $print;
    }

    method user-input($prompt, $input, $print = True) {
        my $text = $prompt;
        self.add-entry($text, $print);

        for $input.words -> $word {
            @.log.pop;
            @.wrapped.pop;
            self.add-entry($text ~= " $word", $print);
        }
    }
}


#| Create title animation
sub make-title-animation(ProgressBar :$bar, Bool :$ascii, Bool :$bench) {
    my $t0 = now;

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

    my $solid = q:to/SOLID/;  # :
        ░███░███░███░███░███░░░███░███░░░███░███░███░███░███░███░███░
        ░███░███░███░███░███░░░███░███░░░███░███░███░███░███░███░███░
        ░▀▀▀░▀▀▀░▀▀▀░▀▀▀░▀▀▀░░░▀▀▀░▀▀▀░░░▀▀▀░▀▀▀░▀▀▀░▀▀▀░▀▀▀░▀▀▀░▀▀▀░
        SOLID

    sub make-matching-blank($orig, $char = ' ') {
        my $w = $orig.lines[0].chars;
        my $h = $orig.lines.elems;

        ($char x $w ~ "\n") x $h;
    }

    sub make-text-grids(*@texts) {
        my $w = @texts[0].lines[0].chars;
        my $h = @texts[0].lines.elems;

        my @grids = Terminal::Print::Grid.new($w, $h) xx @texts;
        for ^@texts {
            my $grid = @grids[$_];
            my @text = @texts[$_].lines;

            for @text.kv -> $y, $line {
                $grid.set-span-text(0, $y, $line);
            }
        }

        @grids
    }

    my $grids = $ascii ?? make-text-grids($standard, $standard, $standard, make-matching-blank($standard))
                       !! make-text-grids($solid, $pagga, $pagga, $pagga, make-matching-blank($pagga));

    my $title-w = $grids[0].columns;
    my $title-h = $grids[0].rows;
    my $title-x = floor (w       - $title-w) / 2;
    my $title-y = floor (h * 3/4 - $title-h) / 2;  # ==
    my $anim    = KeyframeAnimation.new(:keyframes(|$grids),
                                        :x($title-x), :y($title-y),  # ,
                                        :w($title-w), :h($title-h));

    $anim.on-keyframe.Supply.tap: { $bar.add-progress(60 / ($grids - 1)) if $^frame }
    $bar.add-progress(5);

    my $promise = $anim.speckle($bench ?? .001 !! 6 / ($grids * $title-w * $title-h));
    record-time("Setup animation for $title-w x $title-h title screen", $t0);

    $promise;
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
sub make-party-members() {
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

    record-time("Create {+@party} party members", $t0);

    @party;
}


class Map {
    has $.w is required;
    has $.h is required;

    has $.terrain = make-map($!w, $!h);
}


my %direction =
    nw => (-1, -1), n => (0, -1), ne => (1, -1),
     w => (-1,  0),                e => (1,  0),
    sw => (-1,  1), s => (0,  1), se => (1,  1);

class Party {
    has @.members is required;
    has $.map-x   is required is rw;
    has $.map-y   is required is rw;

    multi method move(Int $dx, Int $dy) {
        $!map-x += $dx;
        $!map-y += $dy;  # ++
    }

    multi method move(Str $dir where %direction) {
        self.move(|%direction{$dir});
    }
}


class Game {
    has Map   $.map;
    has Party $.party;
}


class UI is Widget {
    has Int         $.color-bits;
    has Bool        $.ascii;
    has Game        $.game;
    has ProgressBar $.bar;
    has PartyViewer $.pv;
    has MapViewer   $.mv;
    has LogViewer   $.lv;

    method build-layout() {
        # Basic 3-viewport layout (map, party stats, log/input)
        my $party-width = 34;
        my $log-height  = $.h div 6;
        my $h-break     = $.w - $party-width - 2;
        my $v-break     = $.h - $log-height  - 2;

        my $t-ui = now;
        T.add-grid('main', :new-grid($.grid));
        record-time("Add new {$.w} x {$.h} grid 'main'", $t-ui);
        $.bar.add-progress(5);

        my $t0 = now;
        my $style = $.ascii ?? 'ascii' !! 'double';
        draw-box($.grid, 0, 0, $.w - 1, $.h - 1, $style);
        draw-hline($.grid, $v-break, 1, $.w - 2, $style);
        draw-vline($.grid, $h-break, 1, $v-break - 1, $style);

        # Draw intersections if in full Unicode mode
        unless $.ascii {
            $.grid.set-span-text(0, $v-break, '╠');
            $.grid.set-span-text($.w, $v-break, '╣');
            $.grid.set-span-text($h-break, 0, '╦');
            $.grid.set-span-text($h-break, $v-break, '╩');
        }
        record-time("Lay out $.w x $.h main UI sections", $t0);
        $.bar.add-progress(5);

        $t0 = now;
        $!mv = MapViewer.new(:x(1), :y(1), :w($h-break - 1), :h($v-break - 1),
                             :map($.game.map), :map-x(3), :map-y(3),
                             :party($.game.party), :parent(self));
        record-time("Create {$!mv.w} x {$!mv.h} MapViewer", $t0);
        $!mv.draw(False);
        $.bar.add-progress(5);

        $t0 = now;
        $!pv = PartyViewer.new(:x($h-break + 1), :y(1), :w($party-width),
                               :h($v-break - 2), :party($.game.party),
                               :parent(self));
        record-time("Create {$!pv.w} x {$!pv.h} PartyViewer", $t0);
        $!pv.show-state(False);
        $.bar.add-progress(5);

        # Log/input
        $t0 = now;
        $!lv = LogViewer.new(:x(1), :y($v-break + 1), :w(w - 2),
                             :h($log-height), :parent(self));
        record-time("Create {$!lv.w} x {$!lv.h} LogViewer", $t0);
        $!lv.add-entry('Game state loaded.', False);
        $.bar.add-progress(5);
    }
}


#| Simulate a CRPG or Roguelike interface
sub MAIN(
    Bool :$ascii, #= Use only ASCII characters, no >127 codepoints
    Bool :$bench, #= Benchmark mode (run as fast as possible, with no sleeps or rate limiting)
    Int  :$color-bits = 4 #= Enable extended colors (8 = 256-color, 24 = 24-bit RGB)
    ) {

    my $short-sleep  = .1 * !$bench;
    my $medium-sleep =  1 * !$bench;
    my $long-sleep   = 10 * !$bench;

    my @loading-promises;

    # Start up the fun!
    my $t0 = now;
    T.initialize-screen;
    record-time("Initialize {w} x {h} screen", $t0);

    # Loading bar
    my $bar = ProgressBar.new(:x((w - 50) div 2), :y(h * 2 div 3), :w(50), :h(3),
                              :text('L O A D I N G'));
    $bar.set-progress(0);

    # Animated title
    @loading-promises.push: make-title-animation(:$bar, :$ascii, :$bench);

    # We'll need these later, but will initialize them in a different thread
    my ($game, $ui);

    # Build main UI in a separate thread
    @loading-promises.push: start {
        # Map
        my $map = Map.new(:w(300), :h(200));
        $bar.add-progress(5);

        # Characters
        my @members := make-party-members;
        my $party = Party.new(:@members, :map-x(6), :map-y(8));  # )
        $bar.add-progress(5);

        # Global Game object
        $game = Game.new(:$map, :$party);

        # Global main UI object
        $ui = UI.new(:w(w), :h(h), :x(0), :y(0),  # ,
                     :$game, :$bar, :$ascii, :$color-bits);
        $ui.build-layout;
    }

    # Make sure all loading and title animations finish, and main screen is
    # fully ready, before showing main screen and setting it current
    await @loading-promises;
    $bar.set-progress(100);

    T.switch-grid('main', :blit);
    sleep $medium-sleep;

    # XXXX: Accordion character details down, back up, and then collapse
    { $ui.pv.show-state(:expand($_)); sleep $medium-sleep } for  ^$game.party.members;
    { $ui.pv.show-state(:expand($_)); sleep $medium-sleep } for (^$game.party.members).reverse;
    $ui.pv.show-state;

    # XXXX: Popup help

    # XXXX: Move party around, panning game map as necessary
    sub move-party($dir) {
        $game.party.move($dir);
        $ui.mv.draw;
        sleep $short-sleep;
    }

    move-party('n' ) for ^2;
    move-party('nw') for ^5;
    move-party('e' ) for ^5;
    move-party('se') for ^3;
    move-party('e' ) for ^12;

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
