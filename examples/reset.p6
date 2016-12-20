# ABSTRACT: Initialize and then shutdown the screen

use v6;
use Terminal::Print;


my $t = Terminal::Print.new;

$t.initialize-screen;

$t.shutdown-screen;
