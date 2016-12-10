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
    # Just use the 6x6x6 color cube, ignoring the hi-res grey ramp
    my $c = 16 + 36 * (5e0 * $r + .5e0).floor
               +  6 * (5e0 * $g + .5e0).floor
               +      (5e0 * $b + .5e0).floor;

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

class ParticleEffect is ClearingAnimation {
    has @.particles;

    method generate-particles() {
        for ^1 {
            @!particles.push: {
                age   => 0,
                life  => 3,
                color => 'red',
                x     => 0,
                y     => 0,
                dx    => (^5).pick,
                dy    => (^5).pick,
            }
        }
    }

    method age-particles() {
        my $dt = $.delta.time;

        for @!particles {
            .<x>   += $dt * .<dx>;
            .<y>   += $dt * .<dy>;
            .<age> += $dt;
        }
    }

    method gc-particles() {
        @!particles .= grep: { .<age> < .<life> }
    }

    method draw-frame() {
        self.age-particles;
        self.gc-particles;
        self.generate-particles;

        for @!particles {
            $.grid.change-cell(.<x> * $*TERMINAL-HEIGHT-RATIO, .<y>,
                               %( :char('█'), :color(.<color>) ) );  # >
        }
    }
}



#| Demo various possible rpg-ui attack animations
sub MAIN(
    Real :$height-ratio = 2,  #= Ratio of character cell height to width
) {
    my $*TERMINAL-HEIGHT-RATIO = $height-ratio;

    T.initialize-screen;
    my $root = FullPaintAnimation.new-from-grid(T.current-grid, :concurrent);

    my $size = 12;
    ArrowBurst.new(:parent($root), :y(0), :h($size),
                   :x(0), :w($size * $height-ratio));
    ParticleEffect.new(:parent($root), :y(0), :h($size),
                       :x($size * $height-ratio), :w($size * $height-ratio));

    my $start = now;
    while 5 > (now - $start) {
        my $frame = FrameInfo.new(:id($++), :time(now));
        $root.do-frame($frame);
        $root.composite;
    }

    T.shutdown-screen;
}