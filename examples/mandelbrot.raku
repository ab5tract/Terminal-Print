# ABSTRACT: A simple Mandelbrot set zoomer; looks best on a large terminal

use v6;
use Terminal::Print <T>;


my @colors =
    (0, 0, 1), (0, 0, 2), (0, 0, 3), (0, 0, 4), (0, 0, 5),  # Dark to bright blue
    (1, 1, 5), (2, 2, 5), (3, 3, 5), (4, 4, 5), (5, 5, 5),  # Light blue to white
    (5, 5, 4), (5, 5, 3), (5, 5, 2), (5, 5, 1), (5, 5, 0),  # Pale to bright yellow
    (5, 4, 0), (5, 3, 0), (5, 2, 0), (5, 1, 0), (5, 0, 0),  # Yellow-orange to red
    (4, 0, 0), (3, 0, 0), (2, 0, 0), (1, 0, 0), (0, 0, 0);  # Brick red to black

my @ramp = @colors.map: { ~(16 + 36 * .[0] + 6 * .[1] + .[2]) }


# Fix domain aspect ratio to match image ratio ($w / $h)
sub adjust-aspect(:$w, :$h, :$size is copy) {
    my $height-ratio  = 2e0;
    my $image-aspect  = $w / ($h * $height-ratio);
    my $domain-aspect = $size.re / $size.im;

    if    $image-aspect > $domain-aspect {
        $size = Complex.new($size.re * $image-aspect / $domain-aspect, $size.im);
    }
    elsif $image-aspect < $domain-aspect {
        $size = Complex.new($size.re, $size.im * $domain-aspect / $image-aspect);
    }

    $size;
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
    sub mandel-iter(num $r, num $i) {
        # Cache as native value
        my int $max = $max-iter;

        # Quick skip for main cardioid
        my num $re = $r - .25e0;
        my num $i2 = $i * $i;
        my num $q  = $re * $re + $i2;
        return $max if $q * ($q + $re) * 4e0 < $i2;

        # Quick skip for period-2 bulb
        my num $r1 = $r + 1e0;
        return $max if $r1 * $r1 + $i2 < .0625e0;  # 1/16

        # Fall back to good old fashioned iteration
        my int $iters = 0;
        my num $zr = $r;
        my num $zi = $i;
        while ((my num $zr2 = $zr * $zr) + (my num $zi2 = $zi * $zi)) < 4e0  && $iters < $max {
            $zi = 2e0 * $zr * $zi + $i;
            $zr = $zr2 - $zi2 + $r;
            ++$iters;
        }
        $iters;
    }

    # Main image loop
    for ^h -> $y {
        my num $i = $y * $imag-pixel + $imag-offset;
        my num $r = $real-offset;
        for ^w -> $x {
            my $iters = mandel-iter($r, $i);
            T.current-grid.set-span($x, $y, ' ', 'on_' ~ @ramp[$iters % @ramp]);
            $r += $real-pixel;
        }
        print T.current-grid.span-string(0, w - 1, $y);
    }
}


# Show the area on the current image that will be zoomed into
sub box-zoom(:$w, :$h, :$zoom-factor) {
    my $margin    = (1 - 1 / $zoom-factor) / 2;
    my $x-margin  = $w * $margin;
    my $y-margin  = $h * $margin;
    my ($x1, $x2) = $x-margin.floor, ($w - 1 - $x-margin).floor;
    my ($y1, $y2) = $y-margin.floor, ($h - 1 - $y-margin).floor;

    T.current-grid.print-string($x1, $y1, ' ' x ($w / $zoom-factor), 'on_white');
    T.current-grid.print-string($x1, $y2, ' ' x ($w / $zoom-factor), 'on_white');
    for ($y1 + 1) .. ($y2 - 1) -> $y {
        T.current-grid.print-string($x1, $y, ' ', 'on_white');
        T.current-grid.print-string($x2, $y, ' ', 'on_white');
    }
}


# Zoom in iteratively on a $center point
sub zoom-in(:$w, :$h, :$center, :$size is copy, :$zooms, :$zoom-factor) {
    for ^$zooms {
        my $reals = ($center.re - $size.re) .. ($center.re + $size.re);
        my $imags = ($center.im - $size.im) .. ($center.im + $size.im);

        draw-frame(:$w, :$h, :max-iter(@ramp * 20 - 1),
                   :real-range($reals), :imag-range($imags));

        box-zoom(:$w, :$h, :$zoom-factor);
        $size /= $zoom-factor;
    }
}


# Draw a series of zooming images
T.initialize-screen;
# From https://en.wikipedia.org/wiki/Mandelbrot_set
# my $center = <0.001643721971153-0.822467633298876i>;
my $center = <-.744409151+.20400001i>;
my $size = adjust-aspect(:w(w), :h(h), :size(<1.25+1i>));
my $t0 = now;
zoom-in(:w(w), :h(h), :$center, :$size, :zooms(16), :zoom-factor(4e0));
my $t1 = now;
# sleep 10;
T.shutdown-screen;

printf "%.3f seconds\n", $t1 - $t0;
