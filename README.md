# Terminal::Print

## Synopsis

Terminal::Print intends to provide the essential underpinnings of command-line printing, to be the fuel for the fire, so to speak, for libraries which might aim towards 'command-line user interfaces' (CUI), asynchronous monitoring, rogue-like adventures, screensavers, video art, etc.

## Usage

Right now it only provides a grid with some nice access semantics.

````
my $screen = Terminal::Print.new;

$screen.initialize-screen;              # saves current screen state, blanks screen, and hides cursor

$screen.change-cell(9, 23, '%');        # change the contents of the grid cell at line 9 column 23
$screen.cell-string(9, 23);             # returns the escape sequence to put '%' on line 9 column 23
$screen.print-cell(9, 23);              # prints "%" on the 23rd column of the 9th row
$screen.print-cell(9, 23, '&');         # changes the cell at 9:23 to '&' and prints it

$screen(9,23,'%');                      # uses CALL-ME to dispatch the provided arguments to .print-cell

$screen.shutdown-screen;                # unwinds the process from .initialize-screen
````

Check out some animations:

````
perl6 -Ilib examples/show-love.p6
perl6 -Ilib examples/zig-zag.p6
perl6 -Ilib examples/matrix-ish.p6
perl6 -Ilib
````

By default the `Terminal::Print` object will use ANSI escape sequences for it's cursor drawing, but you can tell it to use `universal` if you would prefer to use the cursor movement commands as provided by `tput`. (You should only really need this if you are having trouble with the default).

```
my $t = Terminal::Print(cursor-profile => 'universal')
```

## History

At first I thought I might try writing a NativeCall wrapper around ncurses. Then I realized that there is absolutely no reason to fight a C library which has mostly bolted on Unicode when I can do it in Pure Perl 6, with native Unicode goodness.

## Roadmap

Status: *BETA*

- Create an abstraction around the entire draw cycle, replacing the initialize-draw-shutdown patttern with a block that is passed to a `.draw` method on the `Terminal::Print` object itself
- Upgrade the tests with robust comparisons against a known-good corpus
- Investigate the potential of binding to `libtparm` (the backend to `tput`) via NativeCall
- Re-arrange the grabbing of the terminal width and height such that `Terminal::Print::Commands` can be precompiled. (Though arguably we should never do this, in case someone is running the code between two different incompatible terminals, I think we can burn that effigy when it is actually needed -- and save a hefty amount of startup time on the way).

## Problems?

### It dies immediately complaining about my TERM env setting

In order to make the shelling out to `tput` safer, I have opted to use a whitelist of
valid terminals. The list is quite short at the moment, so my apologies if you trigger
this error. Everything should work smoothly once you have added it to the lookup hash
in `Terminal::Print::Commands`. Please consider sending it in as a PR, or filing a bug
report!


This module is currently a bit under nourished. It hungers for a proper test suite and documentation.

Copyright 2015-2016, John Haltiwanger. Released under the Artistic License 2.0.
