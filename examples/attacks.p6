# ABSTRACT: Render a number of different attack animations


use Terminal::Print;
use Terminal::Print::Widget;


### CONVENIENCE ROUTINES

#| Math readability: use the actual square root operator
sub prefix:<√>(Numeric $n) { $n.sqrt }

#| Normalize a 2-vector; (0, 0) will be left unchanged
sub normalize(Real $x, Real $y) {
    my $length = √($x² + $y²);
    $length ?? ($x / $length, $y / $length) !! (0, 0);
}

#| Compute the compass segment 0 ..^ $segments for a given vector direction ($x, $y), counting counterclockwise from 0 = easterly (pointing mostly along +X axis) with inverted Y
sub compass-segment(Real $x, Real $y, Int :$segments = 4) {
    (atan2(-$y, $x) / τ * $segments).round % $segments
}

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


### ANIMATION CLASSES

class FrameInfo {
    has $.id;
    has $.time;
}


role Animated[Bool :$auto-clear, Bool :$concurrent] {
    has Bool      $.auto-clear = $auto-clear;
    has Bool      $.concurrent = $concurrent;

    has FrameInfo $.start;
    has FrameInfo $.last;
    has FrameInfo $.cur;
    has FrameInfo $.rel;
    has FrameInfo $.delta;

    method prep-frame(FrameInfo $!cur) {
        # Bootstrap history
        $!start ||= $!cur;
        $!last  ||= $!cur;

        # Add info for clocks relative to widget start and previous frame
        # XXXX: Is this a lot of per-widget overhead?
        $!rel     = FrameInfo.new(:id(  $!cur.id   - $!start.id  ),
                                  :time($!cur.time - $!start.time));
        $!delta   = FrameInfo.new(:id(  $!cur.id   - $!last.id   ),
                                  :time($!cur.time - $!last.time ));
    }

    method draw-children() {
        if $!concurrent {
            @.children.map: { start .?do-frame($!cur) }
        }
        else {
            .?do-frame($!cur) for @.children;

            my $p = Promise.new;
            $p.keep;
            $p
        }
    }

    method clear-frame() {
        $.grid.clear;
    }

    method draw-frame() {
        # Default behavior is simply to compose the children in
        .composite for @.children;
    }

    method finish-frame() {
        $!last = $!cur;
    }

    method do-frame(FrameInfo $frame) {
        self.prep-frame($frame);

        # Maximize concurrency if requested
        my @p = self.draw-children;
        self.clear-frame if $.auto-clear;
        await @p;

        self.draw-frame;
        self.finish-frame;
    }
}


class FullPaintAnimation is Terminal::Print::Widget does Animated[] {};
class ClearingAnimation  is Terminal::Print::Widget does Animated[:auto-clear] {};


class Arrow is FullPaintAnimation {
    has $.speed    is required;  #= cells / second
    has $.target-x is required;
    has $.target-y is required;
    has $!start-x;
    has $!start-y;
    has $!dir-x;
    has $!dir-y;

    submethod TWEAK() {
        $!start-x = self.x;
        $!start-y = self.y;

        ($!dir-x, $!dir-y) = normalize($!target-x - $!start-x,
                                       $!target-y - $!start-y);  # )

        my @arrows  = < → ↗ ↑ ↖ ← ↙ ↓ ↘ >;
        my $segment = compass-segment($!dir-x, $!dir-y, :8segments);
        self.grid.change-cell(0, 0, @arrows[$segment]);
    }

    method draw-frame() {
        # Just move the arrow sprite across the background
        my $dist = $!speed * $.rel.time;
        my $x    = $!start-x + $dist * $!dir-x * $*TERMINAL-HEIGHT-RATIO;
        my $y    = $!start-y + $dist * $!dir-y;  # ++
        self.move-to($x.floor, $y.floor);
    }
}


