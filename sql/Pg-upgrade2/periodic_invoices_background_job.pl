# @tag: periodic_invoices_background_job
# @description: Hintergrundjob zum Erzeugen wiederkehrender Rechnungen
# @depends: periodic_invoices
# @charset: utf-8

use strict;

use SL::BackgroundJob::CreatePeriodicInvoices;

SL::BackgroundJob::CreatePeriodicInvoices->create_job;

1;
