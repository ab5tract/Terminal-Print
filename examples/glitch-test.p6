use Terminal::Print;

T.initialize-screen;

for ^10 {
    T.current-grid.grid = [ [ 'BUG' xx w ] xx h ];

    for ^h -> $y {
        for ^(w div 2) -> $x {
            # Failure.new() // '';  # Triggers glitches
            # Exception.new() // '';  # Doesn't glitch

            T.current-grid.change-cell($x * 2,     $y, ' |');
            T.current-grid.change-cell($x * 2 + 1, $y, ''  );
        }
    }

    print T.current-grid;
    sleep 1;
}

T.shutdown-screen;
