# ABSTRACT: Simulates a user playing a text-based computer game, exercising
#           many parts of the Terminal::Print API.  The simulated game is a
#           mashup of a Roguelike and a high fantasy CRPG.

use v6;
use Terminal::Print <T>;
use Terminal::Print::Widget;
use Terminal::Print::Animated;
use Terminal::Print::BoxDrawing;
use Terminal::Print::ParticleEffect;
use Terminal::Print::Util::Text;
use Terminal::Print::Util::Timing;



#
# GAME WORLD AND PARTY
#

#| Create the initial map terrain state
sub make-terrain($map-w, $map-h) {
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
    map-room( 0, 0, 16, 7);
    map-room(20, 1, 15, 7);
    map-room( 0, 10, 7, 12);

    # Corridors
    @map[4][$_] = '.' for 16..20;
    @map[$_][5] = '.' for  6..10;

    # Doors
    @map[4][15] = '/';
    @map[12][6] = '|';
    @map[19][6] = '|';
    @map[5][26] = '-';

    @map
}


#| Create the initial map seen ("fog of war") state
sub make-seen($map-w, $map-h) {
    # Map is initially entirely hidden and must be exposed by walking around
    my @seen = [ 0 xx $map-w ] xx $map-h;
}


#| Create the initial character party
sub make-party-members() {
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
class Animation  is Widget does Terminal::Print::Animated[:auto-clear] { }
class Overdrawer is Widget does Terminal::Print::Animated[] { }


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
                # self.composite(:print);
                print &($.grid.move-cursor)($x + $.x, $y + $.y) ~ $.grid.grid[$y][$x];  # ))
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

    has $.full-width = True;

    #| Make sure a rectangle of map area is fully visible (not cut off by screen edges)
    method ensure-visible(:$x!, :$y!, :$w!, :$h!) {
        my $map-width = $.full-width ?? $.w div 2 !! $.w;

        $!map-x = max(min($!map-x, $x), $x + $w - $map-width);
        $!map-y = max(min($!map-y, $y), $y + $h - $.h);  # ==
    }

    #| Draw the current map viewport, respecting seen state, party glow, etc.
    method draw-frame(|) {
        my $t0 = now;

        # Make sure party (plus a comfortable radius around them) is still visible
        my $radius     = 4;
        my $full-width = $.full-width;
        my $map-width  = $full-width ?? $.w div 2 !! $.w;

        my $party-x = $.party.map-x;
        my $party-y = $.party.map-y;  # ==
        self.ensure-visible(:x($party-x - $radius), :y($party-y - $radius),  # ,
                            :w(2 * $radius + 1), :h(2 * $radius + 1));

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
class CharacterViewer is Overdrawer {
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
            $.grid.set-span(0, $y, $row, $y ?? $color !! ($color ~ $injury).trim);
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
                    $.parent.request-repaint;

                    $!injury-level -= .2;
                    done if $!injury-level < 0;
                }
            }
        }
    }
}


#| Compose a number of CharacterViewers into an overall party widget
class PartyViewer is Overdrawer {
    has $.party;
    has $!expanded = -1;

    has $!repaint-supplier = Supplier.new;
    has $!repaint-supply = $!repaint-supplier.Supply;

    #| Create a CharacterViewer for each character and prepare repaint trigger
    submethod TWEAK() {
        for $!party.members.kv -> $i, $pc {
            CharacterViewer.new(:id($i + 1), :w(self.w), :h(7), :x(0), :y(0),
                                :parent(self), :character($pc));
        }

        # XXXX: Do an initial show-state to avoid a possible race?
        $!repaint-supply.stable(.05).act: -> $print { self.repaint(:$print) }
    }

    #| Tell the CharacterViewers to draw themselves in the correct states
    method draw-children(|) {
        # Set CV states
        for @.children.kv -> $i, $cv {
            $cv.set-state: $!expanded <  0  ?? 'normal'    !!
                           $!expanded == $i ?? 'highlight' !!
                                               'lowlight'  ;
        }

        # Actually draw the CVs
        callsame;
    }