class ArrowBurst is ClearingAnimation {
    submethod TWEAK() {
        my ($x, $y) = self.w div 2, self.h div 2;
        my $size    = min $x, $y;
        for 0, 15 ...^ 360 -> $degrees {
            my $radians  = $degrees / 360 * τ;
            my $target-x = $x + $size * cos($radians);
            my $target-y = $y - $size * sin($radians);  # Note inverted Y

            Arrow.new(:$x, :$y, :w(1), :h(1), :$target-x, :$target-y,
                      :parent(self), :speed(5));
            # ==
        }
    }
}


#| Widget maintains a (color only) pixel field with double Y resolution
role Pixelated {
    my %cell-cache;

    #| Composite pixels into grid cells by using unicode half-height blocks
    # XXXX: What about transparency (even just of the screen door type)?
    method composite-pixels(@pixels) {
        my $grid = $.grid.grid;
        for ^$.h -> $y {
            my $row1 = @pixels[$y * 2]     // [];
            my $row2 = @pixels[$y * 2 + 1] // [];
            for ^$.w -> $x {
                my $c1 = $row1[$x] // '';
                my $c2 = $row2[$x] // '';

                $grid[$y][$x] = %cell-cache{$c1}{$c2} //= do {
                    my $cell = $c1 && $c2 ?? %( :char('▄'), :color("$c2 on_$c1") ) !!
                               $c1        ?? %( :char('▀'), :color($c1)          ) !!
                               $c2        ?? %( :char('▄'), :color($c2)          ) !! ' ';
                    $.grid.change-cell($x, $y, $cell);
                    $grid[$y][$x];
                }
            }
        }
    }
}


class ParticleEffect is FullPaintAnimation does Pixelated {
    has @.particles;

    #| OVERRIDE: push new particles onto @.particles based on $dt (seconds since last frame)
    method generate-particles(Num $dt) { }

    #| OVERRIDE: update all @.particles based on their new .<age> and $dt (seconds since last frame)
    method update-particles(Num $dt) { }

    #| Make existing particles older by $dt seconds
    method age-particles(Num $dt) {
        .<age> += $dt for @!particles;
    }

    #| Remove any particles that have outlasted their .<life>
    method gc-particles() {
        @!particles .= grep: { .<age> < .<life> }
    }

    #| Composite particles into pixels, and then onto the grid
    method composite-particles() {
        my @colors;
        my $ratio = $*TERMINAL-HEIGHT-RATIO.Num;
        for @!particles {
            next if .<x> < 0e0 || .<y> < 0e0;
            @colors[.<y> * 2e0][.<x> * $ratio] = .<color>;
        }

        self.composite-pixels(@colors);
    }

    #| Render a single frame of this particle effect and update its @.particles
    method draw-frame() {
        my $dt = $.delta.time.Num;

        self.age-particles($dt);
        self.gc-particles;
        self.update-particles($dt);
        self.generate-particles($dt);
        self.composite-particles;

        $.grid.set-span-text($.w - 4, 0, sprintf('%4d', @!particles.elems));
    }
}


class DragonBreath is ParticleEffect {
    method generate-particles(Num $dt) {
        return if $.rel.time > 2;

        for ^($dt * 100) {
            @.particles.push: {
                age   => 0e0,
                life  => 3e0,
                color => rgb-color(1e0, 1e0, 0e0),  # Saturated yellow
                x     => 1e0.rand,
                y     => 1e0.rand,
                dx    => 2e0 + 3e0.rand,
                dy    => 2e0 + 3e0.rand,
            }
        }
    }

    method update-particles(Num $dt) {
        for @.particles {
            .<x> += $dt * .<dx>;
            .<y> += $dt * .<dy>;

            my $fade = 1e0 - .<age> / .<life>;
            .<color> = rgb-color(1e0, $fade < 0e0 ?? 0e0 !! $fade, 0e0)  # Fade to red
        }
    }
}


class SwirlBlast is ParticleEffect {
    has $.size = min(self.w div 2, self.h div 2);

