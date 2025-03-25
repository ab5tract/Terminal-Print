use Test;
use lib 'lib';

chdir('t');
plan 4;

sub slurp-corpus($topic) {
    "corpus/$topic".IO.slurp;
}

use Terminal::Print; pass "Import Terminal::Print";

my $b = Terminal::Print.new;
lives-ok { my $t = Terminal::Print.new; }, "Can create a Terminal::Print object";

lives-ok { my $t = Terminal::Print.new( :cursor-profile('universal') ) },
    "Can create Terminal::Print object with print-profile 'universal'";

dies-ok { my $t = Terminal::Print.new( :cursor-profile('nonexistent') ) },
    "Cannot create Terminal::Print object with print-profile 'nonexistent'";

#ok $b.print-command('save-screen') eq slurp-corpus('save-screen'), ".save-screen matches corpus";
#ok $b.print-command('restore-screen') eq slurp-corpus('restore-screen'), ".restore-screen matches corpus";

#
# lives-ok {
#     do {
#         sleep 0.5;
#         $b.initialize-screen;
#         print ~$b.grid-object(0);
#         sleep 0.5;
#         $b.shutdown-screen;
#     }
# }, "Can print the whole screen by stringifying the default grid object";
#
# lives-ok {
#     do {
#         sleep 0.5;
#         $b.initialize-screen;
#         $b.print-grid(0);
#         sleep 0.5;
#         $b.shutdown-screen;
#     }
# }, "Can print the whole screen by using .print-screen with a grid index";
#
# lives-ok {
#     $b.add-grid('5s');
# }, "Can add a (named) grid";
#
# lives-ok {
#     $b.clone-grid(0);
# }, "Can clone a grid (index origin)";
#
# lives-ok {
#     $b.clone-grid(0,'hearts-again');
# }, "Can clone a grid (index origin, named destination)";
#
# lives-ok {
#     $b.clone-grid('5s');
# }, "Can clone a grid (named index)";
#
# lives-ok {
#     $b.clone-grid('5s','5s+2');
# }, "Can clone a grid (named index, named destination)";
#
# lives-ok {
#     do {
#         $b.initialize-screen;
#         $b.print-grid('hearts-again');
#         sleep 0.5;
#         $b.shutdown-screen;
#     }
# }, "Cloned screen 'hearts-again' prints the same hearts again";
#
# ok +$b.grids[*] == 6, 'There are the expected number of grids available through $b.grids';
#
# ok $b.clone-grid(0,'h4') === $b.grids[*-1], ".clone-grid returns the clone itself";
#
# # TODO: Bring back grep-grid !!
#
# #lives-ok {
# #    do {
# #        $b.initialize-screen;
# #        $b.grid-object('hearts-again').grep-grid({$^x %% 3 and $^y %% 2 || $x %% 2 and $y %% 3 || so $x|$y %% 7}, :o);
# #        sleep 1;
# #        $b.shutdown-screen;
# #    }
# #}, "Printing individual hearts based on grep-grid";
#
# lives-ok {
#     do {
#         $b.initialize-screen;
#         sleep 1;
#         $b.print-grid('hearts-again');
#         sleep 1;
#         $b.shutdown-screen;
#     }
# }, "print-grid('hearts-again') (aka the same grid) prints the same as the previous run";
#
# lives-ok {
#     do {
#         $b.initialize-screen;
#         sleep 1;
#         $b.blit(0);
#         sleep 1;
#         $b.blit('hearts-again');
#         sleep 1;
#         $b.blit(0);
#         sleep 0.5;
#         $b.blit('hearts-again');
#         sleep 0.5;
#         $b.blit(0);
#         sleep 0.5;
#         $b.blit('hearts-again');
#         sleep 0.5;
#         $b.blit(0);
#         sleep 0.5;
#         $b.blit('hearts-again');
#         sleep 0.5;
#         $b.blit(0);
#         sleep 0.5;
#         $b.blit('hearts-again');
#         sleep 0.5;
#         $b.shutdown-screen;
#     }
# }, "blitting between grids works";
