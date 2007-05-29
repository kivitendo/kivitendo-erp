#!/usr/bin/perl -w

BEGIN {
  unshift @INC, "modules/YAML"; # Use our own version of YAML.
  push @INC, "modules";         # Only use our own versions of modules if there's no system version.
}

use SL::InstallationCheck;

$| = 1;

foreach my $module (@SL::InstallationCheck::required_modules) {
  print("Looking for $module->{name}...");
  if (!SL::InstallationCheck::module_available($module->{"name"})) {
    print(" NOT found\n" .
          "  The module '$module->{name}' is not available on your system.\n" .
          "  Please install it with the CPAN shell, e.g.\n" .
          "    perl -MCPAN -e \"install $module->{name}\"\n" .
          "  or download it from this URL and install it manually:\n" .
          "    $module->{url}\n\n");
  } else {
    print(" ok\n");
  }
}
