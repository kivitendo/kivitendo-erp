package SL::BackgroundJob::Test;

use strict;

use parent qw(SL::BackgroundJob::Base);

sub run {
  my ($self, $db_obj) = @_;
  my $data            = $db_obj->data_as_hash;

  $::lxdebug->message(0, "Test job is being executed.");

  die "Oh cruel world: " . $data->{exception} if $data->{exception};

  return exists $data->{result} ? $data->{result} : 1;
}

1;
