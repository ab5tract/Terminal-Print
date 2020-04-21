use Test;

use Terminal::Print::Widget;
use Terminal::Print::BoxDrawing;
use Terminal::ANSIColor;

class A is Terminal::Print::Widget does Terminal::Print::BoxDrawing {
    method TWEAK { self.grid.disable }

    method border-check($expected, :$color, :$style) {
        self.draw-box(
            0, 0, self.w - 1, self.h - 1,
            |( :$color if $color ),
            |( :$style if $style )
        );

        my $cells = self.grid.grid.join;
        is $cells.&colorstrip, $expected,
            ( $style || 'default' ) ~ ( $color ?? ' with color' !! '' );

        return unless $color;

        is $cells.&uncolor,
            ( "$color reset" xx self.w * self.h - 1 ).join(' '),
            $color;
    }
}

my $widget = A.new(x => 0, y => 0, h => 3, w => 3);

for %(
     default => '╔ ═ ╗║   ║╚ ═ ╝',
     ascii   => '+ - +|   |+ - +',
     light1  => '┌ ─ ┐│   │└ ─ ┘',
     light2  => '┌ ╌ ┐╎   ╎└ ╌ ┘',
     light3  => '┌ ┄ ┐┆   ┆└ ┄ ┘',
     light4  => '┌ ┈ ┐┊   ┊└ ┈ ┘',
     heavy1  => '┏ ━ ┓┃   ┃┗ ━ ┛',
     heavy2  => '┏ ╍ ┓╏   ╏┗ ╍ ┛',
     heavy3  => '┏ ┅ ┓┇   ┇┗ ┅ ┛',
     heavy4  => '┏ ┉ ┓┋   ┋┗ ┉ ┛',
     double  => '╔ ═ ╗║   ║╚ ═ ╝',
).kv -> $style, $expected {
    $widget.border-check(
        $expected,
        |( :$style unless $style eq 'default' )
    );

    $widget.border-check(
        $expected,
        |( :$style unless $style eq 'default' ),
        color => 'red',
    );
}

dies-ok { $widget.draw-box( 0, 0, 2, 2, style => 'missing' ) },
    'Validates style names without color';

dies-ok { $widget.draw-box( 0, 0, 2, 2, color => 'red', style => 'missing' ) },
    'Validates style names with color';


done-testing;
