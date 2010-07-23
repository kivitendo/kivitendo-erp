package Term::ReadLine::Perl::Bind;
### From http://www.perlmonks.org/?node_id=751611
### Posted by repellant (http://www.perlmonks.org/?node_id=665462)

### Set readline bindkeys for common terminals

use warnings;
use strict;

BEGIN {
    require Exporter;
    *import = \&Exporter::import; # just inherit import() only

    our $VERSION   = 1.001;
    our @EXPORT_OK = qw(rl_bind_action $action2key $key2codes);
}

use Term::ReadLine;

# http://cpansearch.perl.org/src/ILYAZ/Term-ReadLine-Perl-1.0302/ReadLine
my $got_rl_perl;

BEGIN {
    $got_rl_perl = eval {
        require Term::ReadLine::Perl;
        require Term::ReadLine::readline;
    };
}

# bindkey actions for terminals
our $action2key = {
    Complete               => "Tab",
    PossibleCompletions    => "C-d",
    QuotedInsert           => "C-v",

    ToggleInsertMode       => "Insert",
    DeleteChar             => "Del",
    UpcaseWord             => "PageUp",
    DownCaseWord           => "PageDown",
    BeginningOfLine        => "Home",
    EndOfLine              => "End",

    ReverseSearchHistory   => "C-Up",
    ForwardSearchHistory   => "C-Down",
    ForwardWord            => "C-Right",
    BackwardWord           => "C-Left",

    HistorySearchBackward  => "S-Up",
    HistorySearchForward   => "S-Down",
    KillWord               => "S-Right",
    BackwardKillWord       => "S-Left",

    Yank                   => "A-Down", # paste
    KillLine               => "A-Right",
    BackwardKillLine       => "A-Left",
};

our $key2codes = {
    "Tab"                  => [ "TAB", ],
    "C-d"                  => [ "C-d", ],
    "C-v"                  => [ "C-v", ],

    "Insert"               => [ qq("\e[2~"), qq("\e[2z"), qq("\e[L"), ],
    "Del"                  => [ qq("\e[3~"), ],
    "PageUp"               => [ qq("\e[5~"), qq("\e[5z"), qq("\e[I"), ],
    "PageDown"             => [ qq("\e[6~"), qq("\e[6z"), qq("\e[G"), ],
    "Home"                 => [ qq("\e[7~"), qq("\e[1~"), qq("\e[H"), ],
    "End"                  => [ qq("\e[8~"), qq("\e[4~"), qq("\e[F"), ],

    "C-Up"                 => [ qq("\eOa"), qq("\eOA"), qq("\e[1;5A"), ],
    "C-Down"               => [ qq("\eOb"), qq("\eOB"), qq("\e[1;5B"), ],
    "C-Right"              => [ qq("\eOc"), qq("\eOC"), qq("\e[1;5C"), ],
    "C-Left"               => [ qq("\eOd"), qq("\eOD"), qq("\e[1;5D"), ],

    "S-Up"                 => [ qq("\e[a"), qq("\e[1;2A"), ],
    "S-Down"               => [ qq("\e[b"), qq("\e[1;2B"), ],
    "S-Right"              => [ qq("\e[c"), qq("\e[1;2C"), ],
    "S-Left"               => [ qq("\e[d"), qq("\e[1;2D"), ],

    "A-Down"               => [ qq("\e\e[B"), qq("\e[1;3B"), ],
    "A-Right"              => [ qq("\e\e[C"), qq("\e[1;3C"), ],
    "A-Left"               => [ qq("\e\e[D"), qq("\e[1;3D"), ],
};

# warn if any keycode is clobbered
our $debug = 0;

# check ref type
sub _is_array { ref($_[0]) && eval { @{ $_[0] } or 1 } }
sub _is_hash  { ref($_[0]) && eval { %{ $_[0] } or 1 } }

# set bindkey actions for each terminal
my %code2action;

sub rl_bind_action {
    if ($got_rl_perl)
    {
        my $a2k = shift();
        return () unless _is_hash($a2k);

        while (my ($action, $bindkey) = each %{ $a2k })
        {
            # use default keycodes if none provided
            my @keycodes = @_ ? @_ : $key2codes;

            for my $k2c (@keycodes)
            {
                next unless _is_hash($k2c);

                my $codes = $k2c->{$bindkey};
                next unless defined($codes);
                $codes = [ $codes ] unless _is_array($codes);

                for my $code (@{ $codes })
                {
                    if ($debug && $code2action{$code})
                    {
                        my $hexcode = $code;
                        $hexcode =~ s/^"(.*)"$/$1/;
                        $hexcode = join(" ", map { uc } unpack("(H2)*", $hexcode));

                        warn <<"EOT";
rl_bind_action(): re-binding keycode [ $hexcode ] from '$code2action{$code}' to '$action'
EOT
                    }

                    readline::rl_bind($code, $action);
                    $code2action{$code} = $action;
                }
            }
        }
    }
    else
    {
        warn <<"EOT";
rl_bind_action(): Term::ReadLine::Perl is not available. No bindkeys were set.
EOT
    }

    return $got_rl_perl;
}

# default bind
rl_bind_action($action2key);

# bind Delete key for 'xterm'
if ($got_rl_perl && defined($ENV{TERM}) && $ENV{TERM} =~ /xterm/)
{
    rl_bind_action($action2key, +{ "Del" => qq("\x7F") });
}

'Term::ReadLine::Perl::Bind';

