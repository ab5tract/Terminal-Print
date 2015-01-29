
## History

At first I thought I might try writing a NativeCall wrapper around ncurses. Then I realized that there is absolutely no reason to fight a C library which has mostly bolted on Unicode when I can do it in Pure Perl 6, with native Unicode goodness.

## Usage

Right now it only provides a grid with some nice access semantics.

  my $screen = Terminal::Print.new;
  $screen[9][23] = "%";         # prints the escape sequence to put '%' on line 9 column 23
  $screen[9][23];               # returns "%"
  $screen[9][23].print-cell     # prints "%" on the 23rd column of the 9th row
  
  $screen(9,23,"%");       # another way, designed for golfing. there should be a whole sub-module to support golfing (hello, `enum`)

(Note that these are subject to change as the library more fully develops).

But the idea is that in the long-term you will be able to specify views either programmatically or through a JSON structure. These views will support async updates from whatever sources one might desire, allowing for quick hacking together of different "command center"-style scripts.

But if you want to see a pretty display of hearts filling your terminal, just `perl6 Boxbrain.pm` and enjoy. (Even more fun if you set your font size really small ;) ).

## TODO ##

- add row access ($row := $grid[\*][$y] for $cols)
- add async mechanisms for printing "channels" (guardian processes which update
  specific sections of the screen)
- complete the zig-zag example and add others
- split tests into visual and functional. only run functional on install
