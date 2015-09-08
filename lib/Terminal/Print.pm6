unit class Terminal::Print;

use Terminal::Print::Commands;
my constant T = Terminal::Print::Commands;

use Terminal::Print::Element::Grid;

has $!current-buffer;
has Terminal::Print::Element::Grid $!current-grid;

has @!buffers;
has Terminal::Print::Element::Grid @.grids;


has @.grid-indices;
has %!grid-name-map;

has $.max-columns;
has $.max-rows;

method new {
    my $max-columns   = +%T::attribute-values<columns>;
    my $max-rows      = +%T::attribute-values<rows>;

    my $grid = Terminal::Print::Element::Grid.new( :$max-columns, :$max-rows );
    my @grid-indices = $grid.grid-indices;

    self!bind-buffer( $grid, my $buffer = [] );

    self.bless(
                :$max-columns, :$max-rows, :@grid-indices,
                    current-grid    => $grid,
                    current-buffer  => $buffer
              );
}

submethod BUILD( :$current-grid, :$current-buffer, :$!max-columns, :$!max-rows, :@grid-indices ) {
    push @!buffers, $current-buffer;
    push @!grids, $current-grid;

    $!current-grid   := @!grids[0];
    $!current-buffer := @!buffers[0];

    @!grid-indices = @grid-indices;  # TODO: bind this to @!grids[0].grid-indices?
}

method !bind-buffer( $grid, $new-buffer is rw ) {
    for $grid.grid-indices -> [$x,$y] {
        $new-buffer[$x + ($y * $grid.max-rows)] := $grid[$x][$y];
    }
}


method add-grid( $name?, :$new-grid = Terminal::Print::Element::Grid.new( :$!max-columns, :$!max-rows ) ) {
    self!bind-buffer( $new-grid, my $new-buffer = [] );

    push @!grids, $new-grid;
    push @!buffers, $new-buffer;

    if $name {
        %!grid-name-map{$name} = +@!grids-1;
    }
}

method blit( $grid-identifier = 0 ) {
    self.clear-screen;
    self.print-grid($grid-identifier);
}

# 'clear' will also work through the FALLBACK
method clear-screen {
    print %T::human-commands<clear>;
}

method initialize-screen {
    print %T::human-commands<save-screen>;
    self.hide-cursor;
    self.clear-screen;
}

method shutdown-screen {
    self.clear-screen;
    print %T::human-commands<restore-screen>;
    self.show-cursor;
}

# AT-POS hands back a Terminal::Print::Column
#   $b[$x]
# Because we have AT-POS on the column object as well,
# we get
#   $b[$x][$y]
#
# TODO: implement $!current-grid switching
method AT-POS( $column-idx ) {
    $!current-grid.grid[ $column-idx ];
}

# AT-KEY returns the Terminal::Print::Element::Grid.grid of whichever the key specifies
#   $b<specific-grid>[$x][$y]
method AT-KEY( $grid-identifier ) {
    self.grid( $grid-identifier );
}

method postcircumfix:<( )> (*@t) {
    die "Can only specify x, y, and char" if @t > 3;
    my ($x,$y,$char) = @t;
    given +@t {
        when 3 { $!current-grid[$x][$y] = $char; $!current-grid[$x][$y].print-cell }
        when 2 { $!current-grid[$x][$y].print-cell }
        when 1 { $!current-grid[$x] }
    }
}

multi method FALLBACK( Str $command-name ) {
    die "Do not know command $command-name" unless %T::human-command-names{$command-name};
    print %T::human-commands{$command-name};
}



# multi method sugar:
#    @!grids and @!buffers can both be accessed by index or name (if it has
#    one). The name is optionally supplied when calling .add-grid.
#
#    In the case of @!grids, we pass back the grid array directly from the
#    Terminal::Print::Element::Grid object, actually notching both DWIM and DRY in one swoosh.
#    because you can do things like  $b.grid("background")[42][42] this way.
multi method grid( Int $index ) {
    @!grids[$index].grid;
}

multi method grid( Str $name ) {
    die "No grid has been named $name" unless my $grid-index = %!grid-name-map{$name};
    @!grids[$grid-index].grid;
}

#### grid-object stuff

#   Sometimes you simply want the object back (for stringification, or
#   introspection on things like column-range)
multi method grid-object( Int $index ) {
    @!grids[$index];
}

multi method grid-object( Str $name ) {
    die "No grid has been named $name" unless my $grid-index = %!grid-name-map{$name};
    @!grids[$grid-index];
} 


#### buffer stuff

multi method buffer( Int $index ) {
    @!buffers[$index];
}

multi method buffer( Str $name ) {
    die "No buffer has been named $name" unless my $buffer-index = %!grid-name-map{$name};
    @!buffers[$buffer-index];
}

#### print-grid stuff

multi method print-grid( Int $index ) {
    @!grids[$index].print-grid;
}

multi method print-grid( Str $name ) {
    die "No grid has been named $name" unless my $grid-index = %!grid-name-map{$name};
    @!grids[$grid-index].print-grid;
}

method !clone-grid-index( $origin, $dest? ) {
    if $dest {
        self.add-grid($dest, new-grid => @!grids[$origin].clone);
    } else {
        @!grids.push: @!grids[$origin].clone;
    }
    return @!grids[*-1];
}

#### clone-grid stuff

multi method clone-grid( Int $origin, Str $dest? ) {
    die "Invalid grid '$origin'" unless @!grids[$origin]:exists;
    self!clone-grid-index($origin, $dest);
}

multi method clone-grid( Str $origin, Str $dest? ) {
    die "Invalid grid '$origin'" unless my $grid-index = %!grid-name-map{$origin};
    self!clone-grid-index($grid-index, $dest);
}

#### range stuffs
#
# TODO: add hooks to dynamically bind $!current-grid to @!grids

method column-range {
    $!current-grid.column-range; # TODO: we can make the grids reflect specific subsets of these ranges
}

method row-range {
    $!current-grid.row-range;
}
