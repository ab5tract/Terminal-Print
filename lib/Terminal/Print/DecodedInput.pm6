use v6.d.PREVIEW;
unit module Terminal::Print::DecodedInput;

use Terminal::Print::RawInput;


enum DecodeState < Ground Escape Intermediate >;

enum SpecialKey is export <
     CursorUp CursorDown CursorRight CursorLeft
>;

my %special-keys =
    # PC Normal            PC Application         VT52
    "\e[A" => CursorUp,    "\eOA" => CursorUp,    "\eA" => CursorUp,
    "\e[B" => CursorDown,  "\eOB" => CursorDown,  "\eB" => CursorDown,
    "\e[C" => CursorRight, "\eOC" => CursorRight, "\eC" => CursorRight,
    "\e[D" => CursorLeft,  "\eOD" => CursorLeft,  "\eD" => CursorLeft,
    ;


#| Decode a Terminal::Print::RawInput supply containing special key escapes
multi sub decoded-input-supply(Supply $in-supply) is export {
    my $supplier = Supplier::Preserving.new;

    start react {
        my @partial;
        my $state = Ground;

        my sub drain() {
            $supplier.emit($_) for @partial;
            @partial = ();
        }

        my sub try-convert() {
            @partial = ($_,) with %special-keys{@partial.join};
            drain;
            $state = Ground;
        }

        whenever $in-supply -> $in {
            given $state {
                when Ground {
                    given $in {
                        when "\e" { @partial = $in,; $state = Escape }
                        default   { $supplier.emit($in) }
                    }
                }
                when Escape {
                    drain if $in eq "\e";
                    @partial.push: $in;

                    given $in {
                        when "\e"          { }
                        when any < ? O [ > { $state = Intermediate }
                        when 'A'..'D'      { try-convert }
                        when 'P'..'S'      { try-convert }
                        default            { drain; $state = Ground }
                    }
                }
                when Intermediate {
                    drain if $in eq "\e";
                    @partial.push: $in;

                    given $in {
                        when "\e"      { $state = Escape }
                        when ';'       { }
                        when '0'..'9'  { }
                        when 'A'..'Z'  { try-convert }
                        when 'a'..'z'  { try-convert }
                        when '~'       { try-convert }
                        when ' '       { try-convert }
                        default        { drain; $state = Ground }
                    }
                }
            }
        }
    }

    $supplier.Supply.on-close: { $in-supply.done }
}


#| Convert an input stream into a Supply of characters and special key events
multi sub decoded-input-supply(IO::Handle $input = $*IN) is export {
    decoded-input-supply(raw-input-supply($*IN))
}
