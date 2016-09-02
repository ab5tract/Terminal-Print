use v6;

no precompilation;

unit module Terminal::Print::Dimensions;

=begin pod
=title Terminal::Print::Dimensions

Terminal::Print::Dimensions gives us columns() and rows().
Otherwise the dimensions to be printed will always be the size of the
first terminal window you ran/installed the module on.

=end pod

sub columns is export   { q:x{ tput cols  } .chomp }
sub rows is export      { q:x{ tput lines } .chomp }
