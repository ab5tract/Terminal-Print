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

method span-string($y, $x1 = 0, $x2 = $!columns - 1) {
    $!move-cursor($x1, $y) ~ ($x1..$x2).map(-> $x { @!grid[$x][$y] }).join
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
    $!grid-string ||= join '', ^$!rows .map({ self.span-string($_) });
}
