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

GetOptions(
  "verbose"   => \ my $v,
  "all"       => \ my $a,
  "optional!" => \ my $o,
  "devel!"    => \ my $d,
  "required!" => \ ( my $r = 1 ),
  "help"      => sub { pod2usage(-verbose => 2) },
  "color"     => \ ( my $c = 1 ),
);

$d = $r = $o = 1 if $a;

$| = 1;

if ($r) {
  check($_, required => 1) for @SL::InstallationCheck::required_modules;
}
if ($o) {
  check($_, optional => 1) for @SL::InstallationCheck::optional_modules;
}
if ($d) {
  check($_, devel => 1) for @SL::InstallationCheck::developer_modules;
}

sub check {
  my ($module, %role) = @_;

  my $line = "Looking for $module->{fullname}";
  print $line;
  my $res = SL::InstallationCheck::module_available($module->{"name"}, $module->{version});
  print dot_pad(length $line, $res ? 2 : 6, $res ? mycolor("ok", 'green') : mycolor("NOT ok", 'red')), $/;

  return if $res;

  my $needed_text =
      $role{optional} ? 'It is OPTIONAL for Lx-Office but RECOMMENDED for improved functionality.'
    : $role{required} ? 'It is NEEDED by Lx-Office and must be installed.'
    : $role{devel}    ? 'It is OPTIONAL for Lx-Office and only useful for developers.'
    :                   'It is not listed as a dependancy yet. Please tell this the developers.';

  my @source_texts = source_texts($module);
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

sub source_texts {
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

sub dot_pad {
  my ($s, $l, $text) = @_;
  print " ";
  print '.' x (80 - $s - 2 - $l);
  print " ";
  return $text;
}

1;

__END__

=encoding UTF-8

=head1 NAME

scripts/installation_check.pl - check Lx-Office dependancies

=head1 SYNOPSIS

  scripts/installation_check.pl [OPTION]

=head1 DESCRIPTION

List all modules needed by Lx-Office, probes for them, and warns if one is not available.

=over 4

=item C<-a, --all>

Probe for all modules.

=item C<-c, --color>

Color output. Default on.

=item C<-d, --devel>

Probe for developer dependancies. (Used for console  and tags file)

=item C<-h, --help>

Display this help.

=item C<-o, --optional>

Probe for optional modules.

=item C<-r, --required>

Probe for required modules (default).

=item C<-v. --verbose>

Print additional info for modules that are missing

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

=cut
