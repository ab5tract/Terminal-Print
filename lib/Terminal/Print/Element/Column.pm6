class Terminal::Print::Element::Column;

use Terminal::Print::Element::Cell;

has @.cells is rw;
has $.column;
has $!max-rows;

method new( :$max-rows, :$column ) {
    my @cells;
    for ^$max-rows { @cells[$_] = Terminal::Print::Element::Cell.new };
    self.bless( :$max-rows, :$column, :@cells );
}

method at_pos( $y ) {
    @!cells[$y];
}

method assign_pos ( $y, Str $char ) {
    @!cells[$y].clear-cell-string;
    @!cells[$y].char = $char;
}
