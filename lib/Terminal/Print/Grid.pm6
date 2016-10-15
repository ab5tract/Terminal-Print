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
has @.indices;
has @.grid;
has $.grid-string = '';
has $.move-cursor;
has $!print-enabled = True;

method new($columns, $rows, :$move-cursor) {
    my @indices = (^$columns X ^$rows)>>.Array;
    my @grid;
    for @indices -> [$x, $y] {
        @grid[$x][$y] = " ";
    }
    $move-cursor //= move-cursor-template;

    self.bless(:$columns, :$rows, :@grid, :@indices, :$move-cursor);
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
    return unless $!print-enabled;
    print self.cell-string($x, $y);
}

multi method print-cell($x, $y, Str $char) {
    return unless $!print-enabled;
    my $cell = Cell.new(:$char);
    self.change-cell($x, $y, $cell);
    print self.cell-string($x, $y);
}

multi method print-cell($x, $y, %c) {
    return unless $!print-enabled;
    my $cell = Cell.new(|%c);
    self.change-cell($x, $y, $cell);
    print self.cell-string($x, $y);
}

multi method print-string($x, $y) {
    return unless $!print-enabled;
    self.print-cell($x, $y);
}

multi method print-string($x, $y, Str() $string) {
    return unless $!print-enabled;
    my ($off-x, $off-y) = 0 xx 2;
    if +$string.comb == 1 {
        self.print-cell($x, $y, $string);
    } else {
        for $string.lines -> $line {
            my @chars = $line.comb;
            for @chars -> $c {
                self.print-cell($x + $off-x, $y + $off-y, $c);
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
    unless $!grid-string {
        for @!indices -> [$x, $y] {
            $!grid-string ~= self.cell-string($x, $y);
        }
    }
    $!grid-string
}
