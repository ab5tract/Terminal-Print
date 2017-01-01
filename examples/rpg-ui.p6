# ABSTRACT: Simulates a user playing a text-based computer game, exercising
#           many parts of the Terminal::Print API.  The simulated game is a
#           mashup of a Roguelike and a high fantasy CRPG.

use v6;
use Terminal::Print;
use Terminal::Print::Widget;
use Terminal::Print::Animated;
use Terminal::Print::BoxDrawing;
use Terminal::Print::Util::Text;
use Terminal::Print::Util::Timing;



#
# GAME WORLD AND PARTY
#

#| Create the initial map terrain state
sub make-terrain($map-w, $map-h) {
    my $t0 = now;

    # Start with a map of the right shape but empty of actual terrain
    my @map = [ '' xx $map-w ] xx $map-h;

    #| Add floor and walls for a rectangular room
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
    map-room(0, 10, 7, 12);

    # Corridors
    @map[4][$_] = '.' for 16..20;
    @map[$_][5] = '.' for  6..10;

    # Doors
    @map[4][15] = '/';
    @map[12][6] = '|';
    @map[19][6] = '|';
    @map[5][26] = '-';

    record-time("Create $map-w x $map-h map terrain", $t0);

    @map
}


#| Create the initial map seen ("fog of war") state
sub make-seen($map-w, $map-h) {
    my $t0 = now;

    # Map is initially entirely hidden and must be exposed by walking around
    my @seen = [ 0 xx $map-w ] xx $map-h;

    record-time("Create $map-w x $map-h map seen state", $t0);

    @seen
}


#| Create the initial character party
sub make-party-members() {
    my $t0 = now;

    # Use a plain old hash for each character; no need for a bespoke class yet
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
          :spells('Acid Splash', 'Geyser', 'Fireball', 'Lightning Bolt', 'Magic Missile', 'Passwall',),
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


#| A rectangular map with terrain and seen ("fog of war") layers
class Map {
    has $.w is required;
    has $.h is required;

    has $.terrain = make-terrain($!w, $!h);
    has $.seen    = make-seen($!w, $!h);
}


#| Coordinate deltas for cardinal and diagonal directions
my %direction =
    nw => (-1, -1), n => (0, -1), ne => (1, -1),
     w => (-1,  0),                e => (1,  0),
    sw => (-1,  1), s => (0,  1), se => (1,  1);

#| The player's party, including members and location
class Party {
    has @.members is required;
    has $.map-x   is required;
    has $.map-y   is required;  # i

    #| Move the party's location by (Δx, Δy)
    multi method move(Int $dx, Int $dy) {
        $!map-x += $dx;
        $!map-y += $dy;  # ++
    }

    #| Move the party's location one step in a cardinal or diagonal direction
    multi method move(Str $dir where %direction) {
        self.move(|%direction{$dir});
    }
}


#| The overall game state (map and party info) independent of the UI
class Game {
    has Map   $.map;
    has Party $.party;
}



#
# UI WIDGETS
#


#| Local extension to T::P::Widget
class Widget is Terminal::Print::Widget {
    #| Record compositing times
    method composite(|c) {
        my $t0 = now;
        callsame;
        record-time("Composite $.w x $.h {self.^name}", $t0);
    }
}

#| An animated Widget (with local extensions)
class Animation is Widget does Terminal::Print::Animated[:auto-clear] { }


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

    #| Initialize the progress bar beyond simply setting attributes
    submethod TWEAK() {
        # Render initial text
        my @lines = $!text.lines;
        my $top = (self.h - @lines) div 2;
        for @lines.kv -> $i, $line {
            self.grid.set-span-text((self.w - $line.chars) div 2,
                                    $top + $i, $line);
        }

        # Update progress bar display whenever supply is updated
        $!progress-supply.act: -> (:$key, :$value) {
            self!update-progress: $!progress * ($key eq 'add') + $value
        }
    }

    #| Add an increment to the current progress level
    method add-progress($increment) {
        $!progress-supplier.emit('add' => $increment);
    }

    #| Set the current progress level to an absolute value
    method set-progress($value) {
        $!progress-supplier.emit('set' => $value);
    }

    #| Make sure current progress level is sane and update the screen
    method !update-progress($p) {
        my $t0 = now;

        # Compute length of completed portion of bar
        $!progress    = max(0, min($!max, $p));
        my $completed = floor $.w * $!progress / $!max;

        # Loop over bar thickness (height) setting color spans
        $.grid.set-span-color(0, $completed - 1,   $_, "$!text-color on_$!completed") for ^$.h;
        $.grid.set-span-color($completed, $.w - 1, $_, "$!text-color on_$!remaining") for ^$.h;

        record-time("Draw $.w x $.h {self.^name}", $t0);

        # Update screen
        self.composite(:print);
    }
}


