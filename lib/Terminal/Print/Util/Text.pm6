# ABSTRACT: Miscellaneous text utilities

# XXXX: API still in heavy flux!


unit module Terminal::Print::Util::Text;


#| Wrap $text to width $w, adding $prefix at the start of each line after the first and $first-prefix to the first line
sub wrap-text($w, $text, $prefix = '', $first-prefix = '') is export {
    my @words = $text.words;
    return [] unless @words;

    # Quick out for short text; still joins @words to maintain uniform spacing
    return [ $first-prefix ~ @words.join(' ') ]
        if $w > $first-prefix.chars + $text.chars;

    # Invariants:
    #  * Latest line in @lines always contains at least a prefix and one word
    #  * No line is wider than $w unless it contains only one very long word
    #    (no attempt is made to split single words across multiple lines)
    my @lines = $first-prefix ~ @words.shift;

    for @words -> $word {
        # If next word won't fit, use it to start a new line
        if $w < @lines[*-1].chars + 1 + $word.chars {
            push @lines, "$prefix$word";
        }
        # ... otherwise just extend the last line
        else {
            @lines[*-1] ~= " $word";
        }
    }

    @lines
}
