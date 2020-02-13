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

    #| Wrap an existing T::P::Grid into a T::P::Widget
    method new-from-grid($grid, |c) {
        self.new(:$grid, :w($grid.w), :h($grid.h), :x(0), :y(0), |c);
    }

    #| Replace widget's backing grid, updating widget size to match
    method replace-grid($!grid) {
        $!w = $!grid.w;
        $!h = $!grid.h;
    }

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

    #| Remove a child widget from this one
    method remove-child(Terminal::Print::Widget $child) {
        # <> performs decont (decontainerizing) magic so that =:= can compare
        # the identity of the underlying objects, not their containers
        @!children .= grep(*<> !=:= $child<>);
    }

    #| Return T::P::Grid object that this Widget will draw on
    method target-grid() {
        given $!parent {
            when Terminal::Print::Grid   { $_    }
            when Terminal::Print::Widget { .grid }
            default                      { $*TERMINAL.current-grid }
        }
    }

    #| Composite this widget onto a target grid, optionally printing to screen
    # For now, simply copies widget contents (effects such as alpha blend NYI).
    # Default behavior is to print iff the widget's parent is the screen grid.
    method composite(Terminal::Print::Grid :$to = self.target-grid,
                     Bool :$print = $to === $*TERMINAL.current-grid) {

        # Skip copy if target is own backing grid, e.g. screen's root widget
        if $to === $!grid {
            print $!grid if $print;
        }
        else {
            # Destination grid (a Monitor) does the work for thread safety
            $print ?? $to.print-from($!grid, $!x, $!y)
                   !! $to .copy-from($!grid, $!x, $!y);
        }
    }
}
