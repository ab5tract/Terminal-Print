use OO::Monitors;

use Terminal::Print::Commands;

#| A rectangular grid containing Unicode characters and color/style information
unit monitor Terminal::Print::Grid;

sub cell($new-char?, :%details) is export {
    use Terminal::ANSIColor;
    
    constant RESET-COLOR = color('reset');

    #XXX: is a state var in a lexical sub in an OO::Monitors a potential race condition?
    #       Also, should we check the size and clear it at some point?
    #       Maybe it should just be a lexically scoped class var?
    state %cache;
    
    my $char = $new-char ~~ Str     ?? ~$new-char
                                    !! %details<char> // ' ';

    # This should be considered the simplest case. If %details has a render sub, for instance,
    # we shouldn't cache. So for any other similar cases, we will have checked before we got here.
    my $color = %details<color> // '';
    my $key = $color ?? $char ~ $color
                     !! $char;
    return %cache{ $key } if %cache{ $key }:exists;

    my ($string);
    if $color {
        if $color.contains(',') {
            $string = %cache{ $key } = colored($char, $color);
        } else {
            my $cached-color = %cache{$color} //= color($color);
            $string = %cache{ $key } = "{ $cached-color }{ $char }{ RESET-COLOR }";
        }
    } else {
        $string = %cache{ $key } = $char;
    }

    return $string;
}

#| Internal (immutable) class holding all position-independent information about a single grid cell
#my class Cell {
#    has $.char is required;
#    has $.color;
#    has $!string;
#
#    my $reset = color('reset');
#    my %cache = '' => '';
#
#    submethod BUILD(:$!char, :$color) {
#        $!color = $color // '';
#        if $!color.contains(',') {
#            $!string = colored($!char, $!color);
#        }
#        else {
#            %cache{$!color} //= color($!color);
#            $!string = $!color ?? "%cache{$!color}$!char$reset" !! $!char;
#        }
#    }
#
#    method Str() { $!string }
#}

has $.w;
has $.h;
has @!indices;

#| self.grid contains all the strings, ready to print
has @.grid;
#| self.grid-details contains hashes with details such as color
has @.grid-details;

has $.grid-string = '';
has $.move-cursor;
has $!print-enabled = True;

# Compatibility accessors
method columns { $!w }
method width   { $!w }
method rows    { $!h }
method height  { $!h }

#| Instantiate a new (row-major) grid of size $w x $h
method new($w, $h, :$move-cursor = move-cursor-template) {
    my @grid = [ [ ' ' xx $w ] xx $h ];
    my @grid-details = [ [ Hash.new  xx $w ] xx $h ];

    self.bless(:$w, :$h, :@grid, :@grid-details, :$move-cursor);
}

#| Clear the grid to blanks (ASCII spaces) with no color/style overrides
method clear() {
    @!grid = [ [ ' ' xx $!w ] xx $!h ];
}

#| Lazily computed array of every [x, y] coordinate pair in the grid
method indices() {
    @!indices ||= (^$!w X ^$!h)>>.Array;
}

#| Return the escape string necessary to move to, color, and output a single cell
method cell-string($x, $y) {
    "{$!move-cursor($x, $y)}{~@!grid[$y][$x]}"
}

#| Return the escape string necessary to move to (x1, y) and output every cell (with color) on that row from x1..x2
method span-string($x1, $x2, $y) {
    my $row = @!grid[$y];
    $!move-cursor($x1, $y) ~ $row[$x1..$x2].join.subst("\e[0m\e[", "\e[0;", :g);
}

#| Set both the text and color of a span
method set-span($x, $y, Str $text, $color?) {
    $!grid-string = '';
    my $row = @!grid[$y];

    if $color {
        my @cells;
        for $text.comb -> $char {
            @cells.push: cell($char, :details(:$color));
            my $details := @!grid-details[$y][$x];
            #XXX: Right now we don't apply/utilize existing details.. but we could.
            #       We could even allow custom "render" subroutines that allow higher level sugar
            #       at minimal cost. That would happen in the cell sub itself, but here I'm
            #       just making note that we aren't using existing details in set-span.
            $details<color> = $color;
            $details<char>  = $char;
        }
        $row.splice($x, +@cells, @cells);
    }
    else {
        my @chars = $text.comb;
        $row.splice($x, +@chars, @chars);
    }
}

