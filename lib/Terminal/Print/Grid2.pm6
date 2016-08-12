use OO::Monitors;

monitor Terminal::Print::Grid2 {
    has $.rows = 0;
    has $.columns = 0;
    has @.grid-indices = (^$!columns X ^$!rows)>>.Array;
    has @.grid is rw = do {
        my @grid;
        for @!grid-indices -> [$x, $y] {
            @grid[$x] //= [];
            @grid[$x][$y] = " ";
        }
        @grid
    };
}
