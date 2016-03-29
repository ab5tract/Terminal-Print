unit class Terminal::Print::Grid;

class Terminal::Print::Grid::Column {
    has $!column;
    has $!max-rows;
    has $!grid-object;

    submethod BUILD( :$!column, :$!max-rows, :$grid-object ) {
        $!grid-object := $grid-object;
    }

    method AT-POS($i) {
        $!grid-object[$!column;$i];
    }

    method ASSIGN-POS($i,$v) {
        await $!grid-object.change-cell($!column,$i,$v);
    }

}

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

submethod BUILD( :$!max-columns, :$!max-rows, :$!move-cursor-profile = 'ansi', :$frame-time ) {
    @!grid-indices = (^$!max-columns X ^$!max-rows)>>.Array;
    for @!grid-indices -> [$x,$y] {
        @!grid[$x;$y] = " ";
    }
    $!character-supplier = Supplier.new;
    $!control-supplier = Supplier.new;
    $!character-supply = $!character-supplier.Supply;
    $!control-supply = $!control-supplier.Supply;

    &!move-cursor-template = %T::human-commands<move-cursor>{ $!move-cursor-profile };

    $!frame-time = $frame-time // 0.05;
}

method initialize {
    state $initialized;

    unless $initialized {
        start {
            $initialized = True;
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
                            $frame-string ~= self.cell-string(|@args);
                        }
                        when 'close' { $initialized = False; done; }
                    }
                }
                whenever Supply.interval($!frame-time) {
                   if $frame-string {
                       print $frame-string;
                       $frame-string = '';
                   }
                }
            }
        }
    }

    # this is deferred until after the full construction of the grid object
    # so that we can pass it properly into the column constructor.
    for ^$!max-columns -> $x {
        @!grid[$x] //= Terminal::Print::Grid::Column.new( :grid-object(self), :column($x), :$!max-rows );
    }
}

method shutdown {
    await start $!control-supplier.emit(['close']);
}

method change-cell($x, $y, $c) {
    start {
        $!character-supplier.emit([$x,$y,$c]);
    }
}

method cell-string(Int $x, Int $y) {
    "{&!move-cursor-template($x, $y)}{@!grid[$x;$y]}";
}

multi method print-cell(Int $x, Int $y) {
    $!control-supplier.emit(['print', [$x, $y]]);
}

multi method print-cell(Int $x, Int $y, Str $char) {
    await self.change-cell($x, $y, $char).then({
        $!control-supplier.emit(['print', [$x, $y]]);
    });
}

method print-grid {
    print &!move-cursor-template(0, 0) ~ self;
}

method Str {
    unless $!grid-string {
        for ^$!max-rows -> $y {
            $!grid-string ~= [~] ~@!grid[$_;$y] for ^$!max-columns;
        }
    }
    $!grid-string;
}

multi method AT-POS($x) {
    @!grid[$x];
}

multi method AT-POS($x,$y) {
    @!grid[$x;$y];
}

multi method EXISTS-POS($x) {
    @!grid[$x]:exists;
}

multi method EXISTS-POS($x,$y) {
    @!grid[$x;$y]:exists;
}
