package Support::TestRoutines;

use Test::More;
use List::MoreUtils qw(any);

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(test_deeply);

sub test_deeply {
  my ($first, $second, $description, @ignore_keys) = @_;

  my @first_keys = keys %{$first};
  my @second_keys = keys %{$second};
  foreach my $key (@first_keys) {
    if (!any { $_ eq $key } @ignore_keys) {
      if (!any { $_ eq $key } @second_keys) {
        ok(0, $description . ": " . $key);
      }
    }
  }
  foreach my $key (@second_keys) {
    if (!any { $_ eq $key } @ignore_keys) {
      if (!any { $_ eq $key } @first_keys) {
        ok(0, $description . ": " . $key);
      } else {
        is($first->{$key}, $second->{$key}, $description . ": " . $key);
      }
    }
  }
}

