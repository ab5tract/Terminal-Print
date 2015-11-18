
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

#class Terminal::Print::Grid {

use Terminal::Print::Commands;

constant T = Terminal::Print::Commands;

has @.grid;
has $!grid-string;
has $!character-supply;
has $!control-supply;

has $.max-columns;
has $.max-rows;
has @.grid-indices;

has &.move-cursor-template;

has Terminal::Print::MoveCursorProfile $.move-cursor-profile;

submethod BUILD( :$!max-columns, :$!max-rows, :$!move-cursor-profile = 'ansi' ) {
    @!grid-indices = (^$!max-columns X ^$!max-rows)>>.Array;
    for @!grid-indices -> [$x,$y] {
        @!grid[$x;$y] = Str.new(:value(" "));
    }
    $!character-supply = Supply.new;
    $!control-supply = Supply.new;

    &!move-cursor-template = %T::human-commands<move-cursor>{ $!move-cursor-profile };
}

method initialize {
    state $initialized;

    unless $initialized {
        start {
            $initialized = True;
            react {
                whenever $!character-supply -> [$x,$y,$c] {
                    @!grid[$x;$y] = $c;
                }
                whenever $!control-supply -> $command {
                    given $command {
                        # I have a feeling this isn't actually doing what I think it's doing
                        # Probably need to rewrite this whole react block as a Promise
                        # and keep the vow here. Then we can just spin up a new Promise whenever
                        # initialize gets called again, or throw an exception if the current 'React Promise'
                        # is not yet kept.
                        when 'close' { done; }
                    }
                    $initialized = False;
                }
            }
        }
    }

    for ^$!max-columns -> $x {
        @!grid[$x] //= Terminal::Print::Grid::Column.new( :grid-object(self), :column($x), :$!max-rows );
    }
}

method shutdown {
    await start $!control-supply.emit('close');
}

method change-cell($x, $y, $c) {
    start {
        $!character-supply.emit([$x,$y,$c]);
        $!grid-string = '' if $!grid-string;
    }
}

multi method print-cell(Int $x, Int $y) {
    print "{&!move-cursor-template($x, $y)}{@!grid[$x;$y]}";
}

multi method print-cell(Int $x, Int $y, Str $char) {
    await self.change-cell($x, $y, $char).then({
        print "{&!move-cursor-template($x, $y)}{$char}";
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
#}
