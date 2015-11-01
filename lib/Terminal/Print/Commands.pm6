unit module Terminal::Print::Commands;

our %human-command-names;
our %human-commands;
our %tput-commands;
our %attributes;
our %attribute-values;

constant USE-ANSI = so %*ENV<USE_ANSI>;

BEGIN {

    my sub build-cursor-to-template {
        my ($x,$y) = 13,13;
        my $raw = qq:x{ tput cup $y $x };
        # Replace the digits with format specifiers used
        # by sprintf
        $raw ~~ s:nth(*-1)[\d+] = "%d";
        $raw ~~ s:nth(*)[\d+]   = "%d";
        # This sub replaces the parameters received from the
        # output given by tput with the appropriate values.
        # TODO: regex search might be inefficient;
        # might want to investigate
        my Str sub cursor-template( Int :$x,  Int :$y ) {
            #my $t = now;
            #return "\e[{$y+1};{$x+1}H" if USE-ANSI;
            my $res = USE-ANSI ?? "\e[{$y+1};{$x+1}H" !! sprintf($raw, $y + 1, $x + 1);
            #print "\e[1;1H{ now - $t }";
            return $res;
        }
        return &cursor-template;
    }

    %human-command-names = %(
        'clear'              => 'clear',
        'save-screen'        => 'smcup',
        'restore-screen'     => 'rmcup',
        'pos-cursor-save'    => 'sc',
        'pos-cursor-restore' => 'rc',
        'hide-cursor'        => 'civis',
        'show-cursor'        => 'cnorm',
        'move-cursor'        => 'cup',
        'erase-char'         => 'ech',
    );

    for %human-command-names.kv -> $human,$command {
        given $human {
            when 'move-cursor'  { %tput-commands{$command} = &( build-cursor-to-template ) }
            when 'erase-char'   { %tput-commands{$command} = qq:x{ tput $command 1 } }
            default             { %tput-commands{$command} = qq:x{ tput $command } }
        }
        %human-commands{$human} = &( %tput-commands{$command} );
    }

    %attributes = %(
        'columns'       => 'cols',
        'rows'          => 'lines',
        'lines'         => 'lines',
    );

    %attribute-values<columns>  = %*ENV<COLUMNS> //= qq:x{ tput cols };
    %attribute-values<rows>     = %*ENV<ROWS>    //= qq:x{ tput lines };
}

sub move-cursor-template returns Code is export {
    %human-commands<move-cursor>;
}

sub move-cursor( Int $x, Int $y ) is export {
    %human-commands<move-cursor>( :$x, :$y );
}

sub cursor_to( Int $x, Int $y ) is export {
    %human-commands<move-cursor>( :$x, :$y );
}

sub tput( Str $command ) is export {
    die "Not a supported (or perhaps even valid) tput command"
        unless %tput-commands{$command};

    %tput-commands{$command};
}
