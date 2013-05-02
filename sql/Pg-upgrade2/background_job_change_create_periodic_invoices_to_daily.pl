# @tag: background_job_change_create_periodic_invoices_to_daily
# @description: Hintergrundjob zum Erzeugen periodischer Rechnungen täglich ausführen
# @depends: release_3_0_0
package SL::DBUpgrade2::background_job_change_create_periodic_invoices_to_daily;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DB::BackgroundJob;

sub run {
  my ($self) = @_;

  foreach my $job (@{ SL::DB::Manager::BackgroundJob->get_all(where => [ package_name => 'CreatePeriodicInvoices' ]) }) {
    $job->update_attributes(cron_spec => '0 3 * * *', next_run_at => undef);
  }

  return 1;
}

1;
