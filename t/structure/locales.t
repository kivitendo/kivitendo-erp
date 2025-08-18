use Test::More;

use strict;
use File::Spec qw();

foreach my $dir (glob('locale/*')) {
  next if ! -d $dir;

  my $locale;
  (undef, undef, $locale) = File::Spec->splitpath($dir);
  my $out = `./scripts/locales.pl -r $locale`;

  ok(0 eq ($? >> 8), "'$locale' is up to date");

  my $any_errors   = $out =~ m{^E:}m;
  my $any_warnings = $out =~ m{^W:}m;

  ok(!$any_errors,   "run for '$locale' has no errors");
  ok(!$any_warnings, "run for '$locale' has no warnings");
}

done_testing();

1;

#####
# vim: ft=perl
# set emacs to perl mode
# Local Variables:
# mode: perl
# End:
