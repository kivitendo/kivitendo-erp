package SL::BackgroundJob::LSUpdateEmployeeBaseData;

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
