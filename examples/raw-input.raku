use Terminal::Print::RawInput;

# Display character stream, exiting the program when 'q' is pressed
my $in-supply = raw-input-supply;
react {
    whenever $in-supply -> $c {
        my $char = $c.ord < 32 ?? '^' ~ ($c.ord + 64).chr !! $c;
        printf "got: %3d  %2s  %2s\r\n", $c.ord, $c.ord.base(16), $char;

        done if $c eq 'q';
    }
}

# Give the input supply enough time to restore the TTY state
sleep .1;
