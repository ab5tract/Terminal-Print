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
    my $grid = T.current-grid;

    my $w = 12;                         # In fullwidth blocks (to appear square)
    my $h = min(h, 24) - 1;             # Fill the majority of a vt100 terminal
    my $x = $w div 2;                   # Start drops from center of play area
    my $y = -1;                         # redraw() will cause blocks to fall
    my $x-off = (w div 2 - $w) div 2;   # Center play area horizontally

    my ($mino, $next-mino) = %minos.keys.pick xx 2;
    my $orientation = 0;

    #| Erase and redraw mino after state changes
    sub redraw() {
        # Remember previous frame's values so we can erase moved blocks
        state $old-x = $x;
        state $old-y = $y;
        state $old-m = $mino;
        state $old-o = $orientation;

        # XXXX: HACK, just drop one line per frame
        $y++;

        # Erase the old, draw the new
        sub set-blocks(@blocks, $x, $y, $color) {
            for @blocks -> ($dx, $dy) {
                next unless 0 <= $y + $dy < $h;
                $grid.set-span(($x + $dx) * 2, $y + $dy, '  ', $color);
            }
        }

        my $old-blocks = %minos{$old-m}[$old-o];
        my $new-blocks = %minos{$mino}[$orientation];
        set-blocks($old-blocks, $x-off + $old-x, $old-y, '');
        set-blocks($new-blocks, $x-off + $x, $y, 'on_' ~ %colors{$mino});

        # Find (conservative) bounds of "damaged" area
        my $min-x = max 0,      min $old-x - 1, $x - 1;
        my $max-x = min $w - 1, max $old-x + 2, $x + 2;
        my $min-y = max 0,      min $old-y - 1, $y - 1;
        my $max-y = min $h - 1, max $old-y + 2, $y + 2;

        # Reprint entire area within damage bounds
        print $grid.span-string(($x-off + $min-x) * 2,
                                ($x-off + $max-x) * 2 + 1, $_)
            for $min-y .. $max-y;

        # Everything new is old again
        $old-x = $x;
        $old-y = $y;
        $old-m = $mino;
        $old-o = $orientation;
    }

    #| Draw the next mino that will come after the current one is locked in
    sub draw-next-mino() {
        my $x = $x-off + $w + 2;
        my $y = 3;

        my @blocks := %minos{$next-mino}[0];
        my $color   = 'on_' ~ %colors{$next-mino};

        $grid.set-span($x * 2, $y + $_, '  ' x +@blocks, '') for ^(+@blocks);

        for @blocks -> ($dx, $dy) {
            $grid.set-span(($x + $dx + 1) * 2, $y + $dy + 1, '  ', $color);
        }

        print $grid.span-string($x * 2, ($x + @blocks - 1) * 2, $y + $_)
            for ^(+@blocks);
    }

    #| Draw the playing field, indicators, key bindings, etc.
    sub draw-field() {
        # Sides
        for ^$h -> $y {
            $grid.print-string( $x-off * 2 - 2,   $y, '  ', 'on_white');
            $grid.print-string(($x-off + $w) * 2, $y, '  ', 'on_white');
        }

        # Bottom
        $grid.print-string($x-off * 2 - 2, $h, '  ' x ($w + 2), 'on_white');

        # Score and Next indicators
        my $right = ($x-off + $w + 2) * 2;
        $grid.print-string($right, 0, 'Score:');
        $grid.print-string($right, 2, 'Next:');

        # Keymap
        my @keys = q => 'quit', space => 'drop', z => 'rotate left',
                   x => 'rotate right', ',' => 'move left', '.' => 'move right';
        for @keys.kv -> $i, (:$key, :$value) {
            $grid.print-string($right, 7 + $i, sprintf "%-6s  %s", $key, $value);
        }

        # Initial and next mino
        redraw;
        draw-next-mino;
    }

    #| Push away from walls as needed to fit current orientation
    sub wall-bump($x, $mino, $orientation) {
        my @xs = %minos{$mino}[$orientation]».[0];
        min(max($x, 0, -@xs.min), $w - 1 - @xs.max)
    }

    # Draw the initial playing area
    draw-field;

    # Main game loop
    my $in-supply = raw-input-supply;
    $in-supply.act: -> $_ {
        when 'q' { $in-supply.done }  # Quit
        when ' ' { ($mino, $next-mino) = $next-mino, %minos.keys.pick;
                   $x = $w div 2; $y = -1; $orientation = 0; redraw; draw-next-mino }  # XXXX: Hard drop
        when 'z' { $orientation = ($orientation - 1) % %minos{$mino}.elems;
                   $x = wall-bump($x, $mino, $orientation); redraw }  # Rotate left
        when 'x' { $orientation = ($orientation + 1) % %minos{$mino}.elems;
                   $x = wall-bump($x, $mino, $orientation); redraw }  # Rotate right
        when ',' { $x = wall-bump($x - 1, $mino, $orientation); redraw }  # Move left
        when '.' { $x = wall-bump($x + 1, $mino, $orientation); redraw }  # Move right
    }

    T.shutdown-screen;
}
