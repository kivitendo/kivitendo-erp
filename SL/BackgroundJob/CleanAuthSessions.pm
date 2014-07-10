package SL::BackgroundJob::CleanAuthSessions;

use strict;

use parent qw(SL::BackgroundJob::Base);

sub create_job {
  $_[0]->create_standard_job('30 6 * * *'); # daily at 6:30 am
}

sub run {
  my ($self) = @_;

  $::auth->expire_sessions;

  return 1;
}

1;

__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::CleanAuthSessions - Background job for cleaning the
session tables of expired entries

=head1 SYNOPSIS

This background job deletes all entries for expired sessions from the
tables C<auth.session> and C<auth.session_content>. It will also
delete all files associated with that session (see
L<SL::SessionFile>).

The job is supposed to run once a day.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
