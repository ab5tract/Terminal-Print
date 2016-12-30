use OO::Monitors;

# Only shows glitches when a monitor instead of a class
# class Grid {
monitor Grid {
    has $.w;
    has $.h;
    has @.grid;

    method change-cell($x, $y, $s) {
        @!grid[$y][$x] = $s;
    }

    # Very weird occasional crash bug if this is commented out:
    #    Cannot resolve caller infix:<div>(Nil, Int)
    # method Str() { '' }
}


my $w    = +q:x{ tput cols  };
my $h    = +q:x{ tput lines };
my $grid = Grid.new(:$w, :$h);

for ^10 {
    # Occasionally produces "Use of Nil in numeric context"
    $grid.grid = [ [ 'BUG' xx $grid.w ] xx $grid.h ];

    for ^$grid.h -> $y {
        for ^($grid.w div 2) -> $x {
            Failure.new() // '';  # Triggers glitches
            # Exception.new() // '';  # Doesn't glitch

            $grid.change-cell($x * 2,     $y, ' |');
            $grid.change-cell($x * 2 + 1, $y, ''  );
        }
    }

    # ANSI command here just makes image easier to watch, but can be removed
    print ^$h .map({ "\e[{ $_ + 1 };1H" ~ $grid.grid[$_].join });
    sleep 1;
}
