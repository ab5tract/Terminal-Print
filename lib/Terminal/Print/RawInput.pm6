use v6.d.PREVIEW;
unit module Terminal::Print::RawInput;

# For TTY raw mode
use Terminal::API;

#| Convert an input stream to a Supply of individual characters
#  Reads bytes in order to work around lower-layer grapheme combiner handling
#  (which will make the input seem to be on a one-character delay).
sub raw-input-supply(IO::Handle $input = $*IN,
                     Bool :$drop-old-unread) is export {
    # If a TTY, convert to raw mode, saving current mode first
    my $fd = $input.native-descriptor;
    my $saved-term-config;
    if $input.t {
        $saved-term-config = Terminal::API::get-config($fd);
        my $when           = $drop-old-unread ?? Terminal::API::FLUSH !! Terminal::API::DRAIN;
        Terminal::API::make-raw($fd, :$when);
    }

    # Cancelable character supply loop; emits a character as soon as any
    # collected bytes are decodable.  jnthn++ for explaining this supply variant
    # and providing successive improvements in API and semantics in
    # https://rt.perl.org/Public/Bug/Display.html?id=130716
    my $s = Supplier::Preserving.new;
    my $done = False;
    start {
        LOOP: until $done {
            my $buf = Buf.new;

            # TimToady++ for suggesting this decode loop idiom
            repeat {
                my $b = $input.read(1) or last LOOP;
                $buf.push($b);
            } until $done || try my $c = $buf.decode;

            $s.emit($c) unless $done;
        }
    }
    $s.Supply.on-close: {
        # Restore saved TTY mode if any
        Terminal::API::restore-config($saved-term-config, $fd, :when(Terminal::API::DRAIN)) if $saved-term-config;
        $done = True;
    }
}
