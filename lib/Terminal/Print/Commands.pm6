unit module Terminal::Print::Commands;

=begin pod
=title Terminal::Print::Commands

=head1 Synopsis

This module essentially just creates a hash of escape sequences for doing various
things, along with a few exported sub-routines to make interacting with this hash
a bit nicer.

=end pod

our %human-command-names;
our %human-commands;
our %tput-commands;
our %attributes;
our %attribute-values;

our @fg_colors = [ <black red green yellow blue magenta cyan white default> ];
our @bg_colors = [ <on_black on_red on_green on_yellow on_blue on_magenta on_cyan on_white on_default> ];
our @styles    = [ <reset bold underline inverse> ];

subset Terminal::Print::CursorProfile is export where * ~~ / ^('ansi' | 'universal')$ /;

# we can add more, but there is a qq:x call so whitelist is the way to go.
constant @valid-terminals = < xterm xterm-256color vt100 screen screen-256color >;

my %tput-cache;
BEGIN {
    die 'Cannot use Terminal::Print without `tput` (usually provided by `ncurses`)'
        unless q:x{ which tput };

    my @caps = << clear smcup rmcup sc rc civis cnorm "cup 13 13" "ech 1" >>;

    for @valid-terminals -> $term {
        for @caps -> $cap {
            %tput-cache{$term}{$cap.words[0]} = qq:x{ tput -T $term $cap };
        }
    }
}

INIT {
    my $term = %*ENV<TERM> || 'xterm';
    my %cached := %tput-cache{$term};

    die "Please update @valid-terminals with your desired TERM ('$term', is it?) and submit a PR if it works"
        unless %cached;

    my sub build-cursor-to-template {

        my Str sub ansi( Int() $x,  Int() $y ) {
            "\e[{$y+1};{$x+1}H";
        }

        my $raw = %cached<cup>;
        $raw ~~ /^ (.*?) (\d+) (\D+) (\d+) (\D+) $/
            or warn "universal mode must have access to tput";

        my ($pre, $mid, $post) = $0, $2, $4;

        my Str sub universal( Int() $x, Int() $y ) {
            $pre ~ ($y + 1) ~ $mid ~ ($x + 1) ~ $post;
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
            default             {
                %tput-commands{$command} = %cached{$command};
            }
        }
        %human-commands{$human} = %tput-commands{$command};
    }

    %attributes<columns>  = %*ENV<COLUMNS> //= columns();
    %attributes<rows>     = %*ENV<ROWS>    //= rows();
}

sub columns is export   { q:x{ tput cols  } .chomp }
sub rows is export      { q:x{ tput lines } .chomp }

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
