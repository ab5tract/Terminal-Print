class Terminal::Print::Element::Grid;

use Terminal::Print::Element::Column;
use Terminal::Print::Commands;

my constant T = Terminal::Print::Commands;

has @.grid;
has @.buffer;

has $.max-columns;
has $.max-rows;

has @.grid-indices;
has @.column-range;
has @.row-range;

has $!grid-string;

method new( :$max-columns, :$max-rows ) {
    my @column-range = (0..^$max-columns).values;
    my @row-range = (0..^$max-rows).values;
    my @grid-indices = (@column-range X @row-range).map({ [$^x, $^y] });

    my (@grid, @buffer);
    for @column-range -> $x {
        @grid[ $x ] //= Terminal::Print::Element::Column.new( :$max-rows, column => $x );
        for @grid[ $x ].cells.kv -> $y, $cell {
            $cell.x = $x;
            $cell.y = $y;
            $cell.clear-cell-string;
        }
    }

    for @grid-indices -> [$x,$y] {
        @buffer[$x + ($y * $max-columns)] := @grid[ $x ][ $y ];
    }

    self.bless( :$max-columns, :$max-rows, :@grid-indices,
                :@column-range, :@row-range, :@grid, :@buffer );
}

method at_pos( $column ) {
    @!grid[ $column ];
}

method print-grid {
    print move-cursor(0,0) ~ self;
}

method print-row( $y ) {
    my $row-string = [~] @!grid[*][$y] for ^$!max-columns;
    print move-cursor(0,$y) ~ $row-string;
}

method Str {
    if not $!grid-string.defined {
        for 0..^$!max-rows -> $y {
            $!grid-string ~= [~] ~@!grid[$_][$y] for @!column-range;
        }
    }
    $!grid-string;
}
