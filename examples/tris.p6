use Terminal::Print;
use Terminal::Print::RawInput;


#| Coordinates of blocks within mino relative to rotation center
my %minos =
    O => [ [ ( 0, 0), ( 1, 0), (0, 1), (1, 1) ], ],
    I => [ [ (-1, 0), ( 0, 0), (1, 0), (2, 0) ],
           [ (0, -1), ( 0, 0), (0, 1), (0, 2) ], ],
    T => [ [ (-1, 0), ( 0, 0), (1, 0), (0, 1) ],
           [ (0, -1), (-1, 0), (0, 0), (0, 1) ],
           [ (0, -1), (-1, 0), (0, 0), (1, 0) ],
           [ (0, -1), ( 0, 0), (1, 0), (0, 1) ], ],
    L => [ [ (1, -1), (-1, 0), (0, 0), (1, 0) ],
           [(-1, -1), (0, -1), (0, 0), (0, 1) ],
           [ (-1, 0), ( 0, 0), (1, 0), (-1, 1)],
           [ (0, -1), ( 0, 0), (0, 1), (1, 1) ], ],
    J => [ [(-1, -1), (-1, 0), (0, 0), (1, 0) ],
           [ (0, -1), ( 0, 0), (-1, 1), (0, 1)],
           [ (-1, 0), ( 0, 0), (1, 0), (1, 1) ],
           [ (0, -1), (1, -1), (0, 0), (0, 1) ], ],
    S => [ [ (0,  0), ( 1, 0), (-1, 1), (0, 1)],
           [ (0, -1), ( 0, 0), (1, 0), (1, 1) ], ],
    Z => [ [ (-1, 0), ( 0, 0), (0, 1), (1, 1) ],
           [ (1, -1), ( 0, 0), (1, 0), (0, 1) ], ],
;

#| Each mino type has a single fixed color to aid identification
my %colors =
    O => 'yellow', I => 'cyan',  T => 'magenta', L => 'white',
    J => 'blue',   S => 'green', Z => 'red';


#| Similar to a famously addictive block-dropping twitch puzzle game
sub MAIN() {
    T.initialize-screen;

    my $w = 12;                         # In fullwidth blocks (to appear square)
    my $x = $w div 2;                   # Start drops from center of play area
    my $x-off = (w div 2 - $w) div 2;   # Center play area horizontally

    my ($mino, $next-mino) = %minos.keys.pick xx 2;
    my $orientation = 0;

    #| Erase and redraw mino after state changes
    sub redraw() {
        state $old-x = $x;
        state $old-m = $mino;
        state $old-o = $orientation;

        my $grid = T.current-grid;
        my $old-blocks = %minos{$old-m}[$old-o];
        my $new-blocks = %minos{$mino}[$orientation];

        sub set-blocks(@blocks, $x, $color) {
            for @blocks -> ($dx, $dy) {
                $grid.set-span(($x + $dx) * 2, 1 + $dy, '  ', $color);
            }
        }

        set-blocks($old-blocks, $x-off + $old-x, '');
        set-blocks($new-blocks, $x-off + $x, 'on_' ~ %colors{$mino});

        my $min = min $old-x - 1, $x - 1;
        my $max = max $old-x + 2, $x + 2;
        print $grid.span-string(($x-off + $min) * 2,
                                ($x-off + $max) * 2 + 1, $_) for ^4;

        $old-x = $x;
        $old-m = $mino;
        $old-o = $orientation;
    }
    redraw;

    my $in-supply = raw-input-supply;
    $in-supply.act: -> $_ {
        when 'q' { $in-supply.done }  # Quit
        when ' ' { ($mino, $next-mino) = $next-mino, %minos.keys.pick;
                   $x = $w div 2; $orientation = 0; redraw }  # XXXX: Hard drop
        when 'z' { $orientation = ($orientation - 1) % %minos{$mino}.elems; redraw }  # Rotate left
        when 'x' { $orientation = ($orientation + 1) % %minos{$mino}.elems; redraw }  # Rotate right
        when ',' { $x = max($x - 1, 0);      redraw }  # Move left
        when '.' { $x = min($x + 1, $w - 1); redraw }  # Move right
    }

    T.shutdown-screen;
}
