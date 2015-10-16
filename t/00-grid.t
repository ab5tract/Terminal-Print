use v6;

use lib './lib';
use test;

use Terminal::Print::Grid;

my $grid;

lives-ok    { $grid = Terminal::Print::Grid.new(:max-rows(20),:max-columns(10)) }, 'Grid survived';
lives-ok    { $grid.initialize }, '$grid.initialize works';
lives-ok    { $grid.change-cell(1,1,'Y') }, '$grid.change-cell works';
ok          $grid[1;1] eq 'Y', 'Inserted value present where expected';
lives-ok    { $grid[0][0] = "X" }, 'Can assign "X" to $grid[0][0]';
lives-ok    { $grid.shutdown }, '$grid.shutdown works';
