# ABSTRACT: A simple Mandelbrot set zoomer; looks best on a large terminal

use v6;
use Terminal::Print <T>;
use Terminal::Print::Pixelated;


my @colors =
    (0, 0, 1), (0, 0, 2), (0, 0, 3), (0, 0, 4), (0, 0, 5),  # Dark to bright blue
    (1, 1, 5), (2, 2, 5), (3, 3, 5), (4, 4, 5), (5, 5, 5),  # Light blue to white
    (5, 5, 4), (5, 5, 3), (5, 5, 2), (5, 5, 1), (5, 5, 0),  # Pale to bright yellow
    (5, 4, 0), (5, 3, 0), (5, 2, 0), (5, 1, 0), (5, 0, 0),  # Yellow-orange to red
    (4, 0, 0), (3, 0, 0), (2, 0, 0), (1, 0, 0), (0, 0, 0);  # Brick red to black

my @ramp = @colors.map: { ~(16 + 36 * .[0] + 6 * .[1] + .[2]) }


class Mandelbrot is Terminal::Print::PixelAnimation {
    has $.max-iter          = @ramp * 20 - 1;
    has $.cell-height-ratio = 2e0;   # XXXX: Should this be pushed down to Widget?

    #| Fix domain aspect ratio to match image ratio (= $.w / $.h, adjusted for $.cell-height-ratio)
    method adjust-aspect(Complex $size is copy) {
        my $image-aspect  = $.w / ($.h * $.cell-height-ratio);
        my $domain-aspect = $size.re / $size.im;

        if    $image-aspect > $domain-aspect {
            $size = Complex.new($size.re * $image-aspect / $domain-aspect, $size.im);
        }
        elsif $image-aspect < $domain-aspect {
            $size = Complex.new($size.re, $size.im * $domain-aspect / $image-aspect);
        }

        $size;
    }

    #| Mandelbrot escape iteration
    method mandel-iter(num $r, num $i) {
        # Cache as native value
        my int $max = $!max-iter;

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

    #| Draw a widget-filling Mandelbrot set image, bounded by the real and imaginary ranges
    method draw-mandel(:$real-range, :$imag-range) {
        my $h = 2 * $.h;  # double Y resolution

        # Distance covered by each pixel
        my $real-pixel = ($real-range.max - $real-range.min) / $.w;
        my $imag-pixel = ($imag-range.min - $imag-range.max) / $h;  # inverted Y coord

        # Coordinates of center of upper-left pixel
        my $real-offset = $real-range.min + .5e0 * $real-pixel;
        my $imag-offset = $imag-range.max - .5e0 * $imag-pixel;  # inverted Y coord

        # Main pixel loop
        my @pixels;
        my $ramp = +@ramp;
        for ^$h -> $y {
            my num $i = $y * $imag-pixel + $imag-offset;
            my num $r = $real-offset;
            my $row = @pixels[$y] = [];
            for ^$.w -> $x {
                $row[$x] = @ramp[self.mandel-iter($r, $i) % $ramp];
                $r += $real-pixel;
            }
        }

        @pixels;
    }

    #| Convert from center + size to real + imaginary ranges, then compute those Mandelbrot pixels
    method compute-pixels() {
        my $center = $.cur.center;
        my $size   = $.cur.size;

        my $reals = ($center.re - $size.re) .. ($center.re + $size.re);
        my $imags = ($center.im - $size.im) .. ($center.im + $size.im);

        self.draw-mandel(:real-range($reals), :imag-range($imags));
    }

    # Show the area on the current image that will be zoomed into
    method box-zoom($zoom-factor) {
        my $margin    = (1 - 1 / $zoom-factor) / 2;
        my $x-margin  = $.w * $margin;
        my $y-margin  = $.h * $margin;
        my ($x1, $x2) = $x-margin.floor, ($.w - 1 - $x-margin).floor;
        my ($y1, $y2) = $y-margin.floor, ($.h - 1 - $y-margin).floor;

        $.grid.print-string($x1, $y1, ' ' x ($.w / $zoom-factor), 'on_white');
        $.grid.print-string($x1, $y2, ' ' x ($.w / $zoom-factor), 'on_white');
        for ($y1 + 1) .. ($y2 - 1) -> $y {
            $.grid.print-string($x1, $y, ' ', 'on_white');
            $.grid.print-string($x2, $y, ' ', 'on_white');
        }
    }
}


#| Extra info we need for each Mandelbrot frame
class FrameInfo is Terminal::Print::FrameInfo {
    has Complex $.center;       #= Center of frame (and center of zoom)
    has Complex $.size;         #= Distance from center to edge along real and imaginary axes
}


# Draw a series of zooming Mandelbrot set images
sub MAIN() {
    T.initialize-screen;
    my $mandel = Mandelbrot.new-from-grid(T.current-grid);

    my $center = <-.744409151+.20400001i>;
    my $size   = $mandel.adjust-aspect(<1.25+1i>);

    my $t0 = now;
    my $zooms = 16;
    my $zoom-factor = 4e0;
    for 1..$zooms -> $i {
        my $frame = FrameInfo.new(:$center, :$size);
        $mandel.do-frame($frame);
        $mandel.composite;
        if $i < $zooms {
            $mandel.box-zoom($zoom-factor);
            $size /= $zoom-factor;
        }
    }
    my $t1 = now;

    # sleep 10;
    T.shutdown-screen;

    printf "%.3f seconds\n", $t1 - $t0;
}
