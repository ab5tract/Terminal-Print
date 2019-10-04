use Terminal::Print::Widget;
use Terminal::Print::Animated;

unit package Terminal::Print;

#| Widget maintains a (color only) pixel field with double Y resolution
role Pixelated {
    my %cell-cache;

    #| Composite pixels into grid cells by using unicode half-height blocks
    method composite-pixels(@pixels, :$skip-empty) {
        my $grid = $.grid.grid;
        for ^$.h -> int $y {
            my $row1 = @pixels[$y * 2]     // [];
            my $row2 = @pixels[$y * 2 + 1] // [];
            next if $skip-empty && !$row1.elems && !$row2.elems;

            my $grid-row = $grid[$y];
            for ^$.w -> int $x {
                my $c1 = $row1[$x] // '';
                my $c2 = $row2[$x] // '';
                next if $skip-empty && !$c1 && !$c2;

                # Manually inlined for performance
                $grid-row[$x] = %cell-cache{$c1}{$c2} //=
                       $c1 && $c2
                    && $c1 eq $c2 ?? $.grid.cell(' ', "on_$c1"    ) !!
                       $c1 && $c2 ?? $.grid.cell('▄', "$c2 on_$c1") !!
                       $c1        ?? $.grid.cell('▀',  $c1        ) !!
                       $c2        ?? $.grid.cell('▄',  $c2        ) !! ' ';
            }
        }
        # Force invalidation of $.grid.Str cache
        $.grid.change-cell(0, 0, $grid[0][0]);
    }

    #| Convert top and bottom pixel colors into a grid cell object using unicode half-height blocks
    method cell-from-pixel-pair($c1, $c2) {
        %cell-cache{$c1}{$c2} //=
               $c1 && $c2
            && $c1 eq $c2 ?? $.grid.cell(' ', "on_$c1"    ) !!
               $c1 && $c2 ?? $.grid.cell('▄', "$c2 on_$c1") !!
               $c1        ?? $.grid.cell('▀',  $c1        ) !!
               $c2        ?? $.grid.cell('▄',  $c2        ) !! ' '
    }
}


#| A pixel-driven animated widget
class PixelAnimation
      is   Terminal::Print::Widget
      does Terminal::Print::Animated
      does Pixelated
{
    #| Default behavior is to simply composite the computed pixels each frame
    method draw-frame() {
        self.composite-pixels(self.compute-pixels);
    }
}
