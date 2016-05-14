unit class Terminal::Print::Grid;


#
# class Terminal::Print::Grid::Column {
#     has $!column;
#     has $!max-rows;
#     has $!grid-object;
#
#     submethod BUILD( :$!column, :$!max-rows, :$grid-object ) {
#         $!grid-object := $grid-object;
#     }
#
#     method AT-POS($i) {
#         $!grid-object[$!column][$i];
#     }
#
#     method ASSIGN-POS($i,$v) {
#         await $!grid-object.change-cell($!column,$i,$v);
#     }
# }

use Terminal::Print::Commands;

constant T = Terminal::Print::Commands;

has @.grid;
has $!grid-string;

has $!character-supplier;
has $!control-supplier;
has $!character-supply;
has $!control-supply;

has $.frame-time;

has $.max-columns;
has $.max-rows;
has @.grid-indices;

has &.move-cursor-template;

has Terminal::Print::MoveCursorProfile $.move-cursor-profile;
subset Valid::X of Int is export where * < %T::attributes<columns>;
subset Valid::Y of Int is export where * < %T::attributes<rows>;
subset Valid::Char of Str is export where *.chars == 1;

submethod BUILD( :$!max-columns, :$!max-rows, :$!move-cursor-profile = 'ansi', :$frame-time ) {
    @!grid-indices = (^$!max-columns X ^$!max-rows)>>.Array;
    for @!grid-indices -> [$x,$y] {
        @!grid[$x] //= [];
        @!grid[$x][$y] = " ";
    }
    $!character-supplier = Supplier.new;
    $!control-supplier = Supplier.new;
    $!character-supply = $!character-supplier.Supply;
    $!control-supply = $!control-supplier.Supply;

    &!move-cursor-template = %T::human-commands<move-cursor>{ $!move-cursor-profile };

    $!frame-time = $frame-time // 0.05;
}

method initialize {
    my $p = Promise.new;
    start {
        my Str $frame-string;
        react {
            whenever $!character-supply -> [$x,$y,$c] {
                @!grid[$x;$y] = $c;
                $!grid-string = '' if $!grid-string;
            }
            whenever $!control-supply -> [$command, @args] {
                given $command {
                    when 'print' {
                        # print self.cell-string(|@args);
                        #
                        # In this case, @args ~~ [x, y]
                        $frame-string ~= self.cell-string(|@args);
                    }
                    when 'close' { done }
                }
            }
            whenever Supply.interval($!frame-time) {
               if $frame-string {
                   print $frame-string;
                   $frame-string = '';
               }
            }
            default { $p.keep }
        }
    }

    # this is deferred until after the full construction of the grid object
    # so that we can pass it properly into the column constructor.
    # for ^$!max-columns -> $x {
    #     @!grid[$x] //= Terminal::Print::Grid::Column.new( :grid-object(self), :column($x), :$!max-rows );
    # }

    $p
}

method shutdown {
    await start $!control-supplier.emit(['close']);
}

multi method change-cell(Valid::X $x, Valid::Y $y, Valid::Char $c) {
    start {
        $!character-supplier.emit([$x,$y,$c]);
    }
}
multi method change-cell($x, $y, $c) {
    bad-input(:$x, :$y, :$c);
}

multi method cell-string(Valid::X $x, Valid::Y $y) {
    "{&!move-cursor-template($x, $y)}{@!grid[$x][$y]}";
}
multi method cell-string($x, $y) {
    bad-input(:$x, :$y);
}

multi method print-cell(Valid::X $x, Valid::Y $y) {
    if $x >= $!max-columns or $y >= $!max-rows {
        warn "You have provided an out of bounds value -- x: $x\ty: $y";
    } else {
        $!control-supplier.emit(['print', [$x, $y]]);
    }
}

multi method print-cell(Valid::X $x, Valid::Y $y, Valid::Char $c) {
    await self.change-cell($x, $y, $c).then({
        $!control-supplier.emit(['print', [$x, $y]]);
    });
}
multi method print-cell($x, $y, $c?) {
    bad-input(:$x, :$y, :$c);
}

method print-grid {
    print &!move-cursor-template(0, 0) ~ self;
}


sub bad-input(:$x, :$y, :$c) {
    my $warning;
    unless !$x || $x ~~ Valid::X {
        $warning ~= "Invalid x: $x\t";
    }
    unless !$y || $y ~~ Valid::Y {
        $warning ~= "Invalid y: $y\t";
    }
    unless !$c || $c ~~ Valid::Char {
        $warning ~= "Invalid character: $c";
    }
    warn $warning;
}

# Coercions
# TODO: Add a 'gist' ?

method Str {
    unless $!grid-string {
        for ^$!max-rows -> $y {
            $!grid-string ~= [~] ~@!grid[$_][$y] for ^$!max-columns;
        }
    }
    $!grid-string;
}


# The grid may be accessed as an array
# TODO: Harden these via promises

multi method AT-POS(Valid::X $x) {
    @!grid[$x];
}
multi method AT-POS($x) {
    bad-input(:$x);
}

multi method AT-POS(Valid::X $x, Valid::Y $y) {
    @!grid[$x][$y];
}
multi method AT-POS($x, $y) {
    bad-input(:$x, :$y);
}

multi method EXISTS-POS($x) {
    @!grid[$x]:exists;
}

multi method EXISTS-POS($x,$y) {
    @!grid[$x][$y]:exists;
}
