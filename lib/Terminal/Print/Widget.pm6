use Terminal::Print::Grid;

#| A basic rectangular widget that can work in relative coordinates
class Terminal::Print::Widget {
    has Int $.x is required;  #= Location of widget's left edge on parent widget/grid
    has Int $.y is required;  #= Location of widget's top edge on parent widget/grid
    has Int $.w is required;  #= Width of widget in character cells
    has Int $.h is required;  #= Height of widget in character cells

    has $.parent;    #= Parent widget/grid onto which this widget will be composited
    has @.children;  #= Child widgets that will composite onto this one

    has $.grid = Terminal::Print::Grid.new($!w, $!h);  #= Widget's backing grid


    #| Make sure parent widget knows about this child
    submethod TWEAK() {
        $!parent.add-child(self) if $!parent ~~ Terminal::Print::Widget;
    }

    #| Move upper left corner to (x, y) on the parent widget/grid
    method move-to($!x, $!y) { }

    #| Add a child widget to this one
    method add-child(Terminal::Print::Widget $child) {
        @!children.push($child);
    }

    #| Return T::P::Grid object that this Widget will draw on
    method target-grid() {
        given $!parent {
            when Terminal::Print::Grid   { $_    }
            when Terminal::Print::Widget { .grid }
            default                      { $Terminal::Print::T.current-grid }
        }
    }

    #| Composite this widget onto a target grid, optionally printing to screen
    # For now, simply copies widget contents (effects such as alpha blend NYI).
    # Default behavior is to print iff the widget's parent is the screen grid.
    method composite(Terminal::Print::Grid :$to = self.target-grid,
                     Bool :$print = $to === $Terminal::Print::T.current-grid) {
        # Ask the destination grid (a Monitor) to do the copy for thread safety
        $print ?? $to.print-from($!grid, $!x, $!y)
               !! $to .copy-from($!grid, $!x, $!y);
    }
}
