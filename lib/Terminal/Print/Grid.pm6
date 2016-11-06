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
    my @grid = [ [ ' ' xx $columns ] xx $rows ];

    self.bless(:$columns, :$rows, :@grid, :$move-cursor);
}

method indices() {
    @!indices ||= (^$.columns X ^$.rows)>>.Array;
}

method cell-string($x, $y) {
    "{$!move-cursor($x, $y)}{~@!grid[$y][$x]}"
}

method span-string($x1, $x2, $y) {
    my $row = @!grid[$y];
    $!move-cursor($x1, $y) ~ $row[$x1..$x2].join
}

#| Set both the text and color of a span
method set-span($x, $y, Str $text, $color) {
    $!grid-string = '';
    my $row = @!grid[$y];
    for $text.comb.kv -> $i, $char {
        $row[$x + $i] = Cell.new(:$char, :$color);
    }
}

#| Set the text of a span, but keep the color unchanged
method set-span-text($x, $y, Str $text) {
    $!grid-string = '';
    my $row = @!grid[$y];
    for $text.comb.kv -> $i, $char {
        given $row[$x + $i] {
            when Cell { $row[$x + $i] = Cell.new(:$char, :color(.color)) }
            default   { $row[$x + $i] = $char }
        }
    }
}

#| Set the color of a span, but keep the text unchanged
method set-span-color($x1, $x2, $y, $color) {
    $!grid-string = '';
    my $row = @!grid[$y];
    for $x1..$x2 -> $x {
        given $row[$x] {
            when Cell { $row[$x] = Cell.new(:char(.char),     :$color) }
            default   { $row[$x] = Cell.new(:char($_ // ' '), :$color) }
        }
    }
}

multi method change-cell($x, $y, %c) {
    $!grid-string = '';
    @!grid[$y][$x] = Cell.new(|%c);
}

multi method change-cell($x, $y, Str $char) {
    $!grid-string = '';
    @!grid[$y][$x] = $char;
}

multi method change-cell($x, $y, Cell $cell) {
    $!grid-string = '';
    @!grid[$y][$x] = $cell;
}

multi method print-cell($x, $y) {
    print self.cell-string($x, $y) if $!print-enabled;
}

multi method print-cell($x, $y, Str $char) {
    self.change-cell($x, $y, $char);
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
        my $off-y = 0;
        for $string.lines -> $line {
            self.set-span($x, $y + $off-y, $line, $color);
            print self.span-string($x, $x + $line.chars - 1, $y + $off-y);
            $off-y++;
        }
    }
}

method disable {
    $!print-enabled = False;
}

method Str {
    $!grid-string ||= join '', ^$!rows .map({ self.span-string(0, $!columns - 1, $_) });
}
