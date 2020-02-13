use v6.d.PREVIEW;
use Terminal::Print <T>;
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

    my $w = 12;                         # Fullwidth blocks (to appear square)
    my $h = min(h, 24) - 1;             # Fill the majority of a vt100 screen
    my $x = $w div 2;                   # Start drops from center of play area
    my $y = -1;                         # redraw() will cause blocks to fall
    my $x-off = (w div 2 - $w) div 2;   # Center play area horizontally
    my $score-x = ($x-off + $w + 2) * 2 + 8;

    my ($mino, $next-mino) = %minos.keys.pick xx 2;
    my $orientation = 0;
    my $score = 0;

    # Remember previous frame's values so we can erase moved blocks
    state ($old-x, $old-y, $old-m, $old-o);  # ,
    sub set-old-state() {
        $old-x = $x;
        $old-y = $y;
        $old-m = $mino;
        $old-o = $orientation;
    }

    #| Set blocks relative to (x, y) to a given color; x is in fullwidth cells
    sub set-blocks(@blocks, $x, $y, $color) {
        for @blocks -> ($dx, $dy) {
            next unless 0 <= $y + $dy < $h;
            $grid.set-span(($x + $dx) * 2, $y + $dy, '  ', $color);
        }
    }

    #| Erase and redraw mino after state changes
    sub redraw-mino() {
        # Erase the old, draw the new
        my $old-blocks = %minos{$old-m}[$old-o];
        my $new-blocks = %minos{$mino}[$orientation];
        set-blocks($old-blocks, $x-off + $old-x, $old-y, '');
        set-blocks($new-blocks, $x-off + $x, $y, 'on_' ~ %colors{$mino});

        # Find (conservative) bounds of "damaged" area
        my $min-x = max 0,      min $old-x - 1, $x - 1;
        my $max-x = min $w - 1, max $old-x + 2, $x + 2;
        my $min-y = max 0,      min $old-y - 1, $y - 1;
        my $max-y = min $h - 1, max $old-y + 2, $y + 2;  # =

        # Reprint entire area within damage bounds
        print $grid.span-string(($x-off + $min-x) * 2,
                                ($x-off + $max-x) * 2 + 1, $_)
            for $min-y .. $max-y;  # .

        # Everything new is old again
        set-old-state;
    }

    #| Draw per-frame updates
    sub redraw() {
        redraw-mino;

        $grid.print-string($score-x, 0, $score);
    }

    #| Draw the next mino that will come after the current one is locked in
    sub draw-next-mino() {
        my $x = $x-off + $w + 2;
        my $y = 3;

        my @blocks := %minos{$next-mino}[0];
        my $color   = 'on_' ~ %colors{$next-mino};

        $grid.set-span($x * 2, $y + $_, '  ' x +@blocks, '') for ^(+@blocks);

        set-blocks(@blocks, $x + 1, $y + 1, $color);

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
        my @keys = q   => 'quit',        space => 'drop',
                   z   => 'rotate left', x     => 'rotate right',
                   ',' => 'move left',   '.'   => 'move right';
        for @keys.kv -> $i, (:$key, :$value) {
            $grid.print-string($right, 7 + $i,
                               sprintf "%-6s  %s", $key, $value);
        }

        # Initial and next mino
        set-old-state;
        draw-next-mino;
        redraw;
    }

    #| Push away from side walls as needed to fit current orientation
    sub wall-bump($x, $mino, $orientation) {
        my @xs = %minos{$mino}[$orientation]».[0];
        min(max($x, 0, -@xs.min), $w - 1 - @xs.max)
    }

    #| Check for collisions before making a move or rotation
    sub would-collide($mx, $my, $mo) {
        my @orientations := %minos{$mino};

        # First make sure the mino doesn't detect a false self-collision
        my @current-blocks := @orientations[$orientation];
        set-blocks(@current-blocks, $x + $x-off, $y, '');

        # Assume no collision, then look for trouble
        my  $would-collide    = False;
        my  @proposed-blocks := @orientations[($orientation + $mo)
                                              % @orientations];
        for @proposed-blocks -> $block ($dx, $dy) {
            my $bx = ($x + $dx + $mx + $x-off) * 2;
            my $by =  $y + $dy + $my;
            next if $by < 0;
            $would-collide = True if $bx < 0 || $grid.grid[$by][$bx].?color;
        }

        # Restore the original mino before returning the collision result
        set-blocks(@current-blocks, $x + $x-off, $y, %colors{$mino});
        $would-collide
    }

    #| Attempt to move to the side
    sub try-move($mx) {
        $x += $mx unless would-collide($mx, 0, 0);
    }

    #| Attempt to rotate, possibly resolving collisions by kicking right/left
    sub try-rotate($mo) {
        for 0, 1, -1 -> $mx {
            next if would-collide($mx, 0, $mo);

            $x += $mx;
            $orientation = ($orientation + $mo) % %minos{$mino};
            last;
        }
    }

    #| Check whether a particular row has no gaps
    sub row-complete($ry) {
        my $row   := $grid.grid[$ry];
        my @filled = (^$w).grep: { $row[($_ + $x-off) * 2].?color };

        @filled == $w
    }

    #| Find any lines that would clear
    sub clearable-rows() {
        (^$h).grep: { row-complete($_) };
    }

    #| Copy all blocks from $src row to $dst row
    sub copy-row($src, $dst) {
        my ($left, $right) = $x-off * 2, ($x-off + w) * 2 - 1;
        $grid.grid[$dst].splice($left, $w * 2,
                                $grid.grid[$src][$left .. $right]);
    }

    #| Move all blocks from $src row to $dst row, printing result
    sub move-row($src, $dst) {
        return if $src == $dst;
        copy-row($src, $dst);
        print $grid.span-string($x-off * 2, ($x-off + $w) * 2 - 1, $dst);
        $grid.print-string($x-off * 2, $src, '  ' x $w, '');
    }

    #| Try to clear some filled rows
    sub try-clear() {
        my @rows = clearable-rows;
        return 0 unless @rows;

        # Flash white
        $grid.print-string($x-off * 2, $_, '  ' x $w, 'on_white') for @rows;
        sleep .1;

        # Drop uncleared rows into place
        my $dst = $h - 1;
        for (^$h).reverse -> $src {
            next if $src ∈ @rows;
            move-row($src, $dst--);
        }

        # Update score
        $score += @rows² * 100;
        $grid.print-string($score-x, 0, $score);

        +@rows
    }

    #| Print the game over message and exit after a short delay
    sub game-over() {
        my $message = "　ＧＡＭＥ　ＯＶＥＲ！　";
        $grid.print-string($x-off * 2, $h div 2 - 1, '  ' x $w, '');
        $grid.print-string($x-off * 2, $h div 2,     $message,  'white');
        $grid.print-string($x-off * 2, $h div 2 + 1, '  ' x $w, '');
        sleep 3;
        done;
    }

    #| Drop or lock in
    sub try-drop() {
        if would-collide(0, 1, 0) {
            redraw;
            try-clear() or $y < 0 && game-over;
            ($mino, $next-mino) = $next-mino, %minos.keys.pick;
            $x = $w div 2;
            $y = -1;
            $orientation = 0;
            set-old-state;
            draw-next-mino;
            redraw;
            False;
        }
        else {
            ++$y;
            redraw;
            True;
        }
    }

    # Draw the initial playing area
    draw-field;

    # Main game loop
    class Tick { }
    my $in-supply = raw-input-supply;
    my $timer     = Supply.interval(.2).map: { Tick };
    my $supplies  = Supply.merge($in-supply, $timer);

    react {
        whenever $supplies -> $_ {
            when Tick { try-drop                }  # Timer Tick
            when 'q'  { done                    }  # Quit
            when ' '  { ++$score while try-drop }  # Hard drop
            when 'z'  { try-rotate(-1); redraw  }  # Rotate left
            when 'x'  { try-rotate(+1); redraw  }  # Rotate right
            when ','  { try-move(-1);   redraw  }  # Move left
            when '.'  { try-move(+1);   redraw  }  # Move right
        }
    }

    T.shutdown-screen;
}
