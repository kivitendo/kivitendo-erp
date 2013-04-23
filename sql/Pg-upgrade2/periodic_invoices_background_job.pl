# @tag: periodic_invoices_background_job
# @description: Hintergrundjob zum Erzeugen wiederkehrender Rechnungen
# @depends: periodic_invoices
package SL::DBUpgrade2::periodic_invoices_background_job;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::BackgroundJob::CreatePeriodicInvoices;

sub run {
  SL::BackgroundJob::CreatePeriodicInvoices->create_job;
  return 1;
}

1;
