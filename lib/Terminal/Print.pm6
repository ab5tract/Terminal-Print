use v6;

use Term::termios;

class Terminal::Print {

    =begin pod
    =title Terminal::Print

    =head1 Synopsis

    L<Terminal::Print> implements an abstraction layer for printing characters to
    terminal screens with full Unicode support and -- crucially -- the ability to
    print from concurrent threads. The idea is to provide all the necessary
    mechanical details while leaving the actual so called 'TUI' abstractions to
    higher level libraries.

    Obvious applications include snake clones, rogue engines and golfed art works :)

    Oh, and Serious Monitoring Apps, of course.

    =head1 Usage

    L<Terminal::Print> creates you an object for you when you import it, stored in
    C<$Terminal::Print::T>. It also creates a constant C<T> for you in the C<OUR::>
    scope.

    Thus common usage would look like this:

    =for code
    T.initialize-screen;
    T.print-string(20, 20, DateTime.now);
    T.shutdown-screen;

    =head1 Miscellany

    =head2 Where are we at now?

    All the features you can observe while running C<perl6 t/basics.t> work using
    the new react/supply based L<Terminal::Print::Grid>. If you run that test file,
    you will notice that C<Terminal::Print> is needing a better test harness.
    Part of that is getting a C<STDERR> or some such pipe going, and printing state/
    That will make debugging a lot easier.

    Testing a thing that is primarily designed to print to a screen seems a bit
    difficult anyway. I almost think we should make it interactive. 'Did you see a
    screen of hearts?'

    So: async (as mentioned above), testing, and debugging are current pain points.
    Contributions welcome.

    =head2 Why not just use L<NativeCall> and C<ncurses>?

    I tried that first and it wasn't any fun. C<ncurses> unicode support is
    admirable considering the age and complexity of the library, but it
    still feels bolted on.

    C<ncurses> is not re-entrant, either, which would nix one of the main benefits
    we might be able to get from using Perl 6 -- easy async abstractions.

    =end pod

    use Terminal::Print::Grid;
    use Terminal::Print::Widget;

    has Terminal::Print::Grid $.current-grid handles 'indices';
    has Terminal::Print::Grid @.grids;

    has Term::termios $!termios;
    has $!saved-termios;

    has %!grid-name-map;
    has %!root-widget-map{Terminal::Print::Grid};

    has $.columns;
    has $.rows;

    use Terminal::Print::Commands;

    subset Valid::X of Int is export where * < columns();
    subset Valid::Y of Int is export where * < rows();
    subset Valid::Char of Str is export where *.chars == 1;

    has Terminal::Print::CursorProfile $.cursor-profile;
    has $.move-cursor;

    method new( :$cursor-profile = 'ansi' ) {
        my $columns      = columns();
        my $rows         = rows();
        my $move-cursor  = move-cursor-template($cursor-profile);
        my $current-grid = Terminal::Print::Grid.new( $columns, $rows, :$move-cursor );

        #XXX: investigate whether this is ideal or not
        my $termios := Term::termios.new(fd => 1).getattr;

        self.bless( :$columns, :$rows, :$current-grid,
                    :$cursor-profile,  :$move-cursor, :$termios );
    }

    submethod BUILD( :$!current-grid, :$!columns, :$!rows, :$!cursor-profile, :$!move-cursor, :$!termios ) {
        push @!grids, $!current-grid;

        $!saved-termios = $!termios;

        # set up a tap on SIGINT so that we can cleanly shutdown, restoring the previous screen and cursor
        signal(SIGINT).tap: {
            @!grids>>.disable;
            self.shutdown-screen;
            die "Encountered a SIGINT. Cleaning up the screen and exiting...";
        }
    }

    method root-widget() {
        my $grid = self.current-grid;
        %!root-widget-map{$grid} ||= Terminal::Print::Widget.new-from-grid($grid);
    }

    method add-grid( $name?, :$new-grid = Terminal::Print::Grid.new( $!columns, $!rows, :$!move-cursor ) ) {
        push @!grids, $new-grid;
        if $name {
            %!grid-name-map{$name} = +@!grids-1;
        }
        $new-grid;
    }

    multi method switch-grid( Int $index, :$blit ) {
        die "Grid index $index does not exist" unless @!grids[$index]:exists;
        self.blit($index) if $blit;
        $!current-grid = @!grids[$index];
    }

    multi method switch-grid( Str $name, :$blit ) {
        die "No grid has been named $name" unless my $index = %!grid-name-map{$name};
        self.blit($index) if $blit;
        $!current-grid = @!grids[$index];
    }

    method blit( $grid-identifier = 0 ) {
        self.clear-screen;
        self.print-grid($grid-identifier);
    }

    # 'clear' will also work through the FALLBACK
    method clear-screen {
        print-command <clear>;
    }

    method initialize-screen {
        $!termios.makeraw;
        print-command <save-screen>;
        print-command <hide-cursor>;
        print-command <clear>;
    }

    method shutdown-screen {
        $!saved-termios.setattr(:DRAIN);
        print-command <clear>;
        print-command <restore-screen>;
        print-command <show-cursor>;
    }

    method print-command( $command ) {
        print-command($command, $!cursor-profile);
    }

    # AT-POS hands back a Terminal::Print::Column
    #   $b[$x]
    # Because we have AT-POS on the column object as well,
    # we get
    #   $b[$x][$y]
    method AT-POS( $column-idx ) {
        $!current-grid.grid[ $column-idx ];
    }

    # AT-KEY returns the Terminal::Print::Grid.grid of whichever the key specifies
    #   $b<specific-grid>[$x][$y]
    method AT-KEY( $grid-identifier ) {
        self.grid( $grid-identifier );
    }

    multi method CALL-ME($x, $y) {
        $!current-grid.print-cell($x, $y);
    }

    multi method CALL-ME($x, $y, %c) {
        $!current-grid.print-cell($x, $y, %c);
    }

    multi method CALL-ME($x, $y, $c) {
        $!current-grid.print-string($x, $y, $c);
    }

    multi method FALLBACK( Str $command-name where { %T::human-command-names{$_} } ) {
        print-command( $command-name );
    }

    # multi method sugar:
    #    @!grids and @!buffers can both be accessed by index or name (if it has
    #    one). The name is optionally supplied when calling .add-grid.
    #
    #    In the case of @!grids, we pass back the grid array directly from the
    #    Terminal::Print::Grid object, actually notching both DWIM and DRY in one swoosh.
    #    because you can do things like  $b.grid("background")[42][42] this way.

    multi method grid() {
        $!current-grid.grid;
    }

    multi method grid( Int $index ) {
        @!grids[$index].grid;
    }

    multi method grid( Str $name ) {
        die "No grid has been named $name" unless my $grid-index = %!grid-name-map{$name};
        @!grids[$grid-index].grid;
    }

    #### grid-object stuff

    #   Sometimes you simply want the object back (for stringification, or
    #   introspection on things like column-range)
    proto method grid-object($) { }
    multi method grid-object( Int $index ) {
        @!grids[$index];
    }

    multi method grid-object( Str $name ) {
        die "No grid has been named $name" unless my $grid-index = %!grid-name-map{$name};
        @!grids[$grid-index];
    }

    method print-cell(|c) {
        $!current-grid.print-cell(|c);
    }

    method print-string(|c) {
        $!current-grid.print-string(|c);
    }

    method change-cell( $x, $y, Str $c ) {
        $!current-grid.change-cell($x, $y, $c);
    }

    method cell-string($x, $y) {
        $!current-grid.cell-string($x, $y);
    }

    #### print-grid stuff
    proto method print-grid($) { }
    multi method print-grid( Int $index ) {
        die "Grid index $index does not exist" unless @!grids[$index]:exists;
        print @!grids[$index];
    }

    multi method print-grid( Str $name ) {
        die "No grid has been named $name" unless my $index = %!grid-name-map{$name};
        print @!grids[$index];
    }

    # method !clone-grid-index( $origin, $dest? ) {
    #     my $new-grid;
    #     if $dest {
    #         $new-grid := self.add-grid($dest, new-grid => @!grids[$origin].clone);
    #     } else {
    #         @!grids.push: @!grids[$origin].clone;
    #     }
    #     return $new-grid;
    # }
    #
    # #### clone-grid stuff
    #
    # multi method clone-grid( Int $origin, Str $dest? ) {
    #     die "Invalid grid '$origin'" unless @!grids[$origin]:exists;
    #     self!clone-grid-index($origin, $dest);
    # }
    #
    # multi method clone-grid( Str $origin, Str $dest? ) {
    #     die "Invalid grid '$origin'" unless my $grid-index = %!grid-name-map{$origin};
    #     self!clone-grid-index($grid-index, $dest);
    # }

    method Str {
        ~$!current-grid;
    }

    method gist {
        "\{ cols: {self.columns} rows: {self.rows} which: {self.WHICH} grid: {self.current-grid.WHICH} \}";
    }

    =begin Golfing

    The golfing mechanism is minimal. Further golfing functionality may be added via third party modules,
    but the following features seemed to fulfill a 'necessary minimum' set of golfing requirements:

        - Not being subjected to a constructor command, certainly not against the full name of the class
            + Solved via an optional argument to the use/import statement, eg C<use Terminal::Print <T>>
                will create an instance and stash it in the importing scope as C<T>.
            + By default we do not construct an object for you.
        - Having a succinct subroutine form which can initialize and shutdown the screen automatically
            + Solved via 'draw'
        - Easy access to .print-string, sleep, colorization, and the grid indices list. (Even easier than using T());
            + Solved via 'd', 'w', 'h', 'p', 'cl', 'ch', 'slp', 'fgc', 'bgc', 'in'

    =end Golfing

    multi method p($x, $y) {
        self.current-grid.print-string($x, $y);
    }

    multi method p($x, $y, $string) {
        $!current-grid.print-string($x, $y, $string);
    }

    multi method p($x, $y, $string, $color) {
        $!current-grid.print-string($x, $y, $string, $color);
    }

    multi method p($x, $y, %details) {
        $!current-grid.print-string($x, $y, %details);
    }

    method draw(Callable $block) {
        my $drawn-promise = Promise.new;
        start {
            my $end-promise = Promise.new;
            self.initialize-screen;
            $block($end-promise);
            await $end-promise;
            self.shutdown-screen;
            $drawn-promise.keep;
        }
        await $drawn-promise;
    }

    multi method ch($x, $y, $char) {
        $!current-grid.change-cell($x, $y, $char);
    }

    multi method ch(Terminal::Print $T, $x, $y, $char, $color) {
        $!current-grid.change-cell($x, $y, %(:$char, :$color) );
    }

    multi method cl(Terminal::Print $T, $x, $y, $char) {
        $!current-grid.print-cell($x, $y, $char);
    }

    multi method cl(Terminal::Print $T, $x, $y, $char, $color) {
        $!current-grid.print-cell($x, $y, %(:$char, :$color) );
    }
}

sub EXPORT($term-name?) {
    if $term-name {
        my $t = PROCESS::<$TERMINAL> = Terminal::Print.new;

        return {
            "$term-name"    => $t,
            "w"             => $t.columns,
            "h"             => $t.rows,
            "in"            => $t.indices,
            "fgc"           => @Terminal::Print::Commands::fg_colors,
            "bgc"           => @Terminal::Print::Commands::bg_colors,
            "&draw"         => { $t.draw(|@_) },
            "&p"            => { $t.p(|@_) },
            "&ch"           => { $t.ch(|@_) },
            "&cl"           => { $t.cl(|@_) },
            "&slp"          => -> $seconds { sleep($seconds) }
        }
    } else {
        return {};
    }
}