    method generate-particles(Num $dt) {
        my $swirl-time = 1.2e0;
        if $.rel.time == 0 {
            my $initial = 16;
            for ^$initial -> $i {
                my $radians = $i / $initial * τ;
                my $tint    = .5e0.rand;
                @.particles.push: {
                    age   => 0e0,
                    life  => $swirl-time,
                    color => rgb-color($tint, $tint, .7e0 + .3e0.rand),
                    x     => $!size + $!size * cos($radians),
                    y     => $!size - $!size * sin($radians),
                }
            }
        }
        elsif $swirl-time < $.rel.time < $swirl-time + 0.3e0 {
            for ^10 {
                my $radians = τ.rand;
                my $speed   = .5e0 + .5e0.rand;
                @.particles.push: {
                    age   => 0e0,
                    life  => 3e0,
                    color => gray-color(.8e0 + .3e0.rand),
                    x     => $!size,
                    y     => $!size,
                    dx    =>  $speed * cos($radians),
                    dy    => -$speed * sin($radians),
                }
            }
        }
    }

    method update-particles(Num $dt) {
        my $count = @.particles.elems;
        for @.particles.kv -> $i, $_ {
            if .<dx>:exists {
                .<x> += .<dx>;
                .<y> += .<dy>;  # >
            }
            else {
                my $fade = 1e0 - .<age> / .<life>;
                .<x> = $!size + $!size * $fade * cos(($i / $count + .<age>) * τ);
                .<y> = $!size - $!size * $fade * sin(($i / $count + .<age>) * τ);  # >
            }
        }
    }
}


class WaveFront is FullPaintAnimation does Pixelated {
    method compute-pixels() {
        my $w     = $.w;
        my $h     = $.h * 2;
        my $cx    = $w div 2;
        my $cy    = $h div 2;
        my $r     = min($cx, $cy).Num;
        my $life  = 1.5e0;
        my $t     = $.rel.time.Num / $life;
        my $rt    = max(1e0, $r * $t);

        my @colors;
        for ^$h -> $y {
            my $row = @colors[$y] //= [];
            my $dy  = ($y - $cy).Num;
            my $dy2 = $dy * $dy;

            for ^$w -> $x {
                my $dx  = ($x - $cx).Num;
                my $dx2 = $dx * $dx;
                my $d   = √($dx2 + $dy2);
                my $rd  = $d / $rt;

                if .7e0 < $rd < 1e0 {
                    my $tint = $rd * $rd * (.9e0 + .1e0.rand);
                    $row[$x] = rgb-color($tint, $tint, 1e0);
                }
            }
        }

        @colors;
    }

    method draw-frame() {
        self.composite-pixels(self.compute-pixels);

        $.grid.set-span($.w - 5, 0, sprintf('%.3f', $.rel.time), '');
    }
}


#| Demo various possible rpg-ui attack animations
sub MAIN(
    Real :$height-ratio = 2,  #= Ratio of character cell height to width
    Bool :$show-fps,          #= Show FPS (Frames Per Second)
) {
    my $*TERMINAL-HEIGHT-RATIO = $height-ratio;

    T.initialize-screen;
    my $root = FullPaintAnimation.new-from-grid(T.current-grid);  # , :concurrent);

    my $h = 10;
    my $w = $h * $height-ratio;
    for (ArrowBurst, SwirlBlast, DragonBreath, WaveFront).kv -> $i, $anim {
        $anim.new(:parent($root), :x($i * $w), :y(1), :$w, :$h);
    }

    my $fps;
    for ^10 {
        my $frames = 0;
        my $start  = now;
        while (now - $start) < .5 {
            my $frame = FrameInfo.new(:id(++$frames), :time(now));
            $root.do-frame($frame);
            $root.grid.print-string(0, 0, sprintf("FPS: %4d", $fps))
                if $fps && $show-fps;
            $root.composite;
        }
        $fps = floor $frames / (now - $start);
    }

    sleep 3;
    T.shutdown-screen;
}
