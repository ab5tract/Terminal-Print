unit class Terminal::Print::Element::Cell; 

use Terminal::Print::Commands;
my constant T = Terminal::Print::Commands;

has $.x is rw;
has $.y is rw;
has $.char is rw;
has %.attr is rw;
has $!print-string;

# not working as expected ...
method set( :$x, :$y, :$char ) {
    $!x = $x ?? $x !! $!x;
    $!y = $y ?? $y !! $!y;
    $!char = $char ?? $char !! $char;
}

# TODO: throw specific exceptions if any of these vars are undef
method cell-string {
#    $!print-string //= "{cursor_to($!x,$!y)}{$!char}";
    $!print-string ||= "{move-cursor($!x,$!y)}{$!char}";
}

method clear-cell-string {
    $!char = ' ';
    $!print-string = '';  # regen on next print
}

method blank-cell {
    self.clear-cell-string;
    print "{move-cursor($!x,$!y)}{$!char}";
}

method print-cell {
#    $!print-string ||= "{move-cursor($!x,$!y)}{$!char}";
    print "{move-cursor($!x,$!y)}{$!char}";
#    $!print-string //= "{cursor_to($!x,$!y)}{$!char}";
#    print $!print-string;
}

method Str {
    $!char;
}
