# ABSTRACT: Render a number of different attack animations


use Terminal::Print;
use Terminal::Print::Widget;


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
            @.children.map: { start .?do-frame }
        }
        else {
            .?do-frame for @.children;

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
        .compose for @.children;
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
    has $.speed is required;  #= cells / second

    method draw-frame() {
        my $dist = $.speed * $.rel.time;
        return if $dist >= $.w;

        self.clear-frame;
        $.grid.change-cell($dist.floor, $.h div 2, '→');
    }
}


sub MAIN() {
    T.initialize-screen;
    my $root = T.root-widget;
    my $arrow = Arrow.new(:x(0), :y(0), :w(50), :h(5), :parent($root), :speed(30));

    my $start = now;
    while 10 > (now - $start) {
        my $frame = FrameInfo.new(:id($++), :time(now));
        $arrow.do-frame($frame);
        $arrow.composite;
    }

    sleep 2;
    T.shutdown-screen;
}
