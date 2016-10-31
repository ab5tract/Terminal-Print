use OO::Monitors;

use Terminal::Print::Commands;

unit monitor Terminal::Print::Grid;

my class Cell {
    use Terminal::ANSIColor; # lexical imports FTW
    has $.char is required;
    has $.color;
    has $!string;

    method Str {
        $!string //= $!color ?? colored($!char, $!color) !! $!char
    }
}

has $.rows;
has $.columns;
has @!indices;
has @.grid;
has $.grid-string = '';
has $.move-cursor;
has $!print-enabled = True;

method new($columns, $rows, :$move-cursor = move-cursor-template) {
    my @grid = [ [ ' ' xx $rows ] xx $columns ];

    self.bless(:$columns, :$rows, :@grid, :$move-cursor);
}

method indices() {
    @!indices ||= (^$.columns X ^$.rows)>>.Array;
}

method cell-string($x, $y) {
    "{$!move-cursor($x, $y)}{~@!grid[$x][$y]}"
}

method span-string($x1, $x2, $y) {
    $!move-cursor($x1, $y) ~ ($x1..$x2).map(-> $x { @!grid[$x][$y] }).join
}

#| Set both the text and color of a span
method set-span($x, $y, Str $text, $color) {
    $!grid-string = '';
    for $text.comb.kv -> $i, $char {
        @!grid[$x + $i][$y] = Cell.new(:$char, :$color);
    }
}

#| Set the text of a span, but keep the color unchanged
method set-span-text($x, $y, Str $text) {
    $!grid-string = '';
    for $text.comb.kv -> $i, $char {
        given @!grid[$x + $i][$y] {
            when Cell { @!grid[$x + $i][$y] = Cell.new(:$char, :color(.color)) }
            default   { @!grid[$x + $i][$y] = Cell.new(:$char) }
        }
    }
}

#| Set the color of a span, but keep the text unchanged
method set-span-color($x1, $x2, $y, $color) {
    $!grid-string = '';
    for $x1..$x2 -> $x {
        given @!grid[$x][$y] {
            when Cell { @!grid[$x][$y] = Cell.new(:char(.char),     :$color) }
            default   { @!grid[$x][$y] = Cell.new(:char($_ // ' '), :$color) }
        }
    }
}

multi method change-cell($x, $y, %c) {
    $!grid-string = '';
    @!grid[$x][$y] = Cell.new(|%c)
}

multi method change-cell($x, $y, Str $char) {
    $!grid-string = '';
    @!grid[$x][$y] = Cell.new(:$char)
}

multi method change-cell($x, $y, Cell $cell) {
    $!grid-string = '';
    @!grid[$x][$y] = $cell
}

multi method print-cell($x, $y) {
    print self.cell-string($x, $y) if $!print-enabled;
}

multi method print-cell($x, $y, Str $char) {
    self.change-cell($x, $y, Cell.new(:$char));
    self.print-cell($x, $y);
}

multi method print-cell($x, $y, %c) {
    self.change-cell($x, $y, Cell.new(|%c));
    self.print-cell($x, $y);
}

multi method print-string($x, $y) {
    self.print-cell($x, $y);
}

multi method print-string($x, $y, Str() $string, $color?) {
    if $string.chars == 1 {
        self.print-cell($x, $y, $string);
    } else {
        my ($off-x, $off-y) = 0, 0;
        for $string.lines -> $line {
            for $line.comb -> $char {
                $color ?? self.print-cell($x + $off-x, $y + $off-y, %( :$char, :$color ))
                       !! self.print-cell($x + $off-x, $y + $off-y, $char);
                $off-x++;
            }
            $off-y++;
            $off-x = 0;
        }
    }
}

method disable {
    $!print-enabled = False;
}

method Str {
    $!grid-string ||= join '', ^$!rows .map({ self.span-string(0, $!columns - 1, $_) });
}
