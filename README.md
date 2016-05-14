# Terminal::Print

## History

At first I thought I might try writing a NativeCall wrapper around ncurses. Then I realized that there is absolutely no reason to fight a C library which has mostly bolted on Unicode when I can do it in Pure Perl 6, with native Unicode goodness.

## Usage

Right now it only provides a grid with some nice access semantics.

````
  my $screen = Terminal::Print.new;

  $screen[9][23] = "%";         # prints the escape sequence to put '%' on line 9 column 23
  $screen[9][23];               # returns "%"
  $screen[9][23].print-cell     # prints "%" on the 23rd column of the 9th row

  $screen(9,23,"%");            # another way, designed for golfing or simpler expression
````

(Please note that these are are still subject to change as the library develops further).

Terminal::Print intends to provide the essential underpinnings of command-line printing, to be the fuel for the fire, so to speak, for libraries which might aim towards 'command-line user interfaces' (CUI), asynchronous monitoring, rogue-like adventures, screensavers, video art, etc.

Check out some animations:
````
perl6 -Ilib examples/show-love.p6
perl6 -Ilib examples/zig-zag.p6
perl6 -Ilib examples/matrix-ish.p6
perl6 -Ilib
````

By default the `Terminal::Print` object will use ANSI escape sequences for it's cursor drawing, but you can tell it to use `universal` if you would prefer to use the cursor movement commands as provided by `tput`. (You should only really need this if you are having trouble with the default).

```
    my $t = Terminal::Print(move-cursor-profile => 'universal')
```

Additionally, we have `debug`. This will be used to generate and run the test suite.

# It dies immediately complaining about my TERM env setting

In order to make the shelling out to `tput` safer, I have opted to use a whitelist of
valid terminals. The list is quite short at the moment, so my apologies if you trigger
this error. Everything should work smoothly once you have added it to the lookup hash
in `Terminal::Print::Commands`. Please consider sending it in as a PR, or filing a bug
report!

# STATUS: BETA

This module is currently a bit under nourished. It hungers for a proper test suite and documentation.

Copyright 2015-2016, John Haltiwanger. Released under the Artistic License 2.0.
