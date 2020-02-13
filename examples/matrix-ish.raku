# ABSTRACT: Draw the green falling characters of a Matrix-like screen

use v6;
use Terminal::Print <T>;

T.initialize-screen;

my @chars = 'ァ'..'ヾ';
my @columns = ^T.columns;

my @xs = @columns.pick(*).grep({ $_ != 0 && $_ %% 6 }).rotor(5, :partial);

# This will go away after some upcoming hash work
my %hash-hack = %( char => '', color => '' );

while +@xs {
    my @x-range = |@xs.pop;
    await do for @x-range -> $x {
        start {
            for ^T.rows -> $y {
                my $string-printed;
                last if ^21 .roll == 7;
                until ^42 .roll == 0 and $string-printed {
                    unless ^5 .roll == 3 {
                        T.print-cell($x, $y, %( char => @chars.roll, color => 'bold black on_green') );
                        $string-printed = True;
                        T.print-cell($x, $y, %( char => @chars.roll, color => 'bold green' ) );
                    }
                }
            }
        }
    }
}

T.shutdown-screen;
