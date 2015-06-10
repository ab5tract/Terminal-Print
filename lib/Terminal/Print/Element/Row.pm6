class Terminal::Print::Element::Row;


has @!cells;

method new( *@cells ) {
    self.bless( :@cells );
}

submethod BUILD( :@cells ) {
    @!cells[$_] := @cells[$_] for ^@cells.elems;
}

method row-escape-sequence {
    [~] @!cells[].map: *.cell-string;
}

method print-row {
    print self.row-escape-sequence;
}

method AT-POS( $pos ) {
     ~  @!cells[$pos];
}

method at_assign( $pos, Str $char ) {
    @!cells[$pos].clear-cell;
    @!cells[$pos].char = $char;
}

method Str {
    [~] @!cells;
}