#| Animate between keyframes
class KeyframeAnimation is Widget {
    has @.keyframes;
    has $.on-keyframe = Supplier.new;

    #| Blend from one keyframe to the next by replacing cells randomly over time
    method speckle($delay = .01) {
        my $p = Promise.new;
        my $v = $p.vow;

        # Start by simply copying first frame and printing that
        $.grid.copy-from(@!keyframes[0], 0, 0);
        self.composite(:print);

        # Determine random speckling order once, reused for all transitions
        # in this particular animation
        my @indices = $.grid.indices.pick(*);

        # Keep a constant pace through the entire animation, changing one cell
        # at a time until converted to the next keyframe and then continuing
        # with the next one.  As each transition completes, emit the 0-based
        # number of the keyframe just completed into $.on-keyframe.
        #
        # NOTE 1: Due to choosing .tap instead of .act, if this code is running
        # slowly most of it will end up scheduling on alternating threads (only
        # the internals of the composite call will single-thread).
        #
        # NOTE 2: While for a decent-length animation it's unlikely to occur,
        # there is a race between assignment of $tap and $tap.close.  This can
        # be fixed by using:
        #
        #     react { whenever Supply.interval($delay) -> $frame { ... done; }
        #
        # but unfortunately this forces .act semantics, losing the win from
        # multithreading described in NOTE 1.
        my $tap = Supply.interval($delay).tap: -> $frame {
            my $keyframe = 1 + $frame div +@indices;
            $!on-keyframe.emit($keyframe - 1) if $frame %% @indices;

            if $keyframe < @.keyframes {
                my ($x, $y) = @indices[$frame % @indices][0,1];

                $.grid.grid[$y][$x] = @!keyframes[$keyframe].grid[$y][$x];
                self.composite(:print);
            }
            else {
                $!on-keyframe.done;
                $tap.close;
                $v.keep(True);
            }
        }

        # Return a promise that is kept when the animation fully completes
        $p;
    }
}


#| Map terrain types from pure ASCII to full Unicode
my %tiles =
    ascii => {
         '' => '',  '.' => '.', '#' => '#',      # Layout: empty, floor, wall
        '-' => '-', '|' => '|', '/' => '/',      # Doors: closed, closed, open
        '@' => '@',                              # Where party is 'at'
        '+' => '+',                              # Uncharted map area
    },
    ascii-full => {
         '' => '',   '.' => '．', '#' => '##',   # Layout: empty, floor, wall
        '-' => '－', '|' => '｜', '/' => '／',   # Doors: closed, closed, open
        '@' => '＠',                             # Where party is 'at'
        '+' => '＋',                             # Uncharted map area
    },
    tiles => {
         '' => '',  '.' => '⋅', '#' => '█',      # Layout: empty, floor, wall
        '-' => '─', '|' => '│', '/' => '╱',      # Doors: closed, closed, open
        '@' => '@',                              # Where party is 'at'
        '+' => '+',                              # Uncharted map area
    },
    tiles-full => {
         '' => '',   '.' => '・', '#' => '██',   # Layout: empty, floor, wall
        '-' => '──', '|' => '│ ', '/' => '╱ ',   # Doors: closed, closed, open
        '@' => '＠',                             # Where party is 'at'
        '+' => '＋',                             # Uncharted map area
    };


#| A map viewer widget, providing a panning viewport into the game map
class MapViewer is Animation {
    has $.map-x is required;
    has $.map-y is required;  # i
    has $.map   is required;
    has $.party is required;

