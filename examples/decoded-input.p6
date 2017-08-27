use Terminal::Print::DecodedInput;

# Display character stream, exiting the program when 'q' is pressed
my $in-supply = decoded-input-supply;
react {
    whenever $in-supply -> $c {
        if $c ~~ Str {
            my $char = $c.ord < 32 ?? '^' ~ ($c.ord + 64).chr !! $c;
            printf "got: %3d  %2s  %2s\r\n", $c.ord, $c.ord.base(16), $char;
            done if $c eq 'q';
        }
        elsif $c ~~ SpecialKey {
            printf "got: $c\r\n";
        }
        else {
            my @mods = ('Meta' if $c.meta), ('Control' if $c.control),
                       ('Alt'  if $c.alt),  ('Shift'   if $c.shift);
            printf "got: %-12s  (@mods[])\r\n", $c.key;
        }
    }
}

# Give the input supply enough time to restore the TTY state
sleep .1;
