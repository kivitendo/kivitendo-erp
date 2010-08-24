#!/usr/bin/perl -w

BEGIN {
  unshift @INC, "modules/override"; # Use our own versions of various modules (e.g. YAML).
  push    @INC, "modules/fallback"; # Only use our own versions of modules if there's no system version.
}

use SL::InstallationCheck;

$| = 1;

foreach my $module (@SL::InstallationCheck::required_modules) {
  if ($module->{version}) {
    print("Looking for $module->{name} $module->{version}...");
  } else {
    print("Looking for $module->{name}...");
  }
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

foreach my $module (@SL::InstallationCheck::optional_modules) {
  print("Looking for $module->{name} (optional)...");
  if (!SL::InstallationCheck::module_available($module->{"name"})) {
    print(" NOT found\n" .
          "  The module '$module->{name}' is not available on your system.\n" .
          "  While it is not strictly needed it provides extra functionality\n" .
          "  and should be installed.\n" .
          "  You can install it with the CPAN shell, e.g.\n" .
          "    perl -MCPAN -e \"install $module->{name}\"\n" .
          "  or download it from this URL and install it manually:\n" .
          "    $module->{url}\n\n");
  } else {
    print(" ok\n");
  }
}
