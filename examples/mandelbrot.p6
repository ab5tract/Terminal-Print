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

my $max-iter = @ramp.end;


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


my $min-imag = -1e0;
my $max-imag =  1e0;
my $min-real = -2e0;
my $max-real = .5e0;

T.initialize-screen;

# Center rendering in oddly-aspected screen
my $height-ratio = 2e0;
my $aspect = w / (h * $height-ratio);
if $aspect > ($max-real - $min-real) / ($max-imag - $min-imag) {
    my $width  = ($max-imag - $min-imag) * $aspect;
    my $center = ($min-real + $max-real) / 2e0;
    $min-real  = $center - $width / 2e0;
    $max-real  = $center + $width / 2e0;
}
else {
    my $height = ($max-real - $min-real) / $aspect;
    my $center = ($min-imag + $max-imag) / 2e0;
    $min-imag = $center - $height / 2e0;
    $max-imag = $center + $height / 2e0;
}


# Main image loop
for ^h -> $y {
    my $i = ($y + .5e0) / h * ($min-imag - $max-imag) + $max-imag;  # inverted Y coord
    for ^w -> $x {
        my $r = ($x + .5e0) / w * ($max-real - $min-real) + $min-real;
        my $c = Complex.new($r, $i);
        my $iters = mandel-iter($c);
        T.current-grid.set-span($x, $y, '█', @ramp[$iters]);
        # T.current-grid.set-span($x, $y, $iters.base(36), @ramp[$iters]);  # Debug iteration count/color ramp
    }
    print T.current-grid.span-string(0, w - 1, $y);
}

sleep 10;
T.shutdown-screen;