    #| Draw the current map viewport, respecting seen state, party glow, etc.
    method draw-frame(|) {
        my $t0 = now;

        # Make sure party (plus a comfortable radius around them) is still visible
        my $radius     = 4;
        my $full-width = True;
        my $map-width  = $full-width ?? $.w div 2 !! $.w;

        my $party-x = $.party.map-x;
        my $party-y = $.party.map-y;
        $!map-x = max(min($.map-x, $party-x - $radius), $party-x + $radius + 1 - $map-width);
        $!map-y = max(min($.map-y, $party-y - $radius), $party-y + $radius + 1 - $.h);  # ,

        # Update party's seen area
        # XXXX: This naively marks as seen places that aren't actually in line of sight
        my $radius2 = $radius * $radius;
        for (-$radius) .. $radius -> $dy {
            my $y = $party-y + $dy;  # ++
            next unless 0 <= $y < $!map.h;

            my $seen-row = $!map.seen[$y];

            for (-$radius) .. $radius -> $dx {
                my $x = $party-x + $dx;
                next unless 0 <= $x < $!map.w;

                my $dist2 = $dy * $dy + $dx * $dx;
                $seen-row[$x] = 1 if $dist2 < $radius2;
            }
        }

        # Main map, panned to correct location
        my $ascii      = $.parent.ascii;
        my $color-bits = $.parent.color-bits;
        my $tile-mode  = ($ascii      ?? 'ascii' !! 'tiles')
                       ~ ($full-width ?? '-full' !! ''     );
        my $tiles      = %tiles{$tile-mode};

        my $marker = $color-bits > 4 ?? %( :char($tiles<+>), :color('242'))
                                     !!          $tiles<+>;

        my $t1 = now;
        my $g = $.grid;

        # Fast path the common case
        if $full-width && $color-bits > 4 {
            for ^$.h -> $y {
                my $my       = $!map-y + $y;  # ++
                my $row      = $!map.terrain[$my] || [];
                my $seen-row = $!map.seen[$my]    || [];

                if $my %% 10 {
                    for ^$map-width -> $x {
                        my $mapped = $tiles{ $seen-row[$!map-x + $x] && $row[$!map-x + $x] // '' };
                           $mapped = %( :char($mapped), :color('246') ) if $mapped;

                        $g.change-cell($x * 2, $y, $mapped || (($!map-x + $x) %% 10 ?? $marker !! '  '));
                        $g.change-cell($x * 2 + 1, $y, '');
                    }
                }
                else {
                    for ^$map-width -> $x {
                        my $mapped = $tiles{ $seen-row[$!map-x + $x] && $row[$!map-x + $x] or next };

                        $g.change-cell($x * 2,     $y, %( :char($mapped), :color('246') ));
                        $g.change-cell($x * 2 + 1, $y, '');
                    }
                }
            }
        }
        else {
            for ^$.h -> $y {
                my $row = $!map.terrain[$!map-y + $y] // [];  # ++
                my $seen-row = $!map.seen[$!map-y + $y] // [];  # ++
                my $marker-row = ($!map-y + $y) %% 10;  # ++

                if $marker-row {
                    for ^$map-width -> $x {
                        my $mapped = $tiles{ $seen-row[$!map-x + $x] && $row[$!map-x + $x] // '' };

                        if $full-width {
                            $g.change-cell($x * 2, $y, $mapped || (($!map-x + $x) %% 10 ?? $marker !! '  '));
                            $g.change-cell($x * 2 + 1, $y, '');
                        }
                        elsif $mapped {
                            $mapped = %( :char($mapped), :color('246') ) if $color-bits > 4;
                            $g.change-cell($x, $y, $mapped);
                        }
                        elsif ($!map-x + $x) %% 10 {
                            $g.change-cell($x, $y, $marker);
                        }
                    }
                }
                elsif $full-width {
                    for ^$map-width -> $x {
                        my $mapped = $tiles{ $seen-row[$!map-x + $x] && $row[$!map-x + $x] or next };

                        $g.change-cell($x * 2,     $y, $mapped);
                        $g.change-cell($x * 2 + 1, $y, '');
                    }
                }
                else {
                    for ^$map-width -> $x {
                        my $mapped = $tiles{ $seen-row[$!map-x + $x] && $row[$!map-x + $x] or next };
                           $mapped = %( :char($mapped), :color('246') ) if $color-bits > 4;

                        $g.change-cell($x, $y, $mapped);
                    }
                }
            }
        }

        # Party location
        my $t2 = now;
        my $px = $party-x - $.map-x;
        my $py = $party-y - $.map-y;  # ;;
        if 0 <= $px < $map-width && 0 <= $py < $.h {
            if $full-width {
                $g.change-cell($px * 2,     $py, $tiles<@>);
                $g.change-cell($px * 2 + 1, $py, '');
            }
            else {
                $g.change-cell($px, $py, $tiles<@>);
            }
        }

        # Party's light source glow
        # XXXX: This naively lights up areas the glow couldn't actually reach
        my $t3      = now;
        my $r_num   = $radius.Num;
        my $wide    = 1 + $full-width;
        for (-$radius) .. $radius -> $dy {
            my $y = $py + $dy;

            for (-$radius) .. $radius -> $dx {
                my $x = $px + $dx;

                my $dist2 = $dy * $dy + $dx * $dx;
                next if $dist2 >= $radius2;

                # Oddness of following lines brought to you by micro-optimization
                # Calculates a linear dropoff, which looks better than realism
                my $brightness = (13e0 * (1e0 - $dist2.sqrt / $r_num)).ceiling;
                # Ramp from black to bright yellow to white:  16 + 36 * r + 6 * g + b
                my $color = 16 + 42 * (1 + (min 8, $brightness) div 2) + max(0, $brightness - 8);

                # $g.change-cell($x, $y, $brightness.base(16));  # DEBUG: show brightness levels
                $g.set-span-color($x * $wide, $x * $wide, $y,
                                  $color-bits >  4 ?? ~$color       !!
                                  $brightness > 11 ?? 'bold white'  !!
                                  $brightness >  7 ?? 'bold yellow' !!
                                                      'yellow'      );
            }
        }

        my $t4 = now;
        record-time("Draw $.w x $.h {self.^name} -- setup", $t0, $t1);
        record-time("Draw $.w x $.h {self.^name} -- fill",  $t1, $t2);
        record-time("Draw $.w x $.h {self.^name} -- party", $t2, $t3);
        record-time("Draw $.w x $.h {self.^name} -- glow",  $t3, $t4);
        record-time("Draw $.w x $.h {self.^name}", $t0, $t4);

        callsame;
    }
}


#| Render an individual character's current stats
class CharacterViewer is Animation {
    has $.character;
    has $.rows;
    has $.id;
    has $.state = '';
    has $.injury-level = 0;

    #| Set current viewer state
    method set-state($!state) { }

    #| Render the character's stats sheet, health/magic bars, etc.
    method draw-frame(|) {
        my $t0 = now;

        my $color-bits = $.parent.parent.color-bits;
        my $injury = $!injury-level <= 0 ?? ''        !!
                     $color-bits > 4     ?? ' on_' ~ 16 + 36 * (5 * $!injury-level).ceiling !!
                     $!injury-level > .2 ?? ' on_red' !!
                                            ''        ;

        my $color = { highlight => 'bold white', lowlight => 'blue' }{$!state} // '';
           $color = ($color ~ $injury).trim;
        my $body-row = "  %-{$.w - 2}s";

        # Render character stats into rows of the proper width
        # XXXX: Condition icons (poisoned, low health, etc.)
        my $ascii   = $.parent.parent.ascii;
        my $hp-left = $ascii ?? '*' !! '▆';
        my $mp-left = $ascii ?? '=' !! '▆';
        my $max-hp  = $ascii ?? '+' !! '▃';
        my $max-mp  = $ascii ?? '-' !! '▃';
        my $hp-bar  = sprintf('%-6s', $max-hp x $.character<max-hp>);
        my $mp-bar  = sprintf('%-6s', $max-mp x $.character<max-mp>);
        $hp-bar = $hp-left x $.character<hp> ~ substr($hp-bar, $.character<hp>);
        $mp-bar = $mp-left x $.character<mp> ~ substr($mp-bar, $.character<mp>);

        my @rows = sprintf('%d %-7s %-9s %s %s', $.id,
                           $.character<name>, $.character<class>,
                           $hp-bar, $mp-bar),
                   sprintf($body-row, "Armor:  $.character<armor>, AC $.character<ac>"),
                   sprintf($body-row, "Weapon: $.character<weapon>");

        if $.character<spells> -> @spells {
            my $spells = 'Spells: ' ~ @spells.join(', ');
            @rows.append: wrap-text($.w - 2, $spells, '    ')».fmt($body-row);
        }

        # Draw filled rows into the top of the widget in the proper color
        for @rows.kv -> $y, $row {
            $.grid.set-span(0, $y, $row, $color);
        }

        # Add some color to the bar graphs
        if $!state ne 'lowlight' {
            $.grid.set-span-color(20, 25, 0, "red$injury");
            $.grid.set-span-color(27, 32, 0, "blue$injury");
        }

        # Clear all remaining rows
        $!rows = +@rows;
        my $blank = ' ' x $.w;
        # my $blank = sprintf $body-row, $.character<name>.uc x 4;  # Compositing debug
        $.grid.set-span(0, $_, $blank, '') for $!rows ..^ $.h;

        record-time("Draw $.w x $.h {self.^name}", $t0);
    }

    #| Show that the character has just been injured, returning a promise to be kept when the effect fades away
    method injured() {
        $!injury-level = 1.0;

        start {
            react {
                whenever Supply.interval(.1) -> $value {
                    self.do-frame(Terminal::Print::FrameInfo.new);
                    $.parent.request-repaint;

                    $!injury-level -= .2;
                    done if $!injury-level < 0;
                }
            }
        }
    }
}


#| Compose a number of CharacterViewers into an overall party widget
class PartyViewer is Widget {
    has $.party;
    has @.cvs;
    has $!expanded;

    has $!repaint-supplier = Supplier.new;
    has $!repaint-supply = $!repaint-supplier.Supply;

    #| Create a CharacterViewer for each character and prepare repaint trigger
    submethod TWEAK() {
        my $t0 = now;

        @!cvs = do for $!party.members.kv -> $i, $pc {
            CharacterViewer.new(:id($i + 1), :w(self.w), :h(7), :x(0), :y(0),
                                :parent(self), :character($pc));
        }

        record-time("Create { $!party.members.elems } CVs", $t0);

        # XXXX: Do an initial show-state to avoid a possible race?
        $!repaint-supply.act: -> $print { self.repaint(:$print) }
    }

    #| Draw the current party state
    method show-state(:$print = True, :$expand = -1) {
        my $t0 = now;

        # Ask each CharacterViewer to render itself in the appropriate state
        $!expanded = $expand;
        for @!cvs.kv -> $i, $cv {
            $cv.set-state: $expand <  0  ?? 'normal'    !!
                           $expand == $i ?? 'highlight' !!
                                            'lowlight'  ;
            $cv.do-frame(Terminal::Print::FrameInfo.new);
        }

        record-time("Render { $!party.members.elems } CVs", $t0);

        self.request-repaint(:$print);
    }

    #| Repaint self (without redrawing CVs, which would recurse if a CV is animating)
    method repaint(:$print = True) {
        my $t0 = now;

        # Render as a header line followed by composited CharacterViewers
        $.grid.set-span-text(0, 0, '  NAME    CLASS     HEALTH MAGIC ');
        my $y = 1;
        for @!cvs.kv -> $i, $cv {
            $cv.move-to($cv.x, $y);
            $y += $i == $!expanded ?? $cv.rows + 1 !! 1;

            $cv.composite;
        }

        # Make sure extra rows are cleared after collapsing
        $.grid.set-span(0, $y++, ' ' x $.w, '') for ^(min 6, $.h - $y + 1);

        record-time("Repaint $.w x $.h {self.^name}", $t0);

        self.composite(:$print);
    }

    method request-repaint(:$print = True) {
        $!repaint-supplier.emit($print);
    }
}


#| Keep/display a log of events and inputs, scrolling as needed
class LogViewer is Animation {
    has @.log;
    has @.wrapped;
    has $.scroll-pos = 0;
    has $.last-entry-lines = 0;

    #| Draw the currently visible section of the log
    method draw-frame(|) {
        my $t0 = now;

        # Print most recent $.h wrapped lines, highlighting most recent entry
        my $top = max 0, $.scroll-pos - $.h;
        for ^$.h {
            my $line  = @.wrapped[$top + $_] // '';
            my $color = @.wrapped - $top - $_ <= $.last-entry-lines
                        ?? 'bold white' !! '';
            $.grid.set-span(0, $_, $line ~ ' ' x ($.w - $line.chars), $color);
        }

        record-time("Draw $.w x $.h {self.^name}", $t0);
    }

    #| Add a single text entry to the log and optionally print it
    method add-entry($text, :$print = True) {
        my $t0 = now;

        # Update log and wrap lines
        @.log.push($text);
        my @lines = wrap-text($.w, $text, '    ');
        $!last-entry-lines = +@lines;

        # Autoscroll if already at end
        $!scroll-pos += $.last-entry-lines if $.scroll-pos == @.wrapped;
        @.wrapped.append(@lines);

        record-time("Update $.w x $.h {self.^name}", $t0);

        # Render and optionally print and sleep afterwards
        self.do-frame(Terminal::Print::FrameInfo.new);
        self.composite(:$print);
        sleep .5 * @lines if $print && !$*BENCHMARK-MODE;
    }

    #| Simulate a user entering commands at a prompt
    method user-input($prompt, $input, :$print = True) {
        my $text = $prompt;
        self.add-entry($text, :$print);

        for $input.words -> $word {
            @.log.pop;
            @.wrapped.pop;
            self.add-entry($text ~= " $word", :$print);
        }
    }
}


#| Create title animation
sub make-title-animation(ProgressBar :$bar, Bool :$ascii) {
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

    #| Make an array of lines filled with $char, the same dimensions as $orig
    sub make-matching-blank($orig, $char = ' ') {
        my $w = $orig.lines[0].chars;
        my $h = $orig.lines.elems;

        ($char x $w ~ "\n") x $h;
    }

    #| Turn several multiline text blocks into an array of T::P::Grid objects
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

    # Matching keyframes make it appear as if the animation paused, even though
    # in reality it is continuously running from the first frame to the last
    my $grids = $ascii ?? make-text-grids($standard, $standard, $standard, make-matching-blank($standard))
                       !! make-text-grids($solid, $pagga, $pagga, $pagga, make-matching-blank($pagga));

    # Center the title animation in the upper 3/4 of the screen
    my $title-w = $grids[0].columns;
    my $title-h = $grids[0].rows;
    my $title-x = floor (w       - $title-w) / 2;
    my $title-y = floor (h * 3/4 - $title-h) / 2;  # ==
    my $anim    = KeyframeAnimation.new(:keyframes(|$grids),
                                        :x($title-x), :y($title-y),  # ,
                                        :w($title-w), :h($title-h));

    $anim.on-keyframe.Supply.tap: { $bar.add-progress(60 / ($grids - 1)) if $^frame }
    $bar.add-progress(5);

    # Make total animation time relatively constant, despite different number
    # of keyframes and different size for ASCII and full Unicode versions
    # Note: interval supplies need an interval >= 1 ms
    my $seconds-per-frame = 6 / ($grids * $title-w * $title-h);
    my $promise = $anim.speckle($*BENCHMARK-MODE ?? .001 !! $seconds-per-frame);
    record-time("Setup animation for $title-w x $title-h title screen", $t0);

    $promise;
}


#| The main user interface composed of map, party, and log panels
class UI is Widget
 does Terminal::Print::BoxDrawing {
    has Int         $.color-bits;
    has Bool        $.edge-border = False;
    has Bool        $.ascii;
    has Game        $.game;
    has ProgressBar $.bar;
    has PartyViewer $.pv;
    has MapViewer   $.mv;
    has LogViewer   $.lv;

    #| Lay out main UI subwidgets and dividing lines, updating the progress bar
    method build-layout() {
        # Basic 3-viewport layout (map, party stats, log/input)
        my $party-width = 33;
        my $log-height  = $.h div 6;
        my $h-break     = $.w - $party-width - 1 - $.edge-border;
        my $v-break     = $.h - $log-height  - 1 - $.edge-border;

        # Let Terminal::Print know this will be a new screen
        my $t-ui = now;
        T.add-grid('main', :new-grid($.grid));
        record-time("Add new {$.w} x {$.h} grid 'main'", $t-ui);
        $.bar.add-progress(5);

        # Draw viewport borders
        my $t0 = now;
        my $style = $.ascii ?? 'ascii' !! 'double';
        self.draw-box(0, 0, $.w - 1, $.h - 1, :$style) if $.edge-border;
        self.draw-hline(+$.edge-border, $.w - 1 - $.edge-border, $v-break, :$style);
        self.draw-vline($h-break, +$.edge-border, $v-break - 1, :$style);

        # Draw intersections if in full Unicode mode
        unless $.ascii {
            $.grid.set-span-text(0, $v-break,        '╠') if $.edge-border;
            $.grid.set-span-text($.w - 1, $v-break,  '╣') if $.edge-border;
            $.grid.set-span-text($h-break, 0,        '╦') if $.edge-border;
            $.grid.set-span-text($h-break, $v-break, '╩');
        }
        record-time("Lay out $.w x $.h main UI sections", $t0);
        $.bar.add-progress(5);

        # Add map, party, and log viewers, compositing them to the new UI grid
        # but not printing them yet (just updating the progress bar)
        $t0 = now;
        $!mv = MapViewer.new(:x(+$.edge-border), :y(+$.edge-border),
                             :w($h-break - $.edge-border),
                             :h($v-break - $.edge-border),
                             :map($.game.map), :map-x(3), :map-y(3),
                             :party($.game.party), :parent(self));
        record-time("Create {$!mv.w} x {$!mv.h} MapViewer", $t0);
        $!mv.do-frame(Terminal::Print::FrameInfo.new);
        $.bar.add-progress(5);

        $t0 = now;
        $!pv = PartyViewer.new(:x($h-break + 1), :y(+$.edge-border),
                               :w($party-width),
                               :h($v-break - 1 - $.edge-border),
                               :party($.game.party), :parent(self));
        record-time("Create {$!pv.w} x {$!pv.h} PartyViewer", $t0);
        $!pv.show-state(:!print);
        $.bar.add-progress(5);

        # Log/input
        $t0 = now;
        $!lv = LogViewer.new(:x(+$.edge-border), :y($v-break + 1),
                             :w(w - 2 * $.edge-border),
                             :h($log-height), :parent(self));
        record-time("Create {$!lv.w} x {$!lv.h} LogViewer", $t0);
        $!lv.add-entry('Game state loaded.', :!print);
        $.bar.add-progress(5);
    }
}


#
# DEMO EVENTS
#

#| Play out the turns of the climactic red dragon battle
sub dragon-battle(UI $ui, Game $game) {
    #| Do damage to a character and show it in the UI
    my sub do-damage($member) {
        $game.party.members[$member]<hp>--;
        $ui.pv.cvs[$member].injured;
    }

    #| Use up one of the character's magic points and show it in the UI
    my sub use-spell($member) {
        $game.party.members[$member]<mp>--;
        $ui.pv.show-state(:expand($member));
    }

    # Dragon turn #1
    $ui.lv.add-entry("The party encounters a red dragon.");
    $ui.lv.add-entry("The dragon is enraged by Torfin's dragon hide armor and immediately attacks.");
    $ui.lv.add-entry("The dragon breathes a great blast of fire!");
    $ui.lv.add-entry("--> Fennic performs a diving roll and dodges the fire blast.");
    $ui.lv.add-entry("--> Galtar is partially shielded but still takes minor damage.");
    await do-damage(1);
    $ui.lv.add-entry("--> Salnax melts into the dancing shadows, avoiding the brunt of the blast.");
    $ui.lv.add-entry("--> Torfin's dragon hide armor shrugs off the fire.");
    $ui.lv.add-entry("--> Trentis hid behind Torfin and is untouched.");

    # Party turn #1
    $ui.pv.show-state(:expand(0));
    $ui.lv.user-input('[Fennic]>', 'fire bow');
    $ui.lv.add-entry("--> Fennic fires a glowing arrow from the longbow and pierces the dragon's hide.");

    $ui.pv.show-state(:expand(1));
    $ui.lv.user-input('[Galtar]>', 'cast solar blast');
    $ui.lv.add-entry("--> Galtar calls upon the power of the sun and bathes the dragon in searing golden light.");
    use-spell(1);
    $ui.lv.add-entry("--> The dragon is blinded!");

    $ui.pv.show-state(:expand(2));
    $ui.lv.user-input('[Salnax]>', 'trigger ice cone');
    $ui.lv.add-entry("--> Salnax calls a cone of ice from the staff.");
    $ui.lv.add-entry("--> The dragon is encased in ice!");

    $ui.pv.show-state(:expand(3));
    $ui.lv.user-input('[Torfin]>', 'swing sword');
    $ui.lv.add-entry("--> Torfin swings the fearsome sword, biting deep into the dragon's flesh.");
    $ui.lv.add-entry("--> The dragon howls in pain!");

    $ui.pv.show-state(:expand(4));
    $ui.lv.user-input('[Trentis]>', 'throw dagger');
    $ui.lv.add-entry("--> Trentis throws a dagger towards the dragon's underbelly but misses.");

    # Dragon turn #2
    $ui.pv.show-state;
    $ui.lv.add-entry("The dragon smashes through its icy shell.");
    $ui.lv.add-entry("The dragon blindly swings its mighty tail.");
    $ui.lv.add-entry("--> Galtar and Torfin are painfully knocked down!");
    await do-damage(1), do-damage(3);

    # Party turn #2
    $ui.pv.show-state(:expand(0));
    $ui.lv.user-input('[Fennic]>', 'fire bow');
    $ui.lv.add-entry("--> Fennic fires the longbow again, embedding a second arrow in the dragon's neck.");

    $ui.pv.show-state(:expand(1));
    $ui.lv.user-input('[Galtar]>', 'swing mace');
    $ui.lv.add-entry("--> Galtar swings the mace in a perfect arc, slamming it into the dragon's left foreleg with a resounding crunch.");
    $ui.lv.add-entry("--> The dragon staggers from the blow!");

    $ui.pv.show-state(:expand(2));
    $ui.lv.user-input('[Salnax]>', 'cast lightning bolt');
    $ui.lv.add-entry("--> Salnax ionizes the air with a white-hot bolt of electricity.");
    use-spell(2);
    $ui.lv.add-entry("--> The dragon shudders as electric arcs course through it.");

    $ui.pv.show-state(:expand(3));
    $ui.lv.user-input('[Torfin]>', 'rise');
    $ui.lv.add-entry("--> Torfin staggers upright, ready to fight again.");

    $ui.pv.show-state(:expand(4));
    $ui.lv.user-input('[Trentis]>', 'throw dagger');
    $ui.lv.add-entry("--> Trentis throws a dagger and impales the dragon's throat.");

    # Dragon turn #3
    $ui.pv.show-state;
    $ui.lv.add-entry("The dragon blindly casts explosive fireball.");
    $ui.lv.add-entry("--> The fiery blast knocks everyone back, singeing cloth and heating metal.");
    await (^5).map: *.&do-damage;

    # Party turn #3
    $ui.pv.show-state(:expand(0));
    $ui.lv.user-input('[Fennic]>', 'fire bow');
    $ui.lv.add-entry("--> Fennic fires a third arrow into the dragon.");

    $ui.pv.show-state(:expand(1));
    $ui.lv.user-input('[Galtar]>', 'swing mace');
    $ui.lv.add-entry("--> Galtar swings the mace and lands a solid blow to the dragon's right foreleg.");
    $ui.lv.add-entry("--> The dragon remains staggered.");

    $ui.pv.show-state(:expand(2));
    $ui.lv.user-input('[Salnax]>', 'cast magic missile');
    $ui.lv.add-entry("--> Salnax launches a quintet of octarine missiles, scattering them across the dragon's massive frame.");
    use-spell(2);
    $ui.lv.add-entry("--> The dragon howls with growing rage!");

    $ui.pv.show-state(:expand(3));
    $ui.lv.user-input('[Torfin]>', 'sword charge');
    $ui.lv.add-entry("--> Torfin charges the dragon at full speed, focusing battle rage into a massive swing.");
    $ui.lv.add-entry("--> The dragon is critically wounded!");

    $ui.pv.show-state(:expand(4));
    $ui.lv.user-input('[Trentis]>', 'mount dragon');
    $ui.lv.add-entry("--> Trentis leaps acrobatically onto the dragon's back, scrambling for purchase on the thick scales.");

    # Dragon turn #4
    $ui.pv.show-state;
    $ui.lv.add-entry("The dragon's vision clears.");
    $ui.lv.add-entry("Beaten and bleeding and realizing all party members are still fighting, the dragon decides to flee.  Shimmering symbols appear in the air around it and reality twists as the dragon teleports to safety.");
    $ui.lv.add-entry("--> Trentis falls to the floor with a thud.");
    await do-damage(4);
}


#
# MAIN PROGRAM
#

#| Simulate a CRPG or Roguelike interface
sub MAIN(
    Bool :$ascii, #= Use only ASCII characters, no >127 codepoints
    Bool :$bench, #= Benchmark mode (run as fast as possible, with no sleeps or rate limiting)
    Int  :$color-bits = 8 #= Set color support (4 = 16-color, 8 = 256-color, 24 = 24-bit RGB)
    ) {

    PROCESS::<$BENCHMARK-MODE> = $bench;

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
    @loading-promises.push: make-title-animation(:$bar, :$ascii);

    # We'll need these later, but will initialize them in a different thread
    my ($game, $ui);

    # Build main UI in a separate thread
    @loading-promises.push: start {
        # Map
        my $map = Map.new(:w(300), :h(200));
        $bar.add-progress(5);

        # Characters
        my @members := make-party-members;
        my $party = Party.new(:@members, :map-x(3), :map-y(19));  # )
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

    # XXXX: Popup help

    # XXXX: Move party around, panning game map as necessary

    #| Move the party, update the map viewer, and don't go excessively fast
    sub move-party($dir) {
        $game.party.move($dir);
        $ui.mv.do-frame(Terminal::Print::FrameInfo.new);
        $ui.mv.composite(:print);
        sleep $short-sleep;
    }

    # Simulate searching for the dragon
    move-party('n' ) for ^7;
    move-party('ne') for ^2;
    move-party('n' ) for ^4;
    move-party('nw') for ^3;
    move-party('e' ) for ^11;
    move-party('se') for ^1;
    move-party('e' ) for ^8;

    # XXXX: Battle!
    dragon-battle($ui, $game);

    # XXXX: Battle results splash
    $ui.lv.add-entry("YOU ARE VICTORIOUS!");

    # Final sleep
    sleep $long-sleep;

    # Return to our regularly scheduled not-gaming
    $t0 = now;
    T.shutdown-screen;
    record-time("Shut down {w} x {h} screen", $t0);

    # Show timing results
    record-time('TOTAL TIME', $*INITTIME);
    show-timings() if $bench;
}
