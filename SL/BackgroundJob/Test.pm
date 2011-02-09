package SL::BackgroundJob::Test;

use strict;

use parent qw(SL::BackgroundJob::Base);

sub run {
  my $self   = shift;
  my $db_obj = shift;

  $::lxdebug->message(0, "Test job is being executed.");
}

1;
