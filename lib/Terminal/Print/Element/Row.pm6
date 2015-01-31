class Terminal::Print::Element::Row;


has @!cells;

method new( *@cells ) {
    self.bless( :@cells );
}

submethod BUILD( :@cells ) {
    @!cells[$_] := @cells[$_] for ^@cells.elems;
}

method row-escape-sequence {
    [~] @!cells>>.cell-string;
}

method at_pos( $pos ) {
     ~  @!cells[$pos];
}

method Str {
    [~] @!cells;
}
