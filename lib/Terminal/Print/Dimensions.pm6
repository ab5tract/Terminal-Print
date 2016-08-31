use v6;

no precompilation;

unit module Terminal::Print::Dimensions;

sub columns is export   { qq:x{ tput cols  } .chomp }
sub rows is export      { qq:x{ tput lines } .chomp }
