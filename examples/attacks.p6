# ABSTRACT: Render a number of different attack animations


use Terminal::Print;
use Terminal::Print::Widget;


#| Ratio of character cell height to width
constant HEIGHT_RATIO = 2;


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



### ANIMATION CLASSES

class FrameInfo {
    has $.id;
    has $.time;
}


class Animation is Terminal::Print::Widget {
    has Bool      $.auto-clear;
    has Bool      $.concurrent;

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


class Arrow is Animation {
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
        my $x    = $!start-x + $dist * $!dir-x * HEIGHT_RATIO;
        my $y    = $!start-y + $dist * $!dir-y;  # ++
        self.move-to($x.floor, $y.floor);
    }
}


class ArrowBurst is Animation {
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


sub MAIN() {
    T.initialize-screen;
    my $root = Animation.new-from-grid(T.current-grid);  # , :auto-clear); # , :concurrent);
    ArrowBurst.new(:x(0), :y(0), :w(12 * HEIGHT_RATIO), :h(12), :parent($root), :auto-clear);

    my $start = now;
    while 5 > (now - $start) {
        my $frame = FrameInfo.new(:id($++), :time(now));
        $root.do-frame($frame);
        $root.composite;
    }

    T.shutdown-screen;
}
