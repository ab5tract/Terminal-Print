unit class Terminal::Print::Grid;

use Terminal::Print::Commands;

constant T = Terminal::Print::Commands;

has @.grid;
has $!character-supply;
has $!control-supply;

has $.max-columns;
has $.max-rows;
has @.grid-indices;

submethod BUILD( :$!max-columns, :$!max-rows ) {
    @!grid-indices = ^$!max-rows X ^$!max-columns;

    for ^$!max-columns -> $x {
        for ^$!max-rows -> $y {
            @!grid[$x;$y] = Str.new(:value(" "));
        }
    }

    $!character-supply = Supply.new;
    $!control-supply = Supply.new;
}

method initialize {
    start {
        react {
            whenever $!character-supply -> [$x,$y,$c] { 
                @!grid[$x;$y] = $c;
            }
            whenever $!control-supply -> $command {
                given $command {
                    when 'close' { say "This supply is done"; done; }
                }
            }
        }
    }
}

method shutdown {
    $!control-supply.emit('close');
}

method change-cell($x,$y,$c) {
    $!character-supply.emit([$x,$y,$c]);
}

method AT-POS($x,$y) {
    @!grid[$x;$y];
}

method EXISTS-POS($x,$y) {
    @!grid[$x;$y]:exists;
}

method BIND-POS($x,$y,$v) {
    @!grid[$x;$y] := $v;
}

method ASSIGN-POS($x,$y,$v) {
    #    my $v = @coords[*-1];
    say "v:$v,x:$x,y:$y";
    #    self.AT-POS(@coords) = $v;
    @!grid[$x;$y] = $v;
}

