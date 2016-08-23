use OO::Monitors;
use Terminal::Print::Commands;

unit monitor Terminal::Print::Grid;

class Cell {
    use Terminal::ANSIColor; # lexical imports FTW
    has $.char;
    has $.color;
    has $!valid-color;

    method Str {
        if $!color {
            if $!valid-color {
                return colored($!char, $!color);
            } else {
                if colorvalid($!color) {
                    $!valid-color = True;
                    return colored($!char, $!color);
                } else {
                    die "Invalid color: $!color";
                }
            }
        } else {
            return $!char;
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

method change-cell($x, $y, $c) {
    $!grid-string = '';
    @!grid[$x][$y] = $c
}

multi method print-cell($x, $y) {
    print self.cell-string($x, $y);
}

multi method print-cell($x, $y, Str $c) {
    self.change-cell($x, $y, $c);
    print self.cell-string($x, $y);
}

multi method print-cell($x, $y, %c) {
    my $c = Cell.new(|%c);
    self.change-cell($x, $y, $c);
    print self.cell-string($x, $y);
}

method Str {
    unless $!grid-string {
        for @!grid-indices -> [$x, $y] {
            # die "$x, $y" if @!grid[$x][$y] eq ' ';
            $!grid-string ~= self.cell-string($x, $y);
        }
    }
    $!grid-string
}
