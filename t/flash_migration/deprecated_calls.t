use strict;

use lib 't';

use Support::Files;
use Support::TestSetup;

use File::Spec;
use File::Slurp;
use Template;
use Template::Provider;
use Test::More;

my @deprecated_calls_perl = (
  qr/render_flash/,
  qr/flash_detail/,
  qr{common/flash},
  qr/flash (?:_later)? \( \s* ' (?: error | warning | information ) ' \s* , \s* \@ /x,
);

my @deprecated_calls_js = (
  qr/kivi\.display_flash/,
  qr/kivi\.clear_flash/,
);

for my $file (@Support::Files::files) {
  open my $fh, '<', $file or die "can't open $file";

  while (my $line = <$fh>) {
    for my $re (@deprecated_calls_perl) {
      if ($line =~ $re) {
        ok 0, "$file contains '$&', most likely due to incomplete merge of the layout flash feature. Consult the documentation in this test script";
      }
    }
  }

  ok 1, $file;
}

for my $file (@Support::Files::javascript_files) {
  next if $file eq 'js/kivi.Flash.js';

  open my $fh, '<', $file or die "can't open $file";

  while (my $line = <$fh>) {
    for my $re (@deprecated_calls_js) {
      if ($line =~ $re) {
        TODO: { local $TODO = 'clean up compatibility kivi.display_flash and kivi.clear_flash';
          ok 0, "$file contains '$&', most likely due to incomplete merge of the layout flash feature. Consult the documentation in this test script";
        }
      }
    }
  }

  ok 1, $file;
}

done_testing();


__END__

=encoding utf-8

=head1 NAME

t/flash_migration&deprecated_calls.t

=head1 DESCRIPTION

Okay, if this script triggers, this is what needs to be done:

In Javascript:

- all javascript calls to "kivi.display_flash" and "kivi.clear_flash" need to
  be redirected to "kivi.Flash"
- kivi.display_flash_details doesn't exist any more, instead details can now be
  passed as a third argument to kivi.Flash.display_flash

In html:

- There is no common/flash.html template any more, since the layout handles
  that now. Any attempt to render it needs to be removed.

In Perl:

- flash_detail doesn't exist any more, instead flash() and flash_later() take a
  third argument for details
- render_flash doesn't exist anymore and is now handled by the layout.
- flash('error', @errrs) and similar must be called in a loop: flash('error', $_) for @errors

=cut
