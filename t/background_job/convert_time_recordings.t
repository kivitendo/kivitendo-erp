use Test::More tests => 7;

use strict;

use lib 't';
use utf8;

use Support::TestSetup;
use Test::Exception;
use DateTime;

use SL::DB::BackgroundJob;

use_ok 'SL::BackgroundJob::ConvertTimeRecordings';

use SL::Dev::ALL qw(:ALL);

Support::TestSetup::login();

sub clear_up {
  foreach (qw(OrderItem Order DeliveryOrder TimeRecording Project Part Customer RecordLink)) {
    "SL::DB::Manager::${_}"->delete_all(all => 1);
  }
  SL::DB::Manager::Employee->delete_all(where => [ '!login' => 'unittests' ]);
};

########################################

$::myconfig{numberformat} = '1000.00';
my $old_locale = $::locale;
# set locale to en so we can match errors
$::locale = Locale->new('en');


clear_up();

my $part     = new_service(partnumber => 'Serv1', unit => 'Std')->save;
my $project  = create_project(projectnumber => 'p1', description => 'Project 1');
my $customer = new_customer()->save;

# sales order with globalproject_id
my $sales_order = create_sales_order(
  save             => 1,
  customer         => $customer,
  globalproject    => $project,
  taxincluded      => 0,
  orderitems       => [ create_order_item(part => $part, qty => 3, sellprice => 70), ]
);

my @time_recordings;
push @time_recordings, new_time_recording(
  start_time => DateTime->new(year => 2021, month =>  4, day => 19, hour => 10, minute =>  5),
  end_time   => DateTime->new(year => 2021, month =>  4, day => 19, hour => 11, minute => 10),
  customer   => $customer,
  project    => $project,
  part       => $part,
)->save;
push @time_recordings, new_time_recording(
  start_time => DateTime->new(year => 2021, month =>  4, day => 19, hour => 12, minute =>  5),
  end_time   => DateTime->new(year => 2021, month =>  4, day => 19, hour => 14, minute => 10),
  customer   => $customer,
  project    => $project,
  part       => $part,
)->save;

# two time recordings, one order linked with project_id
my %data   = (
  link_project => 1,
  project_id   => $project->id,
  from_date    => '01.04.2021',
  to_date      => '30.04.2021',
);
my $db_obj = SL::DB::BackgroundJob->new();
$db_obj->set_data(%data);
my $job    = SL::BackgroundJob::ConvertTimeRecordings->new;
my $ret    = $job->run($db_obj);

is_deeply($job->{job_errors}, [], 'no errros');
like($ret, qr{^Number of delivery orders created: 1}, 'one delivery order created');

my $linked_dos = $sales_order->linked_records(to => 'DeliveryOrder');
is(scalar @$linked_dos, 1, 'one delivery order linked to order');
is($linked_dos->[0]->globalproject_id, $sales_order->globalproject_id, 'project ids match');

my $linked_items = $sales_order->items->[0]->linked_records(to => 'DeliveryOrderItem');
is(scalar @$linked_items, 1, 'one delivery order item linked to order item');
is($linked_items->[0]->qty*1, 3.16, 'qty in delivery order');

clear_up();

$::locale = $old_locale;

1;

#####
# vim: ft=perl
# set emacs to perl mode
# Local Variables:
# mode: perl
# End:
