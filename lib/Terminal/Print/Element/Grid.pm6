unit class Terminal::Print::Element::Grid;

use Terminal::Print::Element::Column;
use Terminal::Print::Element::Row;
use Terminal::Print::Commands;

my constant T = Terminal::Print::Commands;

has @.grid;
has @.buffer;
has @.rows;

has $.max-columns;
has $.max-rows;

has @.grid-indices;
has @.column-range;
has @.row-range;

has %!grep-cache;

has Str $!grid-string;

method new( :$max-columns, :$max-rows ) {
    my @column-range = ^$max-columns;
    my @row-range    = ^$max-rows;
    my @grid-indices = @column-range X @row-range;

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

    my @rows;
    for @row-range -> $y {
        push @rows, Terminal::Print::Element::Row.new( @grid[][$y] );
    }

    self.bless( :$max-columns, :$max-rows, :@grid-indices,
                :@column-range, :@row-range, :@grid, :@buffer, :@rows );
}

method AT-POS( $column ) {
    @!grid[ $column ];
}

method print-grid {
    print move-cursor(0,0) ~ self;
}

method print-row( $y ) {
    print move-cursor(0,$y) ~ ~@!rows[$y];
}

multi method grep-grid( $test ) {
    %!grep-cache{$test.WHICH} //= do for @!grid-indices -> [$x,$y] {
        [$x,$y] if $test($x,$y);
    }
}
         
multi method grep-grid( $test, :$p! ) {
    %!grep-cache{$test.WHICH} //= do for @!grid-indices -> [$x,$y] {
        @!grid[$x][$y].print-cell if $test($x,$y);
    }
}

multi method grep-grid( $test, :$p!, :$o! ) {
    %!grep-cache{$test.WHICH} //= do for @!grid-indices -> [$x,$y] {
        if $test($x,$y) {
            @!grid[$x][$y].print-cell;
        } else {
            @!grid[$x][$y].clear-cell-string;
        }
    }
}

method Str {
    if not $!grid-string.defined {
        for 0..^$!max-rows -> $y {
            $!grid-string ~= [~] ~@!grid[$_][$y] for @!column-range;
        }
    }
    $!grid-string;
}
