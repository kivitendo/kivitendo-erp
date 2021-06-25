package SL::BackgroundJob::ALL;

use strict;

use SL::BackgroundJob::Base;
use SL::BackgroundJob::BackgroundJobCleanup;
use SL::BackgroundJob::CleanAuthSessions;
use SL::BackgroundJob::CleanBackgroundJobHistory;
use SL::BackgroundJob::CloseProjectsBelongingToClosedSalesOrders;
use SL::BackgroundJob::ConvertTimeRecordings;
use SL::BackgroundJob::CreatePeriodicInvoices;
use SL::BackgroundJob::CsvImport;
use SL::BackgroundJob::FailedBackgroundJobsReport;
use SL::BackgroundJob::MassDeliveryOrderPrinting;
use SL::BackgroundJob::MassRecordCreationAndPrinting;
use SL::BackgroundJob::SelfTest;
use SL::BackgroundJob::SelfTest::Base;
use SL::BackgroundJob::SelfTest::Transactions;
use SL::BackgroundJob::SetNumberRange;
use SL::BackgroundJob::ShopOrderMassTransfer;
use SL::BackgroundJob::ShopPartMassUpload;
use SL::BackgroundJob::Test;

1;