    #| Composite updated CVs
    method draw-frame(|) {
        # Render as a header line followed by composited CharacterViewers
        $.grid.set-span-text(0, 0, '  NAME    CLASS     HEALTH MAGIC ');
        my $y = 1;
        for @.children.kv -> $i, $cv {
            $cv.move-to($cv.x, $y);
            $y += $i == $!expanded ?? $cv.rows + 1 !! 1;

            $cv.composite;
        }

        # Make sure extra rows are cleared after collapsing
        $.grid.set-span(0, $y++, ' ' x $.w, '') for ^(min 6, $.h - $y + 1);
    }

    #| Repaint self, optionally printing result
    method repaint(:$print = True) {
        self.do-frame: Terminal::Print::FrameInfo.new;
        self.composite(:$print);
    }

    #| Request a repaint "soon"
    method request-repaint(:$print = True) {
        $!repaint-supplier.emit($print);
    }

    #| Draw the current party state
    method show-state(:$print = True, :$expand = -1) {
        $!expanded = $expand;
        self.request-repaint(:$print);
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


#| Convert a text block (a single multiline string) into a T::P::Grid
sub make-text-grid($text) {
    my @lines = $text.lines;
    my $w     = @lines».chars.max;
    my $h     = @lines.elems;
    my $grid  = Terminal::Print::Grid.new($w, $h);

    $grid.set-span-text(0, $_, @lines[$_]) for ^$h;

    $grid
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
        my @grids = @texts.map(&make-text-grid);
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
    has Bool        $.narrow = False;
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
        T.add-grid('main', :new-grid($.grid));
        $.bar.add-progress(5);

        # Draw viewport borders
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
        $.bar.add-progress(5);

        # Add map, party, and log viewers, compositing them to the new UI grid
        # but not printing them yet (just updating the progress bar)
        $!mv = MapViewer.new(:x(+$.edge-border), :y(+$.edge-border),
                             :w($h-break - $.edge-border),
                             :h($v-break - $.edge-border),
                             :map($.game.map), :map-x(3), :map-y(3),
                             :full-width(!$.narrow),
                             :party($.game.party), :parent(self));
        $!mv.do-frame(Terminal::Print::FrameInfo.new);
        $.bar.add-progress(5);

        $!pv = PartyViewer.new(:x($h-break + 1), :y(+$.edge-border),
                               :w($party-width),
                               :h($v-break - 1 - $.edge-border),
                               :party($.game.party), :parent(self));
        $!pv.show-state(:!print);
        $.bar.add-progress(5);

        # Log/input
        $!lv = LogViewer.new(:x(+$.edge-border), :y($v-break + 1),
                             :w(w - 2 * $.edge-border),
                             :h($log-height), :parent(self));
        $!lv.add-entry('Game state loaded.', :!print);
        $.bar.add-progress(5);
    }
}


#
# ATTACK ANIMATIONS
#


#| Convert an rgb triplet (each in the 0..1 range) to a valid cell color
sub rgb-color(Real $r, Real $g, Real $b) {
    # Just use the 6x6x6 color cube, ignoring the hi-res gray ramp
    my $c = 16 + 36 * (5e0 * $r + .5e0).floor
               +  6 * (5e0 * $g + .5e0).floor
               +      (5e0 * $b + .5e0).floor;

    # Cell colors must be stringified
    ~$c
}


#| Convert a grayscale value (in the 0..1 range) to a valid cell color
sub gray-color(Real $gray) {
    # Use the hi-res gray ramp plus true black and white
    my $c = $gray <= .012e0 ?? 'black' !!
            $gray >= .953e0 ?? 'white' !!
                               232 + (24e0 * $gray).floor;

    # Cell colors must be stringified
    ~$c
}

#| Uniform random numbers centered on $c (or 0) and up to $n distant
multi sub myrand($n)     {      ($n * 2e0).rand - $n }
multi sub myrand($c, $n) { $c + ($n * 2e0).rand - $n }


role TempCompositing {
    has $.temp = Terminal::Print::Grid.new(self.grid.w, self.grid.h);

    my sub grid-string($grid, :$framed) {
        ('╔' ~ '═' x $grid.w ~ "╗\n║" if $framed)
        ~ $grid.grid.map(*.map({$_ // '?'}).join).join( $framed ?? "║\n║" !! "\n")
        ~ ("║\n╚" ~ '═' x $grid.w ~ '╝' if $framed)
    }

    method debug-string(|) {
        self.^name ~ ":\n"
            ~ "TEMP\n" ~ grid-string($.temp, :framed).indent(4) ~ "\n"
            ~ "GRID\n" ~ grid-string($.grid, :framed).indent(4) ~ "\n"
    }

    method refresh-background(:$from = self.target-grid, |) {
        my $fg = $!temp.grid;
        my $bg = $from.grid;
        my $x1 = $.x;
        my $x2 = $.x + $.w - 1;

        $fg[$_] = [ $bg[$.y + $_][$x1 .. $x2] ] for ^$.h;  # ++
    }

    method composite(:$to = self.target-grid, :$print, |) {
        self.refresh-background(:from($to));
        my &move := &($.grid.move-cursor);
        for ^$.h -> $y {
            my $grid-row = $.grid.grid[$y];
            my $temp-row = $.temp.grid[$y];
            for ^$.w -> $x {
                $temp-row[$x] = $grid-row[$x] if $grid-row[$x] ne ' ';
            }
            print (^$.w .map: { $temp-row[$_] ?? move($_ + $.x, $y + $.y) ~ $temp-row[$_] !! '' }).join if $print;  # )
        }
    }

    method uncomposite(:$to = self.target-grid, |) {
        self.refresh-background(:from($to));
        print &($.grid.move-cursor)($.x, $_ + $.y) ~ $.temp.grid[$_].join for ^$.h;  # ))
    }
}


class SimpleParticle is Terminal::Print::Particle {
    has $.dx;
    has $.dy;
}


class DragonBreath is Terminal::Print::ParticleEffect
 does TempCompositing {
    has $.life;
    has $.gen-frac = .4e0;                 #= fraction of life that generation occurs
    has $.fly-frac = 1e0 - self.gen-frac;  #= fraction of life that last particle lives

    method generate-particles(Num $dt) {
        my $w-scale  = $.w / ($.life * $.fly-frac);
        my $h-scale  = $.h / ($.life * $.fly-frac);

        return if $.rel.time > $.life * $.gen-frac;

        for ^($dt * 100) {
            @.particles.push: SimpleParticle.new:
                age   => 0e0,
                life  => $.life,
                color => rgb-color(1e0, 1e0, 0e0),  # Saturated yellow
                x     => myrand($.w - 1e0, .3e0),
                y     => 1e0,
                dx    => myrand(-1.1e0, .1e0) * $w-scale,
                dy    => myrand(.5e0,  .25e0) * $h-scale;
        }
    }

    method update-particles(Num $dt) {
        for @.particles {
            .x += $dt * .dx;
            .y += $dt * .dy;  # ++

            my $fade = 1e0 - .age / (.life * .8e0);
            .color = rgb-color(1e0, $fade < 0e0 ?? 0e0 !! $fade, 0e0)  # Fade to red
        }
    }
}


class Missiles is Terminal::Print::ParticleEffect
 does TempCompositing {
    has $.life;
    has $.count;

    method generate-particles(Num $dt) {
        return if @.particles;

        for ^$.count {
            @.particles.push: SimpleParticle.new:
                age   => 0e0,
                life  => $.life,
                color => rgb-color(.6e0, 0e0, 1e0),  # Blueish purple
                x     => 0e0,
                y     => $.h / 2e0,
                dx    => myrand(1e0, .15e0) * $.w / $.life,
                dy    => myrand(($_ + .5e0) / $.count - .6e0, .05e0) * 1.5e0 * $.h / $.life;
        }
    }

    method update-particles(Num $dt) {
        for @.particles {
            .x += $dt * .dx;
            .y += $dt * .dy;  # ++
        }
    }
}


class Projectile is Animation
 does TempCompositing {
    has $.life;

    method composite(:$to = self.target-grid, :$print) {
        return unless $print;

        my $x = round $.w * $.rel.time / $.life;
        my $y = $.y + $.h div 2;  # ++
        my $glyph = @.frames[$x % @.frames];

        print $to.span-string($.x, $.x + $x - 1 - $x % 2, $y) if $x >= 2;
        print ' ' if $x % 2;
        print &($.grid.move-cursor)($x + $.x, $y) ~ $glyph if $x < $.w;
    }
}


class Arrow is Projectile {
    has @.frames = < → >;
}


class Dagger is Projectile {
    has @.frames = < ↑ ↗ → ↘ ↓ ↙ ← ↖ >;
}


class SolarBeam is Terminal::Print::PixelAnimation
 does TempCompositing {
    has $.life;

    method compute-pixels() {
        my $t = $.rel.time.Num;
        return () if $t >= $.life;

        my $cy    = $.h - 1;
        my $w     = $.w.Num;
        my $left  = ($w * max(0e0, 1e0 - 5e0 * ($.life - $t))).floor;
        my $right = ($w * min(1e0, 5e0 * $t)).floor;

        my @colors;
        for $left..$right -> $x {
            my $shape = sin(.1e0 + $x / $w * π / 2e0) ** .15e0;  # Beam, narrower at left end
            my $wave  = .1e0 * sin(.5e0 * $x - 15e0 * $t);       # Wavy pulses traveling left to right
            my $beam  = $shape * (1.8e0 + .1e0.rand + $wave);    # Small variations

            for -2 .. 2 -> $dy {
                my $bright = $beam - .5e0 * $dy.abs;
                next if $bright < .5e0;

                @colors[$cy + $dy][$x] = $bright > 1e0 ?? rgb-color(1e0, 1e0, $bright - 1e0)
                                                       !! rgb-color($bright, $bright, 0e0);
            }
        }

        @colors;
    }
}


class ColdCone is Terminal::Print::PixelAnimation
 does TempCompositing {
    has $.life;

    method compute-pixels() {
        my $t = $.rel.time.Num;
        return () if $t >= $.life;

        my $cy    = $.h - 1;
        my $w     = $.w.Num;
        my $left  = ($w * max(0e0, 1e0 - 5e0 * ($.life - $t))).floor;
        my $right = ($w * min(1e0, 5e0 * $t)).floor;

        my @colors;
        for $left..$right -> $x {
            my $ramp  = sin(.1e0 + $x / $w * π / 2e0) ** .15e0;  # Subtly dimmer on left
            my $cone  = $ramp * (1.9e0 + .1e0.rand);             # Small variations
            my $width = $x div 3;

            for -$width .. $width -> $dy {
                my $hyp = ($dy * $dy + $x * $x).sqrt;
                my $cos = $x / ($hyp || 1);
                my $bright = $cone * $cos ** 6e0;
                next if $bright < .5e0;

                @colors[$cy + $dy][$x - 1]
                    = $bright > 1e0
                      ?? rgb-color($bright - 1e0, $bright - 1e0, 1e0)
                      !! rgb-color(0e0, 0e0, $bright);
            }
        }

        @colors;
    }
}


class LightningBolt is Terminal::Print::PixelAnimation
 does TempCompositing {
    has $.life;

    method compute-pixels() {
        my $t = $.rel.time.Num;
        return () if $t >= $.life;

        my $cy    = $.h - 1;
        my $dy    = 2e0.rand - 1e0;
        my $left  = ($.w * max(0e0, 1e0 - 5e0 * ($.life - $t))).floor;
        my $right = ($.w * min(1e0, 5e0 * $t)).floor;

        my @colors;
        for $left..$right -> $x {
            my $top  = ($cy + $dy).floor;
            my $dist = $dy - $dy.floor;

            @colors[$top    ][$x] = gray-color(       $dist  ** .1e0) if $dist < .5e0;
            @colors[$top + 1][$x] = gray-color((1e0 - $dist) ** .1e0) if $dist > .5e0;

            $dy = $dy * .9e0 + 1.0e0.rand - .5e0;
        }

        @colors;
    }
}


class WaveFront is Terminal::Print::PixelAnimation
 does TempCompositing {
    has $.life;

    method compute-pixels() {
        my $w     = $.w;
        my $h     = $.h * 2;
        my $cx    = $w div 2;
        my $cy    = $h div 2;
        my $r     = min($cx, $cy).Num;
        my $t     = $.rel.time.Num / $.life;
        my $rt    = max(1e0, $r * $t);

        my @colors;
        for ^$h -> $y {
            my $row = @colors[$y] //= [];
            my $dy  = ($y - $cy).Num;
            my $dy2 = $dy * $dy;

            for ^$w -> $x {
                my $dx  = ($x - $cx).Num;
                my $dx2 = $dx * $dx;
                my $d   = ($dx2 + $dy2).sqrt;
                my $rd  = $d / $rt;

                if .3e0 < $rd < 1e0 {
                    my $tint = $rd * (.9e0 + .1e0.rand);
                    my $fade = max(.5e0, min(1e0, 5e0 * (1e0 - $t)));
                    $row[$x] = rgb-color($fade, $tint * $fade, 0e0);
                }
            }
        }

        @colors;
    }
}


class Teleport is Animation
 does Terminal::Print::Pixelated
 does TempCompositing {
    has $.cx = self.w div 2;
    has $.cy = self.h div 2;
    has $.r  = min((self.w + 1) div 2, $!cy).Num;

    has @.symbols = (0x263F .. 0x2653).pick(*)».chr;

    #| Figure out what phase of a multi-phase animation is active, and how far that phase has progressed
    method phase($time, @phase-times) {
        my $t = 0e0;
        for @phase-times.kv -> $i, $phase {
            return ($i, ($time - $t) / $phase) if $time < $t + $phase;
            $t += $phase;
        }
        (+@phase-times, $time - $t)
    }

    #| Compute coordinates for hexagon corners, relative to its center
    method hexagon-coords($pct) {
        my $rt    = $!r * $pct;
        my $x     = cos(π / 6);

        my $xrt   = (1e0 + $.parent.full-width) * $x * $rt;
        my $hrt   = .5e0 * $rt;

        ( $xrt, -$hrt),
        ( 0   , -$rt ),
        (-$xrt, -$hrt),
        (-$xrt,  $hrt),
        ( 0   ,  $rt ),
        ( $xrt,  $hrt);
    }

    #| Spread the symbols into the right shape for the tessaract
    method spread-symbols($pct) {
        my @coords = self.hexagon-coords($pct);

        for @coords.kv -> $i, ($x, $y) {
            $.grid.set-span($!cx + ($x / 2).round, $!cy + ($y / 2).round, @.symbols[$i],     'green');
            $.grid.set-span($!cx + $x.round,       $!cy + $y.round,       @.symbols[$i + 6], 'green');
        }

        $.grid.set-span($!cx, $!cy, @.symbols[12], 'green');
    }

    method draw-partial-line(@pixels, $color, $pct, $x1, $y1, $x2, $y2) {
        my $dx = $x2 - $x1;
        my $dy = $y2 - $y1;

        # X-major
        if $dx.abs > $dy.abs {
            my $x = $x1;
            while (my $frac = ($x - $x1) / $dx) <= $pct {
                my $y = $y1 + $dy * $frac;
                @pixels[$y.round][$x.round] = $color;

                $x += $dx.sign;
            }
        }
        # Y-major
        elsif $dx.abs < $dy.abs {
            my $y = $y1;
            while (my $frac = ($y - $y1) / $dy) <= $pct {
                my $x = $x1 + $dx * $frac;
                @pixels[$y.round][$x.round] = $color;

                $y += $dy.sign;
            }
        }
        # Single point
        else {
            @pixels[$y1.round][$x1.round] = $color if $pct > .5e0;
        }
    }

    method form-tesseract($pct) {
        my @coords = self.hexagon-coords(1e0);
        my @pixels;

        my $cy = $!cy * 2 + .5e0;
        my $p1 = min(1e0,           $pct           * 3e0);
        my $p2 = min(1e0, max(0e0, ($pct - .333e0) * 3e0));
        my $p3 =          max(0e0, ($pct - .666e0) * 3e0);

        for 0, 2, 4 -> $i {
            self.draw-partial-line(@pixels, 'magenta', $p1, $!cx, $cy,
                                   $!cx + @coords[$i][0],
                                   $cy + (@coords[$i][1] * 2e0));

            self.draw-partial-line(@pixels, 'magenta', $p2,
                                   $!cx + @coords[$i][0],
                                   $cy + (@coords[$i][1] * 2e0),
                                   $!cx + @coords[$i + 1][0],
                                   $cy + (@coords[$i + 1][1] * 2e0));

            self.draw-partial-line(@pixels, 'magenta', $p2,
                                   $!cx + @coords[$i][0],
                                   $cy + (@coords[$i][1] * 2e0),
                                   $!cx + @coords[($i - 1) % 6][0],
                                   $cy + (@coords[($i - 1) % 6][1] * 2e0));

            self.draw-partial-line(@pixels, 'magenta', $p3,
                                   $!cx + (@coords[$i][0] * .5e0),
                                   $cy +   @coords[$i][1],
                                   $!cx + (@coords[$i + 1][0] * .5e0),
                                   $cy +   @coords[$i + 1][1]);

            self.draw-partial-line(@pixels, 'magenta', $p2,
                                   $!cx + (@coords[$i][0] * .5e0),
                                   $cy +   @coords[$i][1],
                                   $!cx + (@coords[($i - 1) % 6][0] * .5e0),
                                   $cy +   @coords[($i - 1) % 6][1]);
        }

        self.composite-pixels(@pixels);

        self.spread-symbols(1e0);
    }

    method flash($pct) {
        self.form-tesseract(1e0);
        next unless ($pct * 23).round % 2;

        my $ratio = $.parent.full-width + 1e0;
        my $rtx   = ($!r * $pct * $ratio).round;
        my $rty   = ($!r * $pct / 2e0).round;

        my $color = gray-color(.75e0 + $pct / 4e0);

        for -$rty .. $rty -> $dy {
            $.grid.set-span($!cx - $rtx, $!cy + $dy, '█' x ($rtx * 2 + 1), $color);
        }

        for 1 .. $rty -> $dy {
            my $xw = ($rtx * (1 - $dy / $rty)).ceiling;
            $.grid.set-span($!cx - $xw, $!cy + $dy + $rty, '█' x ($xw * 2 + 1), $color);
            $.grid.set-span($!cx - $xw, $!cy - $dy - $rty, '█' x ($xw * 2 + 1), $color);
        }
    }

    method draw-frame() {
        my @times = .8e0, .8e0, 1e0;
        my ($phase, $pct) = self.phase($.rel.time + .5e0, @times);

        given $phase {
            when 0  { self.spread-symbols($pct) }
            when 1  { self.form-tesseract($pct) }
            when 2  { self.flash($pct) }
            default { }
        }
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
        $ui.pv.children[$member].injured;
    }

    #| Use up one of the character's magic points and show it in the UI
    my sub use-spell($member) {
        $game.party.members[$member]<mp>--;
        $ui.pv.show-state(:expand($member));
    }

    #| Convert a rect in party-relative map coords to absolute viewer coords
    my sub maprel-to-viewer(:$dx!, :$dy!, :$w!, :$h!) {
        my $fw = 1 + $ui.mv.full-width;
        my $x  = ($game.party.map-x - $ui.mv.map-x + $dx) * $fw;
        my $y  =  $game.party.map-y - $ui.mv.map-y + $dy;  # -

        ($x, $y, $w * $fw, $h)
    }

    #| Add an attack animation
    my sub show-attack($attack, $life, :$dx!, :$dy!, :$w! is copy, :$h! is copy, |c) {
        my $t0 = now;
        (my $x, my $y, $w, $h) = maprel-to-viewer(:$dx, :$dy, :$w, :$h);

        my $animation = $attack.new(:$x, :$y, :$w, :$h,
                                    :$life, :parent($ui.mv), |c);

        my $start = now;
        repeat {
            $animation.do-frame(Terminal::Print::FrameInfo.new);
            $animation.composite(:print);
        } while now - $start < $life;

        $animation.uncomposite;
        $ui.mv.remove-child($animation);
        record-time("Render $animation.w() x $animation.h() {$animation.^name}", $t0);
    }

    #| Add the dragon to the screen
    my sub add-dragon(:$dx, :$dy) {
        my $dragon-wide = q:to/DRAGON/;
                 __     
            <,  /\      
             `=<###>.   
               ]   ] `~+
            DRAGON

        my $dragon-narrow = q:to/DRAGON/;
                _   
            <, /\   
             `<##>. 
              ]  ]`+
            DRAGON

        # /
        my $dragon = $ui.mv.full-width ?? $dragon-wide !! $dragon-narrow;
        my $grid   = make-text-grid($dragon);
        $grid.set-span-color(0, $grid.w - 1, $_, 'red') for ^$grid.h;

        my $fw   = 1 + $ui.mv.full-width;
        my ($x, $y, $w, $h)
                 = maprel-to-viewer(:$dx, :$dy, :w($grid.w / $fw), :h($grid.h));

        Widget.new-from-grid($grid, :$x, :$y, :parent($ui.mv));
    }

    #| Refresh MapViewer
    my sub refresh-mv() {
        $ui.mv.do-frame(Terminal::Print::FrameInfo.new);
        $ui.mv.composite(:print);
    }

    # Add dragon and make sure the battle area is completely visible
    $ui.lv.add-entry("The party encounters a red dragon.");
    $ui.mv.ensure-visible(:x($game.party.map-x - 1), :y($game.party.map-y - 2),  # ,
                          :w(11), :h(5));
    my $dragon = add-dragon(:dx(+4), :dy(-2));
    refresh-mv();

    # Dragon turn #1
    $ui.lv.add-entry("The dragon is enraged by Torfin's dragon hide armor and immediately attacks.");
    $ui.lv.add-entry("The dragon breathes a great blast of fire!");
    show-attack(DragonBreath, 1e0, :dx(-1), :dy(-2), :w(5), :h(5));
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
    show-attack(Arrow, .5e0, :dx(+1), :dy(0), :w(5), :h(1));

    $ui.pv.show-state(:expand(1));
    $ui.lv.user-input('[Galtar]>', 'cast solar blast');
    $ui.lv.add-entry("--> Galtar calls upon the power of the sun and bathes the dragon in searing golden light.");
    show-attack(SolarBeam, 1e0, :dx(+1), :dy(-2), :w(7), :h(5));
    use-spell(1);
    $ui.lv.add-entry("--> The dragon is blinded!");

    $ui.pv.show-state(:expand(2));
    $ui.lv.user-input('[Salnax]>', 'trigger ice cone');
    $ui.lv.add-entry("--> Salnax calls a cone of ice from the staff.");
    show-attack(ColdCone, 1e0, :dx(+1), :dy(-2), :w(7), :h(5));
    $ui.lv.add-entry("--> The dragon is encased in ice!");

    $ui.pv.show-state(:expand(3));
    $ui.lv.user-input('[Torfin]>', 'swing sword');
    $ui.lv.add-entry("--> Torfin swings the fearsome sword, biting deep into the dragon's flesh.");
    $ui.lv.add-entry("--> The dragon howls in pain!");

    $ui.pv.show-state(:expand(4));
    $ui.lv.user-input('[Trentis]>', 'throw dagger');
    $ui.lv.add-entry("--> Trentis throws a dagger towards the dragon's underbelly but misses.");
    show-attack(Dagger, .75e0, :dx(+1), :dy(0), :w(5), :h(1));

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
    show-attack(Arrow, .5e0, :dx(+1), :dy(0), :w(5), :h(1));

    $ui.pv.show-state(:expand(1));
    $ui.lv.user-input('[Galtar]>', 'swing mace');
    $ui.lv.add-entry("--> Galtar swings the mace in a perfect arc, slamming it into the dragon's left foreleg with a resounding crunch.");
    $ui.lv.add-entry("--> The dragon staggers from the blow!");

    $ui.pv.show-state(:expand(2));
    $ui.lv.user-input('[Salnax]>', 'cast lightning bolt');
    $ui.lv.add-entry("--> Salnax ionizes the air with a white-hot bolt of electricity.");
    show-attack(LightningBolt, 1e0, :dx(+1), :dy(-2), :w(7), :h(5));
    use-spell(2);
    $ui.lv.add-entry("--> The dragon shudders as electric arcs course through it.");

    $ui.pv.show-state(:expand(3));
    $ui.lv.user-input('[Torfin]>', 'rise');
    $ui.lv.add-entry("--> Torfin staggers upright, ready to fight again.");

    $ui.pv.show-state(:expand(4));
    $ui.lv.user-input('[Trentis]>', 'throw dagger');
    $ui.lv.add-entry("--> Trentis throws a dagger and impales the dragon's throat.");
    show-attack(Dagger, .5e0, :dx(+1), :dy(0), :w(5), :h(1));

    # Dragon turn #3
    $ui.pv.show-state;
    $ui.lv.add-entry("The dragon blindly casts explosive fireball.");
    $ui.lv.add-entry("--> The fiery blast knocks everyone back, singeing cloth and heating metal.");
    show-attack(WaveFront, .5e0, :dx(-1), :dy(-2), :w(6), :h(5));
    await (^5).map: *.&do-damage;

    # Party turn #3
    $ui.pv.show-state(:expand(0));
    $ui.lv.user-input('[Fennic]>', 'fire bow');
    $ui.lv.add-entry("--> Fennic fires a third arrow into the dragon.");
    show-attack(Arrow, .5e0, :dx(+1), :dy(0), :w(5), :h(1));

    $ui.pv.show-state(:expand(1));
    $ui.lv.user-input('[Galtar]>', 'swing mace');
    $ui.lv.add-entry("--> Galtar swings the mace and lands a solid blow to the dragon's right foreleg.");
    $ui.lv.add-entry("--> The dragon remains staggered.");

    $ui.pv.show-state(:expand(2));
    $ui.lv.user-input('[Salnax]>', 'cast magic missile');
    $ui.lv.add-entry("--> Salnax launches a quintet of octarine missiles, scattering them across the dragon's massive frame.");
    show-attack(Missiles, 1e0, :dx(+1), :dy(-2), :w(7), :h(5), :count(5));
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
    $ui.mv.remove-child($dragon);
    refresh-mv();
    show-attack(Teleport, 2.1e0, :dx(+3), :dy(-3), :w(7), :h(7));
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
    Int  :$color-bits = 8, #= Set color support (4 = 16-color, 8 = 256-color, 24 = 24-bit RGB)
    Bool :$narrow, #= Use narrow map viewer mode
    ) {

    PROCESS::<$BENCHMARK-MODE> = $bench;

    my $short-sleep  = .1 * !$bench;
    my $medium-sleep =  1 * !$bench;
    my $long-sleep   =  5 * !$bench;

    my @loading-promises;

    # Start up the fun!
    T.initialize-screen;

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
        $ui = UI.new(:w(w), :h(h), :x(0), :y(0), :$narrow,
                     :$game, :$bar, :$ascii, :$color-bits);
        $ui.build-layout;
    }

    # Make sure all loading and title animations finish, and main screen is
    # fully ready, before showing main screen and setting it current
    await @loading-promises;
    $bar.set-progress(100);

    T.switch-grid('main');
    $ui.composite;
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
    sleep $long-sleep || .1;

    # Return to our regularly scheduled not-gaming
    T.shutdown-screen;

    # Show timing results
    record-time('TOTAL TIME', $*INIT-INSTANT // $*INITTIME);
    show-timings() if $bench;
}
