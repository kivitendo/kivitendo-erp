package SL::BackgroundJob::Test;

use strict;

use parent qw(SL::BackgroundJob::Base);

use SL::System::TaskServer;

sub run {
  my ($self, $db_obj) = @_;
  my $data            = $db_obj->data_as_hash;

  $::lxdebug->message(0, "Test job ID " . $db_obj->id . " is being executed on node " . SL::System::TaskServer::node_id() . ".");

  die "Oh cruel world: " . $data->{exception} if $data->{exception};

  return exists $data->{result} ? $data->{result} : 1;
}

1;
