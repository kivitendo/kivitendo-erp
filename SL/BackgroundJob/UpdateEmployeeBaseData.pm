package SL::BackgroundJob::UpdateEmployeeBaseData;

use strict;
use utf8;

use parent qw(SL::BackgroundJob::Base);

use SL::DB::BackgroundJob;
use SL::DB::Employee;

sub run {
  my ($self, $db_obj, $end_date) = @_;

  SL::DB::Manager::Employee->update_entries_for_authorized_users;

  return 1;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::BackgroundJob::UpdateEmployeeBaseData - Background job for copying
user data from the auth database to the "employee" table

=head1 OVERVIEW

When authentication via HTTP headers is active the regular login
routine is skipped. That routine would normally copy values from the
auth database to the employee table. This job can be run regularly to
copy the same values.

The job is enabled & set to run every five minutes by default.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet.deE<gt>

=cut
