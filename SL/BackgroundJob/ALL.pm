package SL::BackgroundJob::ALL;

use strict;

use SL::BackgroundJob::Base;
use SL::BackgroundJob::BackgroundJobCleanup;
use SL::BackgroundJob::CleanBackgroundJobHistory;
use SL::BackgroundJob::CloseProjectsBelongingToClosedSalesOrders;
use SL::BackgroundJob::CreatePeriodicInvoices;
use SL::BackgroundJob::FailedBackgroundJobsReport;

1;
