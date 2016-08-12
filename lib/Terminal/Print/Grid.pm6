use v6;

use OO::Monitors;

monitor Terminal::Print::Grid {


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


submethod BUILD {
    
    $!character-supplier = Supplier.new;
    $!control-supplier = Supplier.new;
    $!character-supply = $!character-supplier.Supply;
    $!control-supply = $!control-supplier.Supply;



    $!frame-time = $frame-time // 0.05;
}

# method initialize {
#     my $p = Promise.new;
#     start {
#         my Str $frame-string;
#         react {
#             whenever $!character-supply -> [$x,$y,$c] {
#                 @!grid[$x;$y] = $c;
#                 $!grid-string = '' if $!grid-string;
#             }
#             whenever $!control-supply -> [$command, @args] {
#                 given $command {
#                     when 'print' {
#                         # print self.cell-string(|@args);
#                         #
#                         # In this case, @args ~~ [x, y]
#                         $frame-string ~= self.cell-string(|@args);
#                     }
#                     when 'close' { done }
#                 }
#             }
#             whenever Supply.interval($!frame-time) {
#                if $frame-string {
#                    print $frame-string;
#                    $frame-string = '';
#                }
#             }
#             default { $p.keep }
#         }
#     }
#
#     # this is deferred until after the full construction of the grid object
#     # so that we can pass it properly into the column constructor.
#     # for ^$!max-columns -> $x {
#     #     @!grid[$x] //= Terminal::Print::Grid::Column.new( :grid-object(self), :column($x), :$!max-rows );
#     # }
#
#     $p
# }

# method shutdown {
#     await start $!control-supplier.emit(['close']);
# }

method change-cell(Valid::X $x, Valid::Y $y, Valid::Char $c) {
    # start {
    #     $!character-supplier.emit([$x,$y,$c]);
    # }
    @!grid[$x][$y] = $c;
}

method cell-string(Valid::X $x, Valid::Y $y) {
    "{&!move-cursor-template($x, $y)}{@!grid[$x][$y]}";
}

method print-cell(Valid::X $x, Valid::Y $y) {
    if $x >= $!max-columns or $y >= $!max-rows {
        warn "You have provided an out of bounds value -- x: $x\ty: $y";
    } else {
        # $!control-supplier.emit(['print', [$x, $y]]);
        print self.cell-string($x, $y);
    }
}

method print-grid {
    print &!move-cursor-template(0, 0) ~ self;
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

multi method AT-POS(Valid::X $x, Valid::Y $y) {
    @!grid[$x][$y];
}

multi method EXISTS-POS($x) {
    @!grid[$x]:exists;
}

multi method EXISTS-POS($x,$y) {
    @!grid[$x][$y]:exists;
}

}
