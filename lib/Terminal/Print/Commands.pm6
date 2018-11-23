module Terminal::Print::Commands
{

=begin pod
=title Terminal::Print::Commands

=head1 Synopsis

This module essentially just creates a hash of escape sequences for doing various
things, along with a few exported sub-routines to make interacting with this hash
a bit nicer.

=end pod

use File::Which;

our %human-command-names;
our %human-commands;
our %tput-commands;

our @fg_colors = [ <black red green yellow blue magenta cyan white default> ];
our @bg_colors = [ <on_black on_red on_green on_yellow on_blue on_magenta on_cyan on_white on_default> ];
our @styles    = [ <reset bold underline inverse> ];

subset Terminal::Print::CursorProfile is export where * ~~ / ^('ansi' | 'universal')$ /;

# we can add more, but there is a qq:x call so whitelist is the way to go.
constant @valid-terminals = < xterm xterm-256color vt100 linux screen screen-256color
                              screen.xterm-256color tmux tmux-256color
                              rxvt-unicode-256color >;

class X::TputCapaMissing is Exception
{
	has Str $.term;
	has Str $.capa;
	method message() { "Tried to use an undefined capability '$.capa' of the terminal type '$.term'." }
}

my %tput-cache;
BEGIN {
    die 'Cannot use Terminal::Print without `tput` (usually provided by `ncurses`)'
        unless which('tput');

    my @caps = << clear smcup rmcup sc rc civis cnorm "cup 13 13" "ech 1" >>;

    sub query-cap(Str $term, Str $cap)
    {
	    my $proc = run 'tput', '-T', $term, $cap, :out;
	    return $proc.out.slurp if $proc.exitcode == 0;
	    return query-cap($term, "clear") if $cap ~~ /^ <[sr]>mcup $/;
	    # TODO: Replace the -1 with a Failure.new(...) once the compiler can cope with it correctly.
	    -1; # We use the "-1" as a poor man's Failure (we die whenever we try to use it)
    }

    for @valid-terminals -> $term {
        for @caps -> $cap {
            %tput-cache{$term}{$cap.words[0]} = query-cap($term, $cap.words[0]);
        }
    }
}

my $term = %*ENV<TERM> || 'xterm';
die "Please update @valid-terminals with your desired TERM ('$term', is it?) and submit a PR if it works" unless %tput-cache{$term}:exists;
my %cached = %tput-cache{$term};

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
            %tput-commands{$command} = %( :&ansi, :&universal );
        }
        default             {
            %tput-commands{$command} = %cached{$command};
        }
    }
    %human-commands{$human} = %tput-commands{$command};
}

sub columns is export { q:x{ tput cols  } .chomp.Int }
sub rows    is export { q:x{ tput lines } .chomp.Int }

sub move-cursor-template( Terminal::Print::CursorProfile $profile = 'ansi' ) returns Code is export {
    $profile eq 'ansi' ?? &ansi !! &universal
}

sub move-cursor( Int $x, Int $y, Terminal::Print::CursorProfile $profile = 'ansi' ) is export {
    ($profile eq 'ansi' ?? &ansi !! &universal)( $x, $y )
}

sub tput( Str $command ) is export {
    die "Not a supported (or perhaps even valid) tput command"
        unless %tput-commands{$command};

    die X::TputCapaMissing.new(term => $term, capa => $command) if %tput-commands{$command} ~~ -1;
    %tput-commands{$command};
}

sub print-command($command, Terminal::Print::CursorProfile $profile = 'ansi') is export {
    die X::TputCapaMissing.new(term => $term, capa => %human-command-names{$command}) if %human-commands{$command} ~~ -1;
    if $profile eq 'debug' {
        return %human-commands{$command}.comb.join(' ');
    } else {
        print %human-commands{$command};
    }
}

CATCH
{
	when X::TputCapaMissing
	{
		# If we're just dying because of a missing capa, we need to clean up as much as we can
		# (with some other capa's potentially missing) and ensure that the error message is not cleared.
		my ($clear, $rmcup, $cnorm) = tput("clear"), tput("rmcup"), tput("cnorm");
		print $clear if $clear !~~ -1; 
		print $rmcup if $rmcup !~~ -1;
		print $cnorm if $cnorm !~~ -1;

		.rethrow; # we cleared the screen meanwhile, so we print the exception again
	}
}

}
