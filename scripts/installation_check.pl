#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Pod::Usage;
use Term::ANSIColor;

BEGIN {
  unshift @INC, "modules/override"; # Use our own versions of various modules (e.g. YAML).
  push    @INC, "modules/fallback"; # Only use our own versions of modules if there's no system version.
}

use SL::InstallationCheck;

my %check;
Getopt::Long::Configure ("bundling");
GetOptions(
  "v|verbose"   => \ my $v,
  "a|all"       => \ $check{a},
  "o|optional!" => \ $check{o},
  "d|devel!"    => \ $check{d},
  "r|required!" => \ $check{r},
  "h|help"      => sub { pod2usage(-verbose => 2) },
  "c|color!"    => \ ( my $c = 1 ),
);

# if notihing is requested check "required"
$check{r} = 1 unless defined $check{a} ||
                     defined $check{o} ||
                     defined $check{d};

if ($check{a}) {
  foreach my $check (keys %check) {
    $check{$check} = 1 unless defined $check{$check};
  }
}


$| = 1;

if ($check{r}) {
  check_module($_, required => 1) for @SL::InstallationCheck::required_modules;
}
if ($check{o}) {
  check_module($_, optional => 1) for @SL::InstallationCheck::optional_modules;
}
if ($check{d}) {
  check_module($_, devel => 1) for @SL::InstallationCheck::developer_modules;
}

sub check_module {
  my ($module, %role) = @_;

  my $line = "Looking for $module->{fullname}";
  my $res = SL::InstallationCheck::module_available($module->{"name"}, $module->{version});
  print_result($line, $res);

  return if $res;

  my $needed_text =
      $role{optional} ? 'It is OPTIONAL for Lx-Office but RECOMMENDED for improved functionality.'
    : $role{required} ? 'It is NEEDED by Lx-Office and must be installed.'
    : $role{devel}    ? 'It is OPTIONAL for Lx-Office and only useful for developers.'
    :                   'It is not listed as a dependancy yet. Please tell this the developers.';

  my @source_texts = module_source_texts($module);
  local $" = $/;
  print STDERR <<EOL if $v;
+------------------------------------------------------------------------------+
  $module->{fullname} could not be loaded.

  This module is either too old or not available on your system.
  $needed_text

  Here are some ideas how to get it:

@source_texts
+------------------------------------------------------------------------------+
EOL
}

sub module_source_texts {
  my ($module) = @_;
  my @texts;
  push @texts, <<EOL;
  - You can get it from CPAN:
      perl -MCPAN -e "install $module->{name}"
EOL
  push @texts, <<EOL if $module->{url};
  - You can download it from this URL and install it manually:
      $module->{url}
EOL
  push @texts, <<EOL if $module->{debian};
  - On Debian, Ubuntu and other distros you can install it with apt-get:
      sudo apt-get install $module->{debian}
    Note: These may be out of date as well if your system is old.
EOL
 # TODO: SuSE and Fedora packaging. Windows packaging.

  return @texts;
}

sub mycolor {
  return $_[0] unless $c;
  return colored(@_);
}

sub print_result {
  my ($test, $exit) = @_;
  print $test, " ", ('.' x (72 - length $test));
  print $exit ? '.... '. mycolor('ok', 'green') : ' '. mycolor('NOT ok', 'red');
  print "\n";
  return;
}

1;

__END__

=encoding UTF-8

=head1 NAME

scripts/installation_check.pl - check Lx-Office dependancies

=head1 SYNOPSIS

  scripts/installation_check.pl [OPTION]

=head1 DESCRIPTION

Check dependencys. List all perl modules needed by Lx-Office, probes for them,
and warns if one is not available.

=head1 OPTIONS

=over 4

=item C<-a, --all>

Probe for all perl modules and all LaTeX master templates.

=item C<-c, --color>

Color output. Default on.

=item C<--no-color>

No color output. Helpful to avoid terminal escape problems.

=item C<-d, --devel>

Probe for perl developer dependancies. (Used for console  and tags file)

=item C<--no-devel>

Dont't probe for perl developer dependancies. (Usefull in combination with --all)

=item C<-h, --help>

Display this help.

=item C<-o, --optional>

Probe for optional modules.

=item C<--no-optional>

Dont't probe for optional perl modules. (Usefull in combination with --all)

=item C<-r, --required>

Probe for required perl modules (default).

=item C<--no-required>

Dont't probe for required perl modules. (Usefull in combination with --all)

=item C<-v. --verbose>

Print additional info for missing dependancies

=back

=head1 BUGS, CAVEATS and TODO

=over 4

=item *

Fedora packages not listed yet.

=item *

Not possible yet to generate a combined cpan/apt-get string to install all needed.

=item *

Not able to handle devel cpan modules yet.

=item *

Version requirements not fully tested yet.

=back

=head1 AUTHOR

  Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>
  Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>
  Wulf Coulmann E<lt>wulf@coulmann.deE<gt>

=cut
