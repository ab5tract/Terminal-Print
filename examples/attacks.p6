# ABSTRACT: Render a number of different attack animations

use v6;
use Terminal::Print <T>;
use Terminal::Print::Widget;
use Terminal::Print::Animated;
use Terminal::Print::Pixelated;
use Terminal::Print::ParticleEffect;


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


### ANIMATION CONVENIENCE CLASSES

class FullPaintAnimation is Terminal::Print::Widget
      does Terminal::Print::Animated[] {};

class ClearingAnimation is Terminal::Print::Widget
      does Terminal::Print::Animated[:auto-clear] {};

class ParticleEffect is Terminal::Print::ParticleEffect {
    #| Display the particle count each frame
    method draw-frame() {
        callsame;
        $.grid.set-span-text($.w - 5, 0, sprintf('%5d', @.particles.elems));
    }
}


### ANIMATIONS

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
    # Tuned for 2 second total effect lifetime
    submethod TWEAK() {
        my ($x, $y) = self.w div 2, self.h div 2;
        my $size    = min $x, $y;
        for 0, 15 ...^ 360 -> $degrees {
            my $radians  = $degrees / 360 * τ;
            my $target-x = $x + $size * cos($radians);
            my $target-y = $y - $size * sin($radians);  # Note inverted Y

            Arrow.new(:$x, :$y, :w(1), :h(1), :$target-x, :$target-y,
                      :parent(self), :speed($size/1.35e0));
        }
    }
}


class SimpleParticle is Terminal::Print::Particle {
    has $.dx;
    has $.dy;
}


class DragonBreath is ParticleEffect {
    has $.size = min(self.w, self.h);

    # Tuned for 4 second total effect lifetime
    method generate-particles(Num $dt) {
        return if $.rel.time > 2;

        my $v0 = .20e0 * $!size;
        my $vr = .30e0 * $!size;

        for ^($dt * $!size * $!size * 3) {
            @.particles.push: SimpleParticle.new:
                age   => 0e0,
                life  => 2e0,
                color => rgb-color(1e0, 1e0, 0e0),  # Saturated yellow
                x     => 1e0.rand,
                y     => 1e0.rand,
                dx    => $v0 + $vr.rand,
                dy    => $v0 + $vr.rand;
        }
    }

    method update-particles(Num $dt) {
        for @.particles {
            .x += $dt * .dx;
            .y += $dt * .dy;  # ++

            my $fade = 1e0 - .age / .life;
            .color = rgb-color(1e0, $fade < 0e0 ?? 0e0 !! $fade, 0e0)  # Fade to red
        }
    }
}


class SwirlBlast is ParticleEffect {
    has $.size = min(self.w / 2e0, self.h / 2e0);

    # Tuned for 3 second total effect lifetime
    method generate-particles(Num $dt) {
        my $swirl-time = 1.2e0;
        if $.rel.time == 0 {
            my $initial = 16;
            for ^$initial -> $i {
                my $radians = $i / $initial * τ;
                my $tint    = .5e0.rand;
                @.particles.push: Terminal::Print::Particle.new:
                    age   => 0e0,
                    life  => $swirl-time,
                    color => rgb-color($tint, $tint, .7e0 + .3e0.rand),
                    x     => $!size + $!size * cos($radians),
                    y     => $!size - $!size * sin($radians);
            }
        }
        elsif $swirl-time < $.rel.time < $swirl-time + 0.3e0 {
            for ^(max(1, 100 * $dt)) {
                my $radians = τ.rand;
                my $speed   = $!size * (.95e0 + .1e0.rand);
                @.particles.push: SimpleParticle.new:
                    age   => 0e0,
                    life  => 1.5e0,
                    color => gray-color(.8e0 + .2e0.rand),
                    x     => $!size,
                    y     => $!size,
                    dx    =>  $speed * cos($radians),
                    dy    => -$speed * sin($radians);
            }
        }
    }

    method update-particles(Num $dt) {
        my $count = @.particles.elems;
        for @.particles.kv -> $i, $_ {
            when SimpleParticle {
                .x += .dx * $dt;
                .y += .dy * $dt;  # ++
            }
            default {
                my $fade = 1e0 - .age / .life;
                my $radians = ($i / $count + .5e0 * .age) * τ;
                .x = $!size + $!size * $fade * cos($radians);
                .y = $!size - $!size * $fade * sin($radians);
            }
        }
    }
}


class WaveFront is Terminal::Print::PixelAnimation {
    # Tuned for 3 second total effect lifetime
    method compute-pixels() {
        my $w     = $.w;
        my $h     = $.h * 2;
        my $cx    = ($w - 1) / 2e0;
        my $cy    = ($h - 1) / 2e0;
        my $r     = min($cx, $cy);
        my $life  = 1.5e0;
        my $t     = $.rel.time.Num / $life;
        my $rt    = max(1e0, $r * $t);
        my $min   = $rt < 2.5e0 ?? 0e0 !! .71e0;

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

                if $min <= $rd <= 1e0 {
                    my $tint = $rd * $rd * (.95e0 + .05e0.rand);
                    $row[$x] = rgb-color($tint, $tint, 1e0);
                }
            }
        }

        @colors;
    }
}


