unit module Terminal::Print::Commands;

# Otherwise the dimensions to be printed will always be the size of the
# first terminal window you ran/installed the module on.
no precompilation;

our %human-command-names;
our %human-commands;
our %tput-commands;
our %attributes;
our %attribute-values;

subset Terminal::Print::MoveCursorProfile is export where * ~~ / ^('ansi' | 'universal' | 'debug')$ /;

# we can add more, but there is a qq:x call so whitelist is the way to go.
my %valid-terminals = <xterm xterm-256color vt100> Z=> True;

BEGIN {

    my sub build-cursor-to-template {

        my Str sub ansi( Int $x,  Int $y ) {
            "\e[{$y+1};{$x+1}H";
        }

        my $raw;
        if q:x{ which tput } {
            my $term;
            if %valid-terminals{ %*ENV<TERM>//'' } -> $t {
                $term = $t;
            }
            $term ||= 'xterm';

            $raw = qq:x{ tput -T $term cup 13 13 };
            # Replace the digits with format specifiers used
            # by sprintf
            $raw ~~ s:nth(*-1)[\d+] = "%d";
            $raw ~~ s:nth(*)[\d+]   = "%d";
        }
        $raw ||= '';

        my Str sub universal( Int $x, Int $y ) {
            warn "universal mode must have access to tput" unless $raw;
            sprintf($raw, $y + 1, $x + 1)
        }

        return %(
                    :&ansi,
                    :&universal
                );
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
            when 'move-cursor'  {
                %tput-commands{$command} = build-cursor-to-template;
            }
            when 'erase-char'   {
                %tput-commands{$command} = qq:x{ tput $command 1 }
            }
            default             {
                %tput-commands{$command} = qq:x{ tput $command }
            }
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

sub move-cursor-template( Terminal::Print::MoveCursorProfile $profile = 'ansi' ) returns Code is export {
    %human-commands<move-cursor>{$profile};
}

sub move-cursor( Int $x, Int $y, Terminal::Print::MoveCursorProfile $profile = 'ansi' ) is export {
    %human-commands<move-cursor><$profile>( $x, $y );
}

sub tput( Str $command ) is export {
    die "Not a supported (or perhaps even valid) tput command"
        unless %tput-commands{$command};

    %tput-commands{$command};
}
