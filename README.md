[![Build Status](https://travis-ci.org/ab5tract/Terminal-Print.svg?branch=master)](https://travis-ci.org/ab5tract/Terminal-Print)

class Terminal::Print::Grid
---------------------------

A rectangular grid containing Unicode characters and color/style information

class Terminal::Print::Grid::Cell
---------------------------------

Internal (immutable) class holding all position-independent information about a single grid cell

### method new

```perl6
method new(
    $w,
    $h,
    :$move-cursor = { ... }
) returns Mu
```

Instantiate a new (row-major) grid of size $w x $h

### method clear

```perl6
method clear() returns Mu
```

Clear the grid to blanks (ASCII spaces) with no color/style overrides

### method indices

```perl6
method indices() returns Mu
```

Lazily computed array of every [x, y] coordinate pair in the grid

### method cell-string

```perl6
method cell-string(
    $x,
    $y
) returns Mu
```

Return the escape string necessary to move to, color, and output a single cell

### method span-string

```perl6
method span-string(
    $x1,
    $x2,
    $y
) returns Mu
```

Return the escape string necessary to move to (x1, y) and output every cell (with color) on that row from x1..x2

### method set-span

```perl6
method set-span(
    $x,
    $y,
    Str $text,
    $color
) returns Mu
```

Set both the text and color of a span

### method set-span-text

```perl6
method set-span-text(
    $x,
    $y,
    Str $text
) returns Mu
```

Set the text of a span, but keep the color unchanged

### method set-span-color

```perl6
method set-span-color(
    $x1,
    $x2,
    $y,
    $color
) returns Mu
```

Set the color of a span, but keep the text unchanged

### method clip-rect

```perl6
method clip-rect(
    $x is copy,
    $y is copy,
    $w is copy,
    $h is copy
) returns Mu
```

Clip a rectangle to entirely fit within this grid

### method copy-from

```perl6
method copy-from(
    Terminal::Print::Grid $grid,
    $x,
    $y
) returns Mu
```

Copy an entire other grid into this grid with upper left at ($x, $y), clipping the copy to this grid's edges

### method print-from

```perl6
method print-from(
    Terminal::Print::Grid $grid,
    $x,
    $y
) returns Mu
```

Copy another grid into this one as with .copy-from and print the modified area

### multi method cell

```perl6
multi method cell(
    %c
) returns Mu
```

Return a position-independent immutable object representing the data for a single colored/styled grid cell, given a hash with char and color keys

### multi method cell

```perl6
multi method cell(
    Str $char,
    $color
) returns Mu
```

Return a position-independent immutable object representing the data for a single colored/styled grid cell, given char and color

### multi method cell

```perl6
multi method cell(
    Str $char
) returns Mu
```

Return a position-independent immutable object representing the data for a single uncolored/unstyled character in a grid cell

### multi method change-cell

```perl6
multi method change-cell(
    $x,
    $y,
    %c
) returns Mu
```

Replace the contents of a single grid cell, specifying a hash with char and color keys

### multi method change-cell

```perl6
multi method change-cell(
    $x,
    $y,
    Str $char
) returns Mu
```

Replace the contents of a single grid cell with a single uncolored/unstyled character

### multi method change-cell

```perl6
multi method change-cell(
    $x,
    $y,
    Terminal::Print::Grid::Cell $cell
) returns Mu
```

Replace the contents of a single grid cell with a prebuilt Cell object

### multi method print-cell

```perl6
multi method print-cell(
    $x,
    $y
) returns Mu
```

Print the .cell-string for a single cell

### multi method print-cell

```perl6
multi method print-cell(
    $x,
    $y,
    Str $char
) returns Mu
```

Replace the contents of a cell with an uncolored/unstyled character, then print its .cell-string

### multi method print-cell

```perl6
multi method print-cell(
    $x,
    $y,
    %c
) returns Mu
```

Replace the contents of a cell, specifying a hash with char and color keys, then print its .cell-string

### multi method print-string

```perl6
multi method print-string(
    $x,
    $y
) returns Mu
```

Degenerate case: print an individual cell

### multi method print-string

```perl6
multi method print-string(
    $x,
    $y,
    $string
) returns Mu
```

Print a (possibly ragged multi-line) string with first character at (x, y), incrementing y for each additional line

### multi method print-string

```perl6
multi method print-string(
    $x,
    $y,
    $string,
    $color
) returns Mu
```

Print a (possibly ragged multi-line) string with first character at (x, y), and in a given color

### method disable

```perl6
method disable() returns Mu
```

Don't actually print in .print-* methods

### method Str

```perl6
method Str() returns Mu
```

Lazily computed stringification of entire grid, including color escapes and cursor movement

