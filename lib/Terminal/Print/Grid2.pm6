use OO::Monitors;

monitor Terminal::Print::Grid2 {
    has $.rows;
    has $.columns;
    has @.grid-indices;
    has @.grid;

    method new($columns, $rows) {
        my @grid-indices = (^$columns X ^$rows)>>.Array;
        my @grid;
        for @grid-indices -> [$x, $y] {
            @grid[$x] //= [];
            @grid[$x][$y] = " ";
        }
        self.bless(:$columns, :$rows, :@grid, :@grid-indices);
    }

    method cell-string($x, $y, $move-cursor) {
        "{$move-cursor($x, $y)}{@!grid[$x][$y]}"
    }

    method change-cell($x, $y, $c) {
        @!grid[$x][$y] = $c
    }

    multi method print-cell($x, $y, $move-cursor) {
        print self.cell-string($x, $y);
    }

    multi method print-cell($x, $y, $c, $move-cursor) {
        @!grid[$x][$y] = $c;
        #dd &!move-cursor; die;
        print self.cell-string($x, $y, $move-cursor);
    }
}
