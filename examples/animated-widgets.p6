# ABSTRACT: Display several simultaneously animating subwidgets, stress-testing concurrency

use Terminal::Print;
use Terminal::Print::Widget;


#| A simple spinning line
class Spinner is Terminal::Print::Widget {
    has $.size;
    has $.top-margin;
    has $.left-margin;
    has $.angle = 0;
    has @!angle = < ─ ╱ │ ╲ >;

    submethod TWEAK() {
        $!size        = min(self.w, self.h);
        $!size       -= $!size %% 2;
        $!top-margin  = (self.h - $!size) div 2;
        $!left-margin = (self.w - $!size) div 2;
        # say "{ (self.x, self.y, self.w, self.h).join: ', ' } --> $!size: ($!left-margin, $!top-margin)";
    }

    method rotate() {
        $.grid.clear;

        my ($x, $y, $dx, $dy) = 0, 0, 0, 0;

        given $.angle {
            when 0 { ($x, $y, $dx, $dy) = $!left-margin, $!top-margin + $!size div 2, 1,  0 }
            when 1 { ($x, $y, $dx, $dy) = $!left-margin, $!top-margin + $!size - 1,   1, -1 }
            when 2 { ($x, $y, $dx, $dy) = $!left-margin + $!size div 2, $!top-margin, 0,  1 }
            when 3 { ($x, $y, $dx, $dy) = $!left-margin, $!top-margin,                1,  1 }
        }

        for ^$!size {
            $.grid.change-cell($x, $y, @!angle[$!angle]);
            $x += $dx;
            $y += $dy;
        }

        $!angle = ($!angle + 1) % @!angle;
    }

    method spin($delay, Bool :$print) {
        start react {
            whenever Supply.interval($delay) -> $ {
                self.rotate;
                self.composite(:$print);
            }
        }
    }
}


#| A simple role to bounce a rectangular widget off its parent's edges
role EdgeBouncer {
    has $.dx = (-2 .. 2).pick;
    has $.dy = (-2 .. 2).pick;

    method move() {
        my $x += $.x + $!dx;
        my $y += $.y + $!dy;  # ++

        if $x < 0 {
            $x   = -$x;
            $!dx = -$!dx;
        }

        if $y < 0 {
            $y   = -$y;
            $!dy = -$!dy;
        }

        if $x + $.w > $.parent.w {
            $x   -= $x + $.w - $.parent.w;
            $!dx  = -$!dx;
        }

        if $y + $.h > $.parent.h {
            $y   -= $y + $.h - $.parent.h;
            $!dy  = -$!dy;
        }

        self.move-to($x, $y);
    }
}


#| A widget that randomly packs other widgets into itself
class RandomPacker is Terminal::Print::Widget
 does EdgeBouncer {
    has @.used;

    #| To start, the widget is completely unused
    submethod TWEAK() {
        @!used = [ False xx self.w ] xx self.h;
    }

    #| Returns True iff a rectangle will fit inside the widget
    method will-fit($x, $y, $w, $h --> Bool) {
        ($x + $w) <= $.w && ($y + $h) <= $.h;
    }

    #| Returns True iff all cells are inside the widget and not used
    method all-clear($x, $y, $w, $h --> Bool) {
        return False unless self.will-fit($x, $y, $w, $h);

        for ^$h -> $dy {
            my $row = @!used[$y + $dy];
            return False if $row[$x + $_] for ^$w;
        }

        True;
    }

    #| Set all cells in a rectangle as used
    method set-used($x, $y, $w, $h) {
        for ^$h -> $dy {
            my $row = @!used[$y + $dy];
            $row[$x + $_] = True for ^$w;
        }
    }

    #| Randomly generate and pack subwidgets into this widget
    method pack(:@sizes, :&create) {
        for $.grid.indices.pick(*) -> [$x, $y] {
            next if @!used[$y][$x];

            for @sizes.pick(*) -> [$w, $h] {
                if self.all-clear($x, $y, $w, $h) {
                    self.set-used($x, $y, $w, $h);
                    create(:$x, :$y, :$w, :$h, :parent(self));
                }
            }
        }
    }
}

sub MAIN(
    Int $count  #= Number of bouncing rectangles, each containing many spinners
) {
    die "Count must be > 0" unless $count > 0;

    $*SCHEDULER = ThreadPoolScheduler.new(:max_threads(255));

    T.initialize-screen;

    my $root = T.root-widget;

    my sub create(:$x, :$y, :$w, :$h, :$parent) {
        Spinner.new(:$x, :$y, :$w, :$h, :$parent).spin(.01 * (1..10).pick);
    }

    my @sizes = [3, 3], [5, 5], [7, 7], [9, 9];
    for ^$count {
        RandomPacker.new(:x((^50).pick), :y((^5).pick), :parent($root),
                         :w((10..20).pick), :h((10..20).pick))
                    .pack(:@sizes, :&create);
    }

    my @frames;
    my $last = now;
    for ^200 {
        $root.grid.clear;
        $root.children.map: { .move; .composite }
        $root.composite;

        my $now = now;
        @frames.push: %( :delta($now - $last), :tasks($*SCHEDULER.loads) );
        $last = $now;
    }

    sleep 2;
    T.shutdown-screen;

    say "FRAME TASKS SECONDS";
    for @frames.kv -> $i, %info {
        printf "%3d  %3d  %7.3f\n", $i, %info<tasks>, %info<delta>;
    }
}
