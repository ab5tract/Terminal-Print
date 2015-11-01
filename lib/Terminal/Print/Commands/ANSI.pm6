unit module Terminal::Print::Commands::ANSI;

use Terminal::Print::Commands;
constant T = Terminal::Print::Commands;

use v6;

BEGIN {
    %T::human-commands<move-cursor> = -> :$x,:$y { "\e[{$y+1};{$x+1}H" };
}
