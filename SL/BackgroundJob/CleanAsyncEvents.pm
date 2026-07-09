package SL::BackgroundJob::CleanAsyncEvents;

use strict;

use parent qw(SL::BackgroundJob::Base);

use SL::DB::AsyncEvent;

sub create_job {
  $_[0]->create_standard_job('20 */8 * * *'); # four times a day
}

sub run {
  my ($self) = @_;

  SL::DB::Manager::AsyncEvent->cleanup;

  return 1;
}

1;

__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::CleanAsyncEvents - Background job for cleaning the
async event tables of redacted messages and old messages

=head1 SYNOPSIS

The job is supposed to run four times a day.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Niklas Schmidt E<lt>niklas@kivitendo.deE<gt>

=cut
