use Test::More;
use Test::Exception;

use strict;

use lib 't';
use utf8;

use Data::Dumper;
use Support::TestSetup;
use File::Slurp;
use IO::Dir;

my %dir;
tie %dir, 'IO::Dir', 'SL/DB';
my @pms = grep { m/\.pm$/ } keys %dir;

foreach my $pm (sort @pms) {
  my $content = read_file("SL/DB/${pm}");
  next unless $content =~ m/__PACKAGE__->meta->add_relationships?\((.+?)\);/s;
  my $code = $1;

  my @not_existing;
  while ($code =~ m/\b(?:map_)?class\s*=>\s*['"]SL::DB::(.+?)['"]/g) {
    push @not_existing, $1 unless -f "SL/DB/${1}.pm";
  }

  if (@not_existing) {
    fail("$pm: Non-existing relationship model(s) " . join(' ', @not_existing));
  } else {
    pass("$pm: all relationship model(s) exist");
  }
}

# print Dumper(\@pms);


done_testing();
