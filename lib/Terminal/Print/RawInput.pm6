use v6.d.PREVIEW;
unit module Terminal::Print::RawInput;

# For TTY raw mode
use Term::termios;


#| Convert an input stream to a Supply of individual characters
#  Reads bytes in order to work around lower-layer grapheme combiner handling
#  (which will make the input seem to be on a one-character delay).
sub raw-input-supply(IO::Handle $input = $*IN) is export {
    # If a TTY, convert to raw mode, saving current mode first
    my $saved-termios;
    if $input.t {
        my $fd = $input.native-descriptor;
        $saved-termios = Term::termios.new(:$fd).getattr;
        Term::termios.new(:$fd).getattr.makeraw.setattr(:DRAIN);
    }

    # Cancelable character supply loop; emits a character as soon as any
    # collected bytes are decodable, and can be canceled with $supply.done.
    my $done = False;
    supply {
        LOOP: until $done {
            my $buf = Buf.new;

            # TimToady++ for suggesting this decode loop idiom
            repeat {
                my $b = $input.read(1) or last LOOP;
                $buf.push($b)
            } until try my $c = $buf.decode;

            emit($c)
        }

        # Restore saved TTY mode if any
        $saved-termios.setattr(:DRAIN) if $saved-termios;

    } does role { method done { $done = True } }
}