class LightningBolt is Terminal::Print::PixelAnimation {
    method compute-pixels() {
        my $life = 4e0;
        my $t    = $.rel.time.Num;
        return () if $t >= $life;

        my $cy    = $.h;
        my $dy    = 2e0.rand - 1e0;
        my $left  = ($.w * max(0e0, 1e0 - 5e0 * ($life - $t))).floor;
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


class SolarBeam is Terminal::Print::PixelAnimation {
    method compute-pixels() {
        my $life = 4e0;
        my $t    = $.rel.time.Num;
        return () if $t >= $life;

        my $cy    = $.h;
        my $w     = $.w.Num;
        my $left  = ($w * max(0e0, 1e0 - 5e0 * ($life - $t))).floor;
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


class ColdCone is Terminal::Print::PixelAnimation {
    method compute-pixels() {
        my $life = 4e0;
        my $t    = $.rel.time.Num;
        return () if $t >= $life;

        my $cy    = $.h;
        my $w     = $.w.Num;
        my $left  = ($w * max(0e0, 1e0 - 5e0 * ($life - $t))).floor;
        my $right = ($w * min(1e0, 5e0 * $t)).floor;

        my @colors;
        for $left..$right -> $x {
            my $ramp  = sin(.1e0 + $x / $w * π / 2e0) ** .15e0;  # Subtly dimmer on left
            my $cone  = $ramp * (1.9e0 + .1e0.rand);             # Small variations
            my $width = $x div 2;

            for -$width .. $width -> $dy {
                my $hyp = √($dy * $dy + $x * $x);
                my $cos = $x / ($hyp || 1);
                my $bright = $cone * $cos ** 6e0;
                next if $bright < .5e0;

                @colors[$cy + $dy][$x] = $bright > 1e0 ?? rgb-color($bright - 1e0, $bright - 1e0, 1e0)
                                                       !! rgb-color(0e0, 0e0, $bright);
            }
        }

        @colors;
    }
}


class Teleport is ClearingAnimation does Terminal::Print::Pixelated {
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
        my $ratio = $*TERMINAL-HEIGHT-RATIO;
        my $rt    = $!r * $pct;
        my $x     = cos(π / 6);

        my $xrt   = $ratio * $x * $rt;
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
        return unless ($pct * 23).round % 2;

        my $ratio = $*TERMINAL-HEIGHT-RATIO;
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
        my ($phase, $pct) = self.phase($.rel.time, @times);

        given $phase {
            when 0  { self.spread-symbols($pct) }
            when 1  { self.form-tesseract($pct) }
            when 2  { self.flash($pct) }
            default { }
        }
    }
}


#| Demo various possible rpg-ui attack animations
sub MAIN(
    Real :$slow-mo = 1e0,     #= Slow time by a dilation factor
    Real :$height-ratio = 2,  #= Ratio of character cell height to width
    Bool :$show-fps,          #= Show FPS (Frames Per Second)
    Bool :$bench,             #= Benchmark mode (fixed frame count and sim rate)
) {
    my $*TERMINAL-HEIGHT-RATIO = $height-ratio;

    T.initialize-screen;

    my class Root is FullPaintAnimation {
        has $.fps is rw;

        method draw-frame() {
            callsame;

            $.grid.print-string(0, 0, sprintf("Time: %5.3f", $.rel.time));
            $.grid.print-string(15, 0, sprintf("FPS: %3d", $!fps))
                if $!fps && $show-fps;
        }
    }

    my $root = Root.new-from-grid(T.current-grid);
    my @rows = (ArrowBurst, SwirlBlast, WaveFront, DragonBreath),
               (LightningBolt, SolarBeam, ColdCone, Teleport);
    my $cols = max @rows>>.elems;
    my $h1 = (T.rows    / @rows).floor - 1;
    my $h2 = (T.columns / $cols / $height-ratio).floor;
    my $h  = min $h1, $h2;
       $h -= $h %% 2;
    my $w  = $h * $height-ratio;

    for @rows.kv -> $row, @animations {
        for @animations.kv -> $i, $anim {
            $anim.new(:parent($root), :x($i * $w), :y($row * ($h + 1) + 1), :$w, :$h);
        }
    }

    my $frames = 0;
    my $anim-start = now;
    repeat {
        my $period-start = now;
        for ^10 {
            my $time  = ($bench ?? .1 * $frames !! now) / $slow-mo;
            my $frame = Terminal::Print::FrameInfo.new(:id(++$frames), :$time);
            $root.do-frame($frame);
        }
        $root.fps = (10 / (now - $period-start)).floor;
    } while $root.rel.time < 4e0;
    my $anim-end = now;

    T.shutdown-screen;

    printf "%.3f FPS\n", $frames / ($anim-end - $anim-start) if $show-fps;
}
