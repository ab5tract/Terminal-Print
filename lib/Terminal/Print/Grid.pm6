use OO::Monitors;
use Terminal::Print::Commands;

unit monitor Terminal::Print::Grid;

my class Cell {
    use Terminal::ANSIColor; # lexical imports FTW
    has $.char is required;
    has $.color;
    has $!string;

    method Str {
        return $!string //= do {
            $!color ?? colored($!char, $!color)
                    !! $!char
        }
    }
}

has $.rows;
has $.columns;
has @.grid-indices;
has @.grid;
has $.grid-string = '';

has $.move-cursor;

method new($columns, $rows, :$move-cursor) {
    my @grid-indices = (^$columns X ^$rows)>>.Array;
    my @grid;
    for @grid-indices -> [$x, $y] {
        @grid[$x] //= [];
        @grid[$x][$y] = " ";
    }
    $move-cursor //= move-cursor-template;

    self.bless(:$columns, :$rows, :@grid, :@grid-indices, :$move-cursor);
}

method cell-string($x, $y) {
    "{$!move-cursor($x, $y)}{~@!grid[$x][$y]}"
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
    print self.cell-string($x, $y);
}

multi method print-cell($x, $y, Str $char) {
    my $cell = Cell.new(:$char);
    self.change-cell($x, $y, $cell);
    print self.cell-string($x, $y);
}

multi method print-cell($x, $y, %c) {
    my $cell = Cell.new(|%c);
    self.change-cell($x, $y, $cell);
    print self.cell-string($x, $y);
}

method Str {
    unless $!grid-string {
        for @!grid-indices -> [$x, $y] {
            $!grid-string ~= self.cell-string($x, $y);
        }
    }
    $!grid-string
}
