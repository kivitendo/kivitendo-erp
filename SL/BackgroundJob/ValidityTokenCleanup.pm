package SL::BackgroundJob::ValidityTokenCleanup;

use strict;

use parent qw(SL::BackgroundJob::Base);

use SL::DB::ValidityToken;

sub create_job {
  $_[0]->create_standard_job('0 3 * * *'); # daily
}

sub run {
  SL::DB::Manager::ValidityToken->cleanup;

  return 1;
}

1;

__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::ValidityTokenCleanup - Background job for
deleting all expired validity tokens

=cut
