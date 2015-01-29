module Terminal::Print::Commands;

our %human-commands;
our %human-controls;
our %tput-controls;
our %attributes;
our %attribute-values;

BEGIN {

    my sub build-cursor-to-template {
        my ($x,$y) = 13,13;
        my $raw = qq:x{ tput cup $y $x };
    
        my Str sub cursor-template( Int :$x,  Int :$y ) {
            # there may be single digit numbers in the escape preamble
            $raw ~~ s:nth(*-2)[\d+] = $y+1;
            $raw ~~ s:nth(*-1)[\d+] = $x+1;
            return $raw;
        }
        return &cursor-template;
    }

    %human-commands = %(
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

    for %human-commands.kv -> $human,$command {
        given $human {
            when 'move-cursor'  { %tput-controls{$command} = &( build-cursor-to-template ) }
            when 'erase-char'   { %tput-controls{$command} = qq:x{ tput $command 1 } }
            default             { %tput-controls{$command} = qq:x{ tput $command } }
        }
        %human-controls{$human} = &( %tput-controls{$command} );
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
    %human-controls<move-cursor>;
}

sub move-cursor( Int $x, Int $y ) is export {
    %human-controls<move-cursor>( :$x, :$y );
}

sub cursor_to( Int $x, Int $y ) is export {
#    %human-controls<move-cursor>( :$x, :$y );
    qq:x{ tput cup $y $x };
}

sub tput( Str $command ) is export {
    die "Not a supported (or perhaps even valid) tput command"
        unless %tput-controls{$command};

    %tput-controls{$command};
}
