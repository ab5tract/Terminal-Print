# ABSTRACT: Display linear and sqrt light sources of various radii in 16- and 256-color variants

use v6;
use Terminal::Print;


sub yellowish-light($cx, $cy, $radius, :$color-bits = 4, :$sqrt) {
    my $radius2 = $radius * $radius;
    my $r_num   = $radius.Num;
    my $grid    = T.current-grid;

    for (-$radius) .. $radius -> $dy {
        my $y = $cy + $dy;

        for (-$radius) .. $radius -> $dx {
            my $x = $cx + $dx;

            my $dist2 = $dy * $dy + $dx * $dx;
            next if $dist2 >= $radius2;

            # Oddness of following lines brought to you by micro-optimization
            my $brightness = (1e0 - $dist2.sqrt / $r_num);
               $brightness = $brightness.sqrt if $sqrt;
               $brightness = (13e0 * $brightness).ceiling;
            # Ramp from black to bright yellow to white:  16 + 36 * r + 6 * g + b
            my $color      = 16 + 42 * (1 + (min 8, $brightness) div 2) + max(0, $brightness - 8);
            # $.grid.change-cell($x, $y, ~$brightness);  # DEBUG: show brightness levels
            $grid.print-cell($x, $y, %( char  => '█',
                                        color => $color-bits >  4 ?? ~$color       !!
                                                 $brightness > 11 ?? 'bold white'  !!
                                                 $brightness >  7 ?? 'bold yellow' !!
                                                                     'yellow'      ));
        }
    }
}


T.initialize-screen;

for 4, 8 -> $color-bits {
    for 1..7 -> $radius {
        T.print-string( 60,  7, 'linear');
        T.print-string( 60, 21, 'sqrt');
        T.print-string( $radius * $radius,  0, $radius);
        yellowish-light($radius * $radius,  7, $radius, :$color-bits);
        yellowish-light($radius * $radius, 21, $radius, :$color-bits, :sqrt);
    }

    sleep 10;
}

T.shutdown-screen;
