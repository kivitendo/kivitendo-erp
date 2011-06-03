#!/usr/bin/perl -w

use strict;

BEGIN {
  unshift @INC, "modules/override"; # Use our own versions of various modules (e.g. YAML).
  push    @INC, "modules/fallback"; # Only use our own versions of modules if there's no system version.
}

use SL::InstallationCheck;

$| = 1;

check($_, 0) for @SL::InstallationCheck::required_modules;
check($_, 1) for @SL::InstallationCheck::optional_modules;

sub check {
  my ($module, $optional) = @_;

  print "Looking for $module->{fullname}...";
  my $res = SL::InstallationCheck::module_available($module->{"name"}, $module->{version});
  print $res ? '' : " NOT", " ok\n";

  return if $res;

  my $needed_text = $optional
    ? 'It is OPTIONAL for Lx-Office but recommended for improved functionality.'
    : 'It is NEEDED by Lx-Office and must be installed.';

  my @source_texts = source_texts($module);
  local $" = $/;
  print STDERR <<EOL;
+-----------------------------------------------------------------------------+
  $module->{fullname} could not be loaded.

  This module is either too old or not available on your system.
  $needed_text

  Here are some ideas how to get it:

@source_texts
+-----------------------------------------------------------------------------+
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
