use Test::More tests => 4;

use lib 't';

use Support::TestSetup;

use_ok 'SL::BackgroundJob::Base';

my @expected_known_job_classes = qw(BackgroundJobCleanup CleanBackgroundJobHistory CreatePeriodicInvoices CsvImport SelfTest Test);
is_deeply [ SL::BackgroundJob::Base->get_known_job_classes ], \@expected_known_job_classes, 'get_known_job_classes called as class method';

my $job = new_ok 'SL::BackgroundJob::Base';
is_deeply [ $job->get_known_job_classes ], \@expected_known_job_classes, 'get_known_job_classes called as instance method';
