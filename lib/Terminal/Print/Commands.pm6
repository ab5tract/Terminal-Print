unit module Terminal::Print::Commands;

=begin pod
=title Terminal::Print::Commands

=head1 Synopsis

This module essentially just creates a hash of escape sequences for doing various
things, along with a few exported sub-routines to make interacting with this hash
a bit nicer.

=head1 A note on precompilation

Terminal::Print::Dimensions gives us columns() and rows().
Otherwise the dimensions to be printed will always be the size of the
first terminal window you ran/installed the module on.

My working hope is that pushing just these two things into a smaller module,
will reduce the cost incurred by 'no precompilation' by isolating these two
clearly un-cachable values.

Thus, the jury may still be out on whether this module needs to have C<no precompilation>
set or not. Please get in touch if you run into any issues.

=end pod

use Terminal::Print::Dimensions; 

our %human-command-names;
our %human-commands;
our %tput-commands;
our %attributes;
our %attribute-values;

subset Terminal::Print::CursorProfile is export where * ~~ / ^('ansi' | 'universal')$ /;

BEGIN {
    # we can add more, but there is a qq:x call so whitelist is the way to go.
    my %valid-terminals = <xterm xterm-256color vt100 screen> X=> True;
    my $term = %*ENV<TERM> || 'xterm';

    die "Please update %valid-terminals with your desired TERM ('$term', is it?) and submit a PR if it works"
        unless %valid-terminals{ $term };

    die 'Cannot use Terminal::Print without `tput` (usually provided by `ncurses`)'
        unless q:x{ which tput };

    my sub build-cursor-to-template {

        my Str sub ansi( Int() $x,  Int() $y ) {
            "\e[{$y+1};{$x+1}H";
        }

        my $raw = qq:x{ tput -T $term cup 13 13 };
        # Replace the digits with format specifiers used
        # by sprintf
        $raw ~~ s:nth(*-1)[\d+] = "%d";
        $raw ~~ s:nth(*)[\d+]   = "%d";
        $raw ||= '';

        my Str sub universal( Int() $x, Int() $y ) {
            warn "universal mode must have access to tput" unless $raw;
            sprintf($raw, $y + 1, $x + 1)
        }

        return %( :&ansi, :&universal );
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
                %tput-commands{$command} = qq:x{ tput -T $term $command 1 }
            }
            default             {
                %tput-commands{$command} = qq:x{ tput -T $term $command }
            }
        }
        %human-commands{$human} = &( %tput-commands{$command} );
    }

    %attributes<columns>  = %*ENV<COLUMNS> //= columns();
    %attributes<rows>     = %*ENV<ROWS>    //= rows();
}

sub move-cursor-template( Terminal::Print::CursorProfile $profile = 'ansi' ) returns Code is export {
    %human-commands{'move-cursor'}{$profile};
}

sub move-cursor( Int $x, Int $y, Terminal::Print::CursorProfile $profile = 'ansi' ) is export {
    %human-commands{'move-cursor'}{$profile}( $x, $y );
}

sub tput( Str $command ) is export {
    die "Not a supported (or perhaps even valid) tput command"
        unless %tput-commands{$command};

    %tput-commands{$command};
}

sub print-command($command, Terminal::Print::CursorProfile $profile = 'ansi') is export {
    if $profile eq 'debug' {
        return %human-commands{$command}.comb.join(' ');
    } else {
        print %human-commands{$command};
    }
}
