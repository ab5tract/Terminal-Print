#
# LOOKUP TABLES
#

#| Unicode horizontal lines in different patterns, with ASCII fallback
my %hline = ascii  => '-', double => '═',
            light1 => '─', light2 => '╌', light3 => '┄', light4 => '┈',
            heavy1 => '━', heavy2 => '╍', heavy3 => '┅', heavy4 => '┉';

#| Unicode vertical lines in different patterns, with ASCII fallback
my %vline = ascii  => '|', double => '║',
            light1 => '│', light2 => '╎', light3 => '┆', light4 => '┊',
            heavy1 => '┃', heavy2 => '╏', heavy3 => '┇', heavy4 => '┋';

#| Overall weight for each line pattern, with ASCII fallback
my %weight = ascii  => 'ascii', double => 'double',
             light1 => 'light', light2 => 'light',
             light3 => 'light', light4 => 'light',
             heavy1 => 'heavy', heavy2 => 'heavy',
             heavy3 => 'heavy', heavy4 => 'heavy';

#| Box corner characters for each line weight (+ round), with ASCII fallback
my %corners = ascii  => < + + + + >,
              double => < ╔ ╗ ╚ ╝ >,
              light  => < ┌ ┐ └ ┘ >,
              heavy  => < ┏ ┓ ┗ ┛ >,
              round  => < ╭ ╮ ╰ ╯ >;


#| Enhance a T::P::Widget to draw boxes and horizontal / vertical lines
role Terminal::Print::BoxDrawing {
    has $.default-box-style = 'double';  #= Line type chosen from %hline and %vline

    #| Draw a horizontal line in a chosen color
    multi method draw-hline($x1, $x2, $y, :$color!, :$style where %hline = $.default-box-style) {
        $.grid.set-span($x1, $y, %hline{$style} x ($x2 - $x1 + 1), $color);
    }

    #| Draw a horizontal line without altering color
    multi method draw-hline($x1, $x2, $y, :$style where %hline = $.default-box-style) {
        $.grid.set-span-text($x1, $y, %hline{$style} x ($x2 - $x1 + 1));
    }

    #| Draw a vertical line in a chosen color
    multi method draw-vline($x, $y1, $y2, :$color!, :$style where %vline = $.default-box-style) {
        $.grid.set-span($x, $_, %vline{$style}, $color) for $y1..$y2;
    }

    #| Draw a vertical line without altering color
    multi method draw-vline($x, $y1, $y2, :$style where %vline = $.default-box-style) {
        $.grid.set-span-text($x, $_, %vline{$style}) for $y1..$y2;
    }

    #| Draw a box in a chosen color
    multi method draw-box($x1, $y1, $x2, $y2, :$color!, :$style where %hline = $.default-box-style) {
        # Draw sides in order: left, right, top, bottom
        self.draw-vline($x1, $y1 + 1, $y2 - 1, :$color, :$style);
        self.draw-vline($x2, $y1 + 1, $y2 - 1, :$color, :$style);
        self.draw-hline($x1 + 1, $x2 - 1, $y1, :$color, :$style);
        self.draw-hline($x1 + 1, $x2 - 1, $y2, :$color, :$style);

        # Draw corners
        my @corners = |%corners{%weight{$style}};
        $.grid.set-span($x1, $y1, @corners[0], $color);
        $.grid.set-span($x2, $y1, @corners[1], $color);
        $.grid.set-span($x1, $y2, @corners[2], $color);
        $.grid.set-span($x2, $y2, @corners[3], $color);
    }

    #| Draw a box without altering color
    multi method draw-box($x1, $y1, $x2, $y2, :$style where %hline = $.default-box-style) {
        # Draw sides in order: left, right, top, bottom
        self.draw-vline($x1, $y1 + 1, $y2 - 1, :$style);
        self.draw-vline($x2, $y1 + 1, $y2 - 1, :$style);
        self.draw-hline($x1 + 1, $x2 - 1, $y1, :$style);
        self.draw-hline($x1 + 1, $x2 - 1, $y2, :$style);

        # Draw corners
        my @corners = |%corners{%weight{$style}};
        $.grid.set-span-text($x1, $y1, @corners[0]);
        $.grid.set-span-text($x2, $y1, @corners[1]);
        $.grid.set-span-text($x1, $y2, @corners[2]);
        $.grid.set-span-text($x2, $y2, @corners[3]);
    }
}
