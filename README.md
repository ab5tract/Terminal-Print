# Terminal::Print

[![Actions Status](https://github.com/ab5tract/Terminal-Print/workflows/test/badge.svg)](https://github.com/ab5tract/Terminal-Print/actions)

## Synopsis

Terminal::Print intends to provide the essential underpinnings of command-line printing, to be the fuel for the fire, so to speak, for libraries which might aim towards 'command-line user interfaces' (CUI), asynchronous monitoring, rogue-like adventures, screensavers, video art, etc.

## Usage

Right now it only provides a grid with some nice access semantics.

````
my $screen = Terminal::Print.new;

$screen.initialize-screen;                      # saves current screen state, blanks screen, and hides cursor

$screen.change-cell(9, 23, '%');                # change the contents of the grid cell at column 9 line 23
$screen.cell-string(9, 23);                     # returns the escape sequence to put '%' on column 9 line 23
$screen.print-cell(9, 23);                      # prints "%" on the 9th column of the 23rd line
$screen.print-cell(9, 23, '&');                 # changes the cell at x:9, y:23 to '&' and prints it

$screen.print-string(9, 23, "hello\nworld!");   # prints a whole string (which can include newlines!)

$screen(9,23,'hello\nworld!');                  # uses CALL-ME to dispatch to .print-string

$screen.shutdown-screen;                        # unwinds the process from .initialize-screen
````

Check out some animations:

````
perl6 -Ilib examples/rpg-ui.p6
perl6 -Ilib examples/show-love.p6
perl6 -Ilib examples/zig-zag.p6
perl6 -Ilib examples/matrix-ish.p6
perl6 -Ilib examples/async.p6
````

By default the `Terminal::Print` object will use ANSI escape sequences for its cursor drawing, but you can tell it to use `universal` if you would prefer to use the cursor movement commands as provided by `tput`. (You should only really need this if you are having trouble with the default).

```
my $t = Terminal::Print.new(cursor-profile => 'universal')
```

## History

At first I thought I might try writing a NativeCall wrapper around ncurses. Then I realized that there is absolutely no reason to fight a C library which has mostly bolted on Unicode when I can do it in Pure Perl 6, with native Unicode goodness.

## Roadmap

Status: *BETA* -- Current API is fixed and guaranteed!

- Improved documentation and examples
- Upgrade the tests with robust comparisons against a known-good corpus
- Investigate the potential of binding to `libtparm` (the backend to `tput`) via NativeCall

## Problems?

### It dies immediately complaining about my TERM env setting

In order to make the shelling out to `tput` safer, I have opted to use a whitelist of
valid terminals. The list is quite short at the moment, so my apologies if you trigger
this error. Everything should work smoothly once you have added it to the lookup hash
in `Terminal::Print::Commands`. Please consider sending it in as a PR, or filing a bug
report!

### It seems to be sending the wrong escape codes when using a different terminal on the same box

This should only be an issue for non-ANSI terminal users. The tradeoff we currently make
is to only disable precompilation on the module which determines the width and height of the
current screen. This means that other escape sequences in `Terminal::Print::Commands` will
only be run once and then cached in precompiled form. Clearing the related precomp files is
a quick and dirty solution. If you run into this issue, please let me know. I will certainly
get overly excited about your ancient TTY :D

## Contributors

ab5tract, japhb, Bluebear94, Xliff

Released under the Artistic License 2.0.
