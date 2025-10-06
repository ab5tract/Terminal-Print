module Terminal::Print::Commands
{

=begin pod
=title Terminal::Print::Commands

=head1 Synopsis

This module essentially just creates a hash of escape sequences for doing various
things, along with a few exported sub-routines to make interacting with this hash
a bit nicer.

=end pod

use Terminal::API;

our @fg_colors = [ <black red green yellow blue magenta cyan white default> ];
our @bg_colors = [ <on_black on_red on_green on_yellow on_blue on_magenta on_cyan on_white on_default> ];
our @styles    = [ <reset bold underline inverse> ];

my %commands =
    clear => "\e[H\e[2J\e[3J",
    save-screen => "\e[?1049h\e[22;0;0t",
    restore-screen => "\e[?1049l\e[23;0;0t",
    hide-cursor => "\e[?25l",
    show-cursor => "\e[?12l\e[?25h",
;

sub columns is export { Terminal::API::get-window-size().cols }
sub rows    is export { Terminal::API::get-window-size().rows }

sub move-cursor(Int() $x, Int() $y) is export {
    "\e[{$y+1};{$x+1}H"
}

sub print-command($command) is export {
    print %commands{$command};
}

}
