use Terminal::Print::DecodedInput;

# Display character stream, exiting the program when 'q' is pressed
my $in-supply = decoded-input-supply;

set-mouse-event-mode(AnyEvents);

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
        elsif $c ~~ Terminal::Print::DecodedInput::ModifiedSpecialKey {
            my @mods = ('Meta' if $c.meta), ('Control' if $c.control),
                       ('Alt'  if $c.alt),  ('Shift'   if $c.shift);
            printf "got: %-12s  (@mods[])\r\n", $c.key;
        }
        elsif $c ~~ Terminal::Print::DecodedInput::MouseEvent {
            my @mods    = ('Meta'  if $c.meta), ('Control' if $c.control),
                          ('Shift' if $c.shift);
            my $mods    = @mods ?? " (@mods[])" !! '';
            my $pressed = $c.pressed ?? 'press' !! 'release';
            my $button  = $c.button ?? "button $c.button() $pressed" !! '';
            printf "Mouse: $c.x(),$c.y() { 'motion ' if $c.motion }$button$mods\r\n";
        }
    }
}

set-mouse-event-mode(NoEvents);
