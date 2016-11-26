use OO::Monitors;

use Terminal::Print::Commands;

#| A rectangular grid containing Unicode characters and color/style information
unit monitor Terminal::Print::Grid;

#| Internal (immutable) class holding all position-independent information about a single grid cell
my class Cell {
    use Terminal::ANSIColor; # lexical imports FTW
    has $.char is required;
    has $.color;
    has $!string;

    my $reset = color('reset');
    my %cache = '' => '';

    submethod BUILD(:$!char, :$color) {
        $!color = $color // '';
        if $!color.contains(',') {
            $!string = colored($!char, $!color);
        }
        else {
            %cache{$!color} //= color($!color);
            $!string = $!color ?? "%cache{$!color}$!char$reset" !! $!char;
        }
    }

    method Str() { $!string }
}

has $.rows;
has $.columns;
has @!indices;
has @.grid;
has $.grid-string = '';
has $.move-cursor;
has $!print-enabled = True;

#| Instantiate a new (row-major) grid of size $columns x $rows
method new($columns, $rows, :$move-cursor = move-cursor-template) {
    my @grid = [ [ ' ' xx $columns ] xx $rows ];

    self.bless(:$columns, :$rows, :@grid, :$move-cursor);
}

#| Clear the grid to blanks (ASCII spaces) with no color/style overrides
method clear() {
    @!grid = [ [ ' ' xx $!columns ] xx $!rows ];
}

#| Lazily computed array of every [x, y] coordinate pair in the grid
method indices() {
    @!indices ||= (^$.columns X ^$.rows)>>.Array;
}

#| Return the escape string necessary to move to, color, and output a single cell
method cell-string($x, $y) {
    "{$!move-cursor($x, $y)}{~@!grid[$y][$x]}"
}

#| Return the escape string necessary to move to (x1, y) and output every cell (with color) on that row from x1..x2
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
        my $cell := $row[$x + $i];
        $cell = $cell ~~ Cell ?? Cell.new(:$char, :color($cell.color)) !! $char;
    }
}

#| Set the color of a span, but keep the text unchanged
method set-span-color($x1, $x2, $y, $color) {
    $!grid-string = '';
    my $row = @!grid[$y];
    for $x1..$x2 -> $x {
        my $cell := $row[$x];
        $cell = Cell.new(:char($cell ~~ Cell ?? $cell.char !! $cell // ' '), :$color);
    }
}

#| Clip a rectangle to entirely fit within this grid
method clip-rect($x is copy, $y is copy, $w is copy, $h is copy) {
    # If the upper-left corner is outside the grid, move it back on the grid
    # and shrink the rectangle size accordingly
    if $x < 0 { $w += $x; $x = 0 }
    if $y < 0 { $h += $y; $y = 0 }

    # If it's entirely outside the grid or the rectangle doesn't have positive
    # extent in both dimensions, clip to zero size
    if $x >= $!columns || $y >= $!rows || $w <= 0 || $h <= 0 {
        # Empty rect
        ($x, $y, 0, 0)
    }
    else {
        # Shrink the rectangle if it extends past the right or bottom edge
        $w = min $w, $!columns - $x;
        $h = min $h, $!rows    - $y;

        # Clipped but non-empty rect
        ($x, $y, $w, $h)
    }
}

#| Copy an entire other grid into this grid with upper left at ($x, $y), clipping the copy to this grid's edges
method copy-from(Terminal::Print::Grid $grid, $x, $y) {
    # Clip to edges of this grid
    my ($x1, $y1, $cols, $rows)
        = self.clip-rect($x, $y, $grid.columns, $grid.rows);

    # Actually do the copy (actually a splice because immutable Cells)
    $!grid-string = '';
    my $from =  $grid.grid;
    if $cols == $grid.columns {
        @!grid[$_ + $y1].splice($x1, $cols, $from[$_]) for ^$rows;
    }
    else {
        @!grid[$_ + $y1].splice($x1, $cols, $from[$_][^$cols]) for ^$rows;
    }

    # Return the clipped rectangle in case a caller (such as print-from)
    # needs the clipped size anyway
    ($x1, $y1, $cols, $rows)
}

#| Copy another grid into this one as with .copy-from and print the modified area
method print-from(Terminal::Print::Grid $grid, $x, $y) {
    # Copy grid, remembering clipped area
    my ($x1, $y1, $cols, $rows) = self.copy-from($grid, $x, $y);

    my $x2 = $x1 + $cols - 1;
    (^$rows).map({ self.span-string($x1, $x2, $_ + $y1) }).join.print
        if $!print-enabled;
}

#| Replace the contents of a single grid cell, specifying a hash with char and color keys
multi method change-cell($x, $y, %c) {
    $!grid-string = '';
    @!grid[$y][$x] = Cell.new(|%c);
}

#| Replace the contents of a single grid cell with a single uncolored/unstyled character
multi method change-cell($x, $y, Str $char) {
    $!grid-string = '';
    @!grid[$y][$x] = $char;
}

#| Replace the contents of a single grid cell with a prebuilt Cell object
multi method change-cell($x, $y, Cell $cell) {
    $!grid-string = '';
    @!grid[$y][$x] = $cell;
}

#| Print the .cell-string for a single cell
multi method print-cell($x, $y) {
    print self.cell-string($x, $y) if $!print-enabled;
}

#| Replace the contents of a cell with an uncolored/unstyled character, then print its .cell-string
multi method print-cell($x, $y, Str $char) {
    self.change-cell($x, $y, $char);
    self.print-cell($x, $y);
}

#| Replace the contents of a cell, specifying a hash with char and color keys, then print its .cell-string
multi method print-cell($x, $y, %c) {
    self.change-cell($x, $y, Cell.new(|%c));
    self.print-cell($x, $y);
}

#| Degenerate case: print an individual cell
multi method print-string($x, $y) {
    self.print-cell($x, $y);
}

#| Print a (possibly ragged multi-line) string with first character at (x, y), incrementing y for each additional line
multi method print-string($x, $y, Str() $string) {
    if $string.chars == 1 {
        self.print-cell($x, $y, $string);
    } else {
        my $off-y = 0;
        for $string.lines -> $line {
            self.set-span-text($x, $y + $off-y, $line);
            print self.span-string($x, $x + $line.chars - 1, $y + $off-y)
                if $!print-enabled;
            $off-y++;
        }
    }
}

#| Print a (possibly ragged multi-line) string with first character at (x, y), and in a given color
multi method print-string($x, $y, Str() $string, $color) {
    if $string.chars == 1 {
        self.print-cell($x, $y, %( :char($string), :$color ));
    } else {
        my $off-y = 0;
        for $string.lines -> $line {
            self.set-span($x, $y + $off-y, $line, $color);
            print self.span-string($x, $x + $line.chars - 1, $y + $off-y)
                if $!print-enabled;
            $off-y++;
        }
    }
}

#| Don't actually print in .print-* methods
method disable() {
    $!print-enabled = False;
}

#| Lazily computed stringification of entire grid, including color escapes and cursor movement
method Str() {
    $!grid-string ||= join '', ^$!rows .map({ self.span-string(0, $!columns - 1, $_) });
}
