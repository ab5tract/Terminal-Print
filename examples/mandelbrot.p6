# ABSTRACT: A simple Mandelbrot set viewer

use v6;

use Terminal::Print;

my @colors =
    (0, 0, 1), (0, 0, 2), (0, 0, 3), (0, 0, 4), (0, 0, 5),  # Dark to bright blue
    (1, 1, 5), (2, 2, 5), (3, 3, 5), (4, 4, 5), (5, 5, 5),  # Light blue to white
    (5, 5, 4), (5, 5, 3), (5, 5, 2), (5, 5, 1), (5, 5, 0),  # Pale to bright yellow
    (5, 4, 0), (5, 3, 0), (5, 2, 0), (5, 1, 0), (5, 0, 0),  # Yellow-orange to red
    (4, 0, 0), (3, 0, 0), (2, 0, 0), (1, 0, 0), (0, 0, 0);  # Brick red to black

my @ramp = @colors.map: { ~(16 + 36 * .[0] + 6 * .[1] + .[2]) }


# Center rendering and fill oddly-aspected screen
sub adjust-aspect(:$w, :$h, :$real-range is copy, :$imag-range is copy) {
    my $height-ratio = 2e0;
    my $image-aspect = $w / ($h * $height-ratio);
    my $range-aspect = ($real-range.max - $real-range.min)
                     / ($imag-range.max - $imag-range.min);

    if    $image-aspect > $range-aspect {
        my $width   = ($imag-range.max - $imag-range.min) * $image-aspect;
        my $center  = ($real-range.max + $real-range.min) / 2e0;
        $real-range = ($center - $width / 2e0)  .. ($center + $width / 2e0);
    }
    elsif $image-aspect < $range-aspect {
        my $height  = ($real-range.max - $real-range.min) / $image-aspect;
        my $center  = ($imag-range.max + $imag-range.min) / 2e0;
        $imag-range = ($center - $height / 2e0) .. ($center + $height / 2e0);
    }

    ($real-range, $imag-range)
}


# Main image loop
sub draw-frame(:$w, :$h, :$real-range, :$imag-range, :$max-iter) {
    # Distance covered by each pixel
    my $real-pixel = ($real-range.max - $real-range.min) / $w;
    my $imag-pixel = ($imag-range.min - $imag-range.max) / $h;  # inverted Y coord

    # Coordinates of center of upper-left pixel
    my $real-offset = $real-range.min + .5e0 * $real-pixel;
    my $imag-offset = $imag-range.max - .5e0 * $imag-pixel;  # inverted Y coord

    # Mandelbrot escape iteration
    sub mandel-iter($c) {
        my $iters = 0;
        my $z = $c;
        while $z.abs < 2e0  && $iters < $max-iter {
            $z = $z * $z + $c;
            $iters++;
        }
        $iters;
    }

    # Main image loop
    for ^h -> $y {
        my $i = $y * $imag-pixel + $imag-offset;
        for ^w -> $x {
            my $r = $x * $real-pixel + $real-offset;
            my $c = Complex.new($r, $i);
            my $iters = mandel-iter($c);
            T.current-grid.set-span($x, $y, ' ', 'on_' ~ @ramp[$iters]);
            # T.current-grid.set-span($x, $y, $iters.base(36), @ramp[$iters]);  # Debug iteration count/color ramp
        }
        print T.current-grid.span-string(0, w - 1, $y);
    }
}


# Draw one frame
T.initialize-screen;
my ($real-range, $imag-range) = adjust-aspect(:w(w), :h(h),
                                              :real-range(-2e0 .. .5e0),
                                              :imag-range(-1e0 ..  1e0));

my $t0 = now;
draw-frame(:w(w), :h(h), :$real-range, :$imag-range, :max-iter(@ramp.end));
my $t1 = now;


# sleep 10;
T.shutdown-screen;

printf "%.3f seconds\n", $t1 - $t0;