#| Set the text of a span, but keep the color unchanged
method set-span-text($x, $y, Str $text) {
    $!grid-string = '';
    my $row := @!grid[$y];
    my $details-row := @!grid-details[$y];
    for $text.comb.kv -> $i, $char {
        my $cell := $row[$x + $i];
        my $details := $details-row[$x + $i] //= Hash.new;

        $details<char> = $char;
        $cell = cell($char, :$details);
    }
}

#| Set the color of a span, but keep the text unchanged
method set-span-color($x1, $x2, $y, $color) {
    $!grid-string = '';
    my $row := @!grid[$y];
    my $details-row := @!grid-details[$y];
    for $x1..$x2 -> $x {
        my $cell := $row[$x];
        my $details := $details-row[$x];

        $details<color> = $color;
        $cell = cell(:$details);
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
    if $x >= $!w || $y >= $!h || $w <= 0 || $h <= 0 {
        # Empty rect
        ($x, $y, 0, 0)
    }
    else {
        # Shrink the rectangle if it extends past the right or bottom edge
        $w = min $w, $!w - $x;
        $h = min $h, $!h - $y;

        # Clipped but non-empty rect
        ($x, $y, $w, $h)
    }
}

#| Copy an entire other grid into this grid with upper left at ($x, $y), clipping the copy to this grid's edges
method copy-from(Terminal::Print::Grid $grid, $x, $y) {
    # Clip to edges of this grid
    my ($x1, $y1, $w, $h)
        = self.clip-rect($x, $y, $grid.w, $grid.h);


    # Actually do the copy (actually a splice because immutable Cells)
    $!grid-string = '';
    my $from = $grid.grid;
    if $w == $grid.w {
        @!grid[$_ + $y1].splice($x1, $w, $from[$_]) for ^$h;
        @!grid-details[$_ + $y1].splice($x1, $w, $from[$_]) for ^$h;
    }
    else {
        @!grid[$_ + $y1].splice($x1, $w, $from[$_][^$w]) for ^$h;
        @!grid-details[$_ + $y1].splice($x1, $w, $from[$_][^$w]) for ^$h;
    }

    # Return the clipped rectangle in case a caller (such as print-from)
    # needs the clipped size anyway
    ($x1, $y1, $w, $h)
}

#| Copy another grid into this one as with .copy-from and print the modified area
method print-from(Terminal::Print::Grid $grid, $x, $y) {
    # Copy grid, remembering clipped area
    my ($x1, $y1, $w, $h) = self.copy-from($grid, $x, $y);

    my $x2 = $x1 + $w - 1;
    (^$h).map({ self.span-string($x1, $x2, $_ + $y1) // '' }).join.print
        if $!print-enabled;
}

#| Replace the contents of a single grid cell, specifying a hash with char and color keys
multi method change-cell($x, $y, %c) {
    return unless 0 <= $x < $!w && 0 <= $y < $!h;
    $!grid-string = '';
    @!grid[$y][$x] = cell(details => %c);
    @!grid-details[$y][$x] = %c;
}

#| Replace the contents of a single grid cell with a single uncolored/unstyled character
multi method change-cell($x, $y, Str $char) {
    return unless 0 <= $x < $!w && 0 <= $y < $!h;
    $!grid-string = '';
    @!grid[$y][$x] = $char;
    #XXX: Can't use the existing details yet because it violates the documented API of 'uncolored, unstyled'
    #    my $details := @!grid-details[$y][$x];
    my $details := @!grid-details[$y][$x] = Hash.new;
    $details<char> = $char;
}

#| Print the .cell-string for a single cell
multi method print-cell($x, $y) {
    print self.cell-string($x, $y)
        if $!print-enabled
        && 0 <= $x < $!w
        && 0 <= $y < $!h;
}

#| Replace the contents of a cell with an uncolored/unstyled character, then print its .cell-string
multi method print-cell($x, $y, Str $char) {
    @!grid[$y][$x] = cell($char);
    @!grid-details[$y][$x]<char> = $char;
    self.print-cell($x, $y);
}

#| Replace the contents of a cell, specifying a hash with char and color keys, then print its .cell-string
multi method print-cell($x, $y, %c) {
    @!grid[$y][$x] = cell(details => %c);
    @!grid-details[$y][$x] = %c;
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
    $!grid-string ||= join '', ^$!h .map({ self.span-string(0, $!w - 1, $_) });
}
