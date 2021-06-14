use Test::More tests => 52;

use strict;

use lib 't';
use utf8;

use Support::TestSetup;
use Test::Exception;
use DateTime;
use Rose::DB::Object::Helpers qw(forget_related);

use SL::DB::BackgroundJob;
use SL::DB::DeliveryOrder;

use_ok 'SL::BackgroundJob::ConvertTimeRecordings';

use SL::Dev::ALL qw(:ALL);

Support::TestSetup::login();

sub clear_up {
  foreach (qw(TimeRecording OrderItem Order DeliveryOrder Project Part Customer RecordLink)) {
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

########################################
# two time recordings, one order linked with project_id in time recording entry
########################################
my $part     = new_service(partnumber => 'Serv1', unit => 'Std')->save;
my $project  = create_project(projectnumber => 'p1', description => 'Project 1');
my $customer = new_customer()->save;
$::form->{type} = 'sales_order';

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
  end_time   => DateTime->new(year => 2021, month =>  4, day => 19, hour => 11, minute =>  5),
  customer   => $customer,
  project    => $project,
  part       => $part,
)->save;
push @time_recordings, new_time_recording(
  start_time => DateTime->new(year => 2021, month =>  4, day => 19, hour => 12, minute =>  5),
  end_time   => DateTime->new(year => 2021, month =>  4, day => 19, hour => 14, minute =>  5),
  customer   => $customer,
  project    => $project,
  part       => $part,
)->save;

my %data   = (
  link_order => 1,
  from_date  => '01.01.2021',
  to_date    => '30.04.2021',
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
is($linked_items->[0]->qty*1, 3, 'qty in delivery order');
is($linked_items->[0]->base_qty*1, 3, 'base_qty in delivery order');

# reload order and orderitems to get changes to deliverd and ship
Rose::DB::Object::Helpers::forget_related($sales_order, 'orderitems');
$sales_order->load;

ok($sales_order->delivered, 'related order is delivered');
is($sales_order->items->[0]->ship*1, 3, 'ship in related order');

clear_up();


########################################
# two time recordings, one order linked with project_id in time recording entry
# unit in order is 'min', but part is 'Std'
########################################
$part     = new_service(partnumber => 'Serv1', unit => 'Std')->save;
$project  = create_project(projectnumber => 'p1', description => 'Project 1');
$customer = new_customer()->save;

$sales_order = create_sales_order(
  save             => 1,
  customer         => $customer,
  globalproject    => $project,
  taxincluded      => 0,
  orderitems       => [ create_order_item(part => $part, qty => 180, unit => 'min', sellprice => 70), ]
);

@time_recordings = ();
push @time_recordings, new_time_recording(
  start_time => DateTime->new(year => 2021, month =>  4, day => 19, hour => 10, minute => 10),
  end_time   => DateTime->new(year => 2021, month =>  4, day => 19, hour => 11, minute => 10),
  customer   => $customer,
  project    => $project,
  part       => $part,
)->save;
push @time_recordings, new_time_recording(
  start_time => DateTime->new(year => 2021, month =>  4, day => 19, hour => 12, minute => 10),
  end_time   => DateTime->new(year => 2021, month =>  4, day => 19, hour => 14, minute => 10),
  customer   => $customer,
  project    => $project,
  part       => $part,
)->save;

%data = (
  link_order => 1,
  from_date  => '01.04.2021',
  to_date    => '30.04.2021',
);
$db_obj = SL::DB::BackgroundJob->new();
$db_obj->set_data(%data);
$job    = SL::BackgroundJob::ConvertTimeRecordings->new;
$ret    = $job->run($db_obj);

$linked_dos = $sales_order->linked_records(to => 'DeliveryOrder');
$linked_items = $sales_order->items->[0]->linked_records(to => 'DeliveryOrderItem');
is($linked_items->[0]->qty*1, 3, 'different units: qty in delivery order');
is($linked_items->[0]->base_qty*1, 3, 'different units: base_qty in delivery order');

# reload order and orderitems to get changes to deliverd and ship
Rose::DB::Object::Helpers::forget_related($sales_order, 'orderitems');
$sales_order->load;

ok($sales_order->delivered, 'different units: related order is delivered');
is($sales_order->items->[0]->ship*1, 180, 'different units: ship in related order');

clear_up();


########################################
# two time recordings, one order linked with project_id in time recording entry
# unit in order is 'Std', but part is 'min'
########################################
$part     = new_service(partnumber => 'Serv1', unit => 'min')->save;
$project  = create_project(projectnumber => 'p1', description => 'Project 1');
$customer = new_customer()->save;

$sales_order = create_sales_order(
  save             => 1,
  customer         => $customer,
  globalproject    => $project,
  taxincluded      => 0,
  orderitems       => [ create_order_item(part => $part, qty => 2, unit => 'Std', sellprice => 70), ]
);

@time_recordings = ();
push @time_recordings, new_time_recording(
  start_time => DateTime->new(year => 2021, month =>  4, day => 19, hour => 10, minute => 10),
  end_time   => DateTime->new(year => 2021, month =>  4, day => 19, hour => 11, minute => 10),
  customer   => $customer,
  project    => $project,
  part       => $part,
)->save;
push @time_recordings, new_time_recording(
  start_time => DateTime->new(year => 2021, month =>  4, day => 19, hour => 12, minute => 10),
  end_time   => DateTime->new(year => 2021, month =>  4, day => 19, hour => 13, minute => 10),
  customer   => $customer,
  project    => $project,
  part       => $part,
)->save;

%data = (
  link_order => 1,
  from_date  => '01.04.2021',
  to_date    => '30.04.2021',
);
$db_obj = SL::DB::BackgroundJob->new();
$db_obj->set_data(%data);
$job    = SL::BackgroundJob::ConvertTimeRecordings->new;
$ret    = $job->run($db_obj);

$linked_dos = $sales_order->linked_records(to => 'DeliveryOrder');
$linked_items = $sales_order->items->[0]->linked_records(to => 'DeliveryOrderItem');
is($linked_items->[0]->qty*1, 2, 'different units 2: qty in delivery order');
is($linked_items->[0]->base_qty*1, 120, 'different units 2: base_qty in delivery order');

# reload order and orderitems to get changes to deliverd and ship
Rose::DB::Object::Helpers::forget_related($sales_order, 'orderitems');
$sales_order->load;

ok($sales_order->delivered, 'different units 2: related order is delivered');
is($sales_order->items->[0]->ship*1, 2, 'different units 2: ship in related order');

clear_up();


########################################
# two time recordings, one with start/end one with date/duration
########################################
$part     = new_service(partnumber => 'Serv1', unit => 'min')->save;
$customer = new_customer()->save;

@time_recordings = ();
push @time_recordings, new_time_recording(
  start_time => DateTime->new(year => 2021, month =>  4, day => 19, hour => 10, minute => 10),
  end_time   => DateTime->new(year => 2021, month =>  4, day => 19, hour => 11, minute => 10),
  customer   => $customer,
  part       => $part,
)->save;

push @time_recordings, new_time_recording(
  date       => DateTime->new(year => 2021, month =>  4, day => 19),
  duration   => 120,
  start_time => undef,
  end_time   => undef,
  customer   => $customer,
  part       => $part,
)->save;

%data = (
  link_order => 0,
  from_date  => '01.04.2021',
  to_date    => '30.04.2021',
);
$db_obj = SL::DB::BackgroundJob->new();
$db_obj->set_data(%data);
$job    = SL::BackgroundJob::ConvertTimeRecordings->new;
$ret    = $job->run($db_obj);

my $dos = SL::DB::Manager::DeliveryOrder->get_all(where => [customer_id => $customer->id]);
is($dos->[0]->items->[0]->qty*1, 180/60, 'date/duration and start/end: qty in delivery order');
is($dos->[0]->items->[0]->base_qty*1, 180, 'date/duration and start/end2: base_qty in delivery order');

clear_up();


########################################
# time recording, linked with order_id
########################################
$part     = new_service(partnumber => 'Serv1', unit => 'Std')->save;
$customer = new_customer()->save;

# sales order with globalproject_id
$sales_order = create_sales_order(
  save             => 1,
  customer         => $customer,
  taxincluded      => 0,
  orderitems       => [ create_order_item(part => $part, qty => 3, sellprice => 70), ]
);

@time_recordings = ();
push @time_recordings, new_time_recording(
  start_time => DateTime->new(year => 2021, month =>  4, day => 19, hour => 10, minute =>  5),
  end_time   => DateTime->new(year => 2021, month =>  4, day => 19, hour => 11, minute =>  5),
  customer   => $customer,
  order      => $sales_order,
  part       => $part,
)->save;

%data = (
  link_order      => 1,
  from_date       => '01.04.2021',
  to_date         => '30.04.2021',
  customernumbers => [$customer->number],
);
$db_obj = SL::DB::BackgroundJob->new();
$db_obj->set_data(%data);
$job    = SL::BackgroundJob::ConvertTimeRecordings->new;
$ret    = $job->run($db_obj);

is_deeply($job->{job_errors}, [], 'no errros');
like($ret, qr{^Number of delivery orders created: 1}, 'linked by order_id: one delivery order created');

$linked_dos = $sales_order->linked_records(to => 'DeliveryOrder');
is(scalar @$linked_dos, 1, 'linked by order_id: one delivery order linked to order');

$linked_items = $sales_order->items->[0]->linked_records(to => 'DeliveryOrderItem');
is(scalar @$linked_items, 1, 'linked by order_id: one delivery order item linked to order item');
is($linked_items->[0]->qty*1, 1, 'linked by order_id: qty in delivery order');
is($linked_items->[0]->base_qty*1, 1, 'linked by order_id: base_qty in delivery order');

# reload order and orderitems to get changes to deliverd and ship
Rose::DB::Object::Helpers::forget_related($sales_order, 'orderitems');
$sales_order->load;

is($sales_order->items->[0]->ship*1, 1, 'linked by order_id: ship in related order');

clear_up();


########################################
# override project and part
########################################
$part     = new_service(partnumber => 'Serv1', unit => 'Std')->save;
my $part2    = new_service(partnumber => 'Serv2', unit => 'min')->save;
$project  = create_project(projectnumber => 'p1', description => 'Project 1');
my $project2 = create_project(projectnumber => 'p2', description => 'Project 2');
$customer = new_customer()->save;

$sales_order = create_sales_order(
  save             => 1,
  customer         => $customer,
  globalproject    => $project,
  taxincluded      => 0,
  orderitems       => [ create_order_item(part => $part, qty => 180, unit => 'min', sellprice => 70), ]
);
my $sales_order2 = create_sales_order(
  save             => 1,
  customer         => $customer,
  globalproject    => $project,
  taxincluded      => 0,
  orderitems       => [ create_order_item(part => $part2, qty => 180, unit => 'min', sellprice => 70), ]
);

new_time_recording(
  start_time => DateTime->new(year => 2021, month =>  4, day => 19, hour => 10, minute => 10),
  end_time   => DateTime->new(year => 2021, month =>  4, day => 19, hour => 11, minute => 10),
  customer   => $customer,
  project    => $project,
  part       => $part,
)->save;
new_time_recording(
  start_time => DateTime->new(year => 2021, month =>  4, day => 19, hour => 11, minute => 10),
  end_time   => DateTime->new(year => 2021, month =>  4, day => 19, hour => 12, minute => 10),
  customer   => $customer,
  project    => $project2,
  part       => $part2,
)->save;
new_time_recording(
  start_time => DateTime->new(year => 2021, month =>  4, day => 19, hour => 12, minute => 10),
  end_time   => DateTime->new(year => 2021, month =>  4, day => 19, hour => 13, minute => 10),
  customer   => $customer,
)->save;

%data = (
  link_order          => 1,
  from_date           => '01.04.2021',
  to_date             => '30.04.2021',
  override_part_id    => $part->id,
  override_project_id => $project->id,
);
$db_obj = SL::DB::BackgroundJob->new();
$db_obj->set_data(%data);
$job    = SL::BackgroundJob::ConvertTimeRecordings->new;
$ret    = $job->run($db_obj);

$linked_dos = $sales_order->linked_records(to => 'DeliveryOrder');
is($linked_dos->[0]->globalproject_id, $project->id, 'overriden part and project: project in delivery order');

$linked_items = $sales_order->items->[0]->linked_records(to => 'DeliveryOrderItem');
is($linked_items->[0]->qty*1, 3, 'overriden part and project: qty in delivery order');
is($linked_items->[0]->base_qty*1, 3, 'overriden part and project: base_qty in delivery order');
is($linked_items->[0]->parts_id, $part->id, 'overriden part and project: part id');

my $linked_dos2 = $sales_order2->linked_records(to => 'DeliveryOrder');
is(scalar @$linked_dos2, 0, 'overriden part and project: no delivery order for unused order');

# reload order and orderitems to get changes to deliverd and ship
Rose::DB::Object::Helpers::forget_related($sales_order, 'orderitems');
$sales_order->load;
Rose::DB::Object::Helpers::forget_related($sales_order2, 'orderitems');
$sales_order2->load;

is($sales_order ->items->[0]->ship||0, 180, 'overriden part and project: ship in related order');
is($sales_order2->items->[0]->ship||0,   0, 'overriden part and project: ship in not related order');

clear_up();


########################################
# default project and part
########################################
$part     = new_service(partnumber => 'Serv1', unit => 'Std')->save;
$project  = create_project(projectnumber => 'p1', description => 'Project 1');
$customer = new_customer()->save;

$sales_order = create_sales_order(
  save             => 1,
  customer         => $customer,
  globalproject    => $project,
  taxincluded      => 0,
  orderitems       => [ create_order_item(part => $part, qty => 180, unit => 'min', sellprice => 70), ]
);

new_time_recording(
  start_time => DateTime->new(year => 2021, month =>  4, day => 19, hour => 10, minute => 10),
  end_time   => DateTime->new(year => 2021, month =>  4, day => 19, hour => 11, minute => 40),
  customer   => $customer,
)->save;

%data = (
  link_order         => 1,
  from_date          => '01.04.2021',
  to_date            => '30.04.2021',
  default_part_id    => $part->id,
  default_project_id => $project->id,
);
$db_obj = SL::DB::BackgroundJob->new();
$db_obj->set_data(%data);
$job    = SL::BackgroundJob::ConvertTimeRecordings->new;
$ret    = $job->run($db_obj);

$linked_dos = $sales_order->linked_records(to => 'DeliveryOrder');
is($linked_dos->[0]->globalproject_id, $project->id, 'default and project: project in delivery order');

$linked_items = $sales_order->items->[0]->linked_records(to => 'DeliveryOrderItem');
is($linked_items->[0]->qty*1, 1.5, 'default part and project: qty in delivery order');
is($linked_items->[0]->base_qty*1, 1.5, 'default part and project: base_qty in delivery order');
is($linked_items->[0]->parts_id, $part->id, 'default part and project: part id');

# reload order and orderitems to get changes to deliverd and ship
Rose::DB::Object::Helpers::forget_related($sales_order, 'orderitems');
$sales_order->load;

is($sales_order->items->[0]->ship*1, 90, 'default part and project: ship in related order');

clear_up();


########################################
# check rounding
########################################
$part     = new_service(partnumber => 'Serv1', unit => 'Std')->save;
$customer = new_customer()->save;

$sales_order = create_sales_order(
  save             => 1,
  customer         => $customer,
  taxincluded      => 0,
  orderitems       => [ create_order_item(part => $part, qty => 3, sellprice => 70), ]
);

@time_recordings = ();
push @time_recordings, new_time_recording(
  start_time => DateTime->new(year => 2021, month =>  4, day => 19, hour => 10, minute =>  0),
  end_time   => DateTime->new(year => 2021, month =>  4, day => 19, hour => 10, minute =>  6),
  customer   => $customer,
  order      => $sales_order,
  part       => $part,
)->save;

%data   = (
  from_date  => '01.01.2021',
  to_date    => '30.04.2021',
  link_order => 1,
  rounding   => 1,
);
$db_obj = SL::DB::BackgroundJob->new();
$db_obj->set_data(%data);
$job    = SL::BackgroundJob::ConvertTimeRecordings->new;
$ret    = $job->run($db_obj);

$linked_dos   = $sales_order->linked_records(to => 'DeliveryOrder');
$linked_items = $sales_order->items->[0]->linked_records(to => 'DeliveryOrderItem');
is($linked_items->[0]->qty*1, 0.25, 'rounding to quarter hour: qty in delivery order');
is($linked_items->[0]->base_qty*1, 0.25, 'rounding to quarter hour: base_qty in delivery order');

# reload order and orderitems to get changes to deliverd and ship
Rose::DB::Object::Helpers::forget_related($sales_order, 'orderitems');
$sales_order->load;

is($sales_order->items->[0]->ship*1, 0.25, 'rounding to quarter hour: ship in related order');

clear_up();


########################################
# check rounding
########################################
$part     = new_service(partnumber => 'Serv1', unit => 'Std')->save;
$customer = new_customer()->save;

$sales_order = create_sales_order(
  save             => 1,
  customer         => $customer,
  taxincluded      => 0,
  orderitems       => [ create_order_item(part => $part, qty => 3, sellprice => 70), ]
);

@time_recordings = ();
push @time_recordings, new_time_recording(
  start_time => DateTime->new(year => 2021, month =>  4, day => 19, hour => 10, minute =>  0),
  end_time   => DateTime->new(year => 2021, month =>  4, day => 19, hour => 10, minute =>  6),
  customer   => $customer,
  order      => $sales_order,
  part       => $part,
)->save;

%data   = (
  from_date  => '01.01.2021',
  to_date    => '30.04.2021',
  link_order => 1,
  rounding   => 0,
);
$db_obj = SL::DB::BackgroundJob->new();
$db_obj->set_data(%data);
$job    = SL::BackgroundJob::ConvertTimeRecordings->new;
$ret    = $job->run($db_obj);

$linked_dos   = $sales_order->linked_records(to => 'DeliveryOrder');
$linked_items = $sales_order->items->[0]->linked_records(to => 'DeliveryOrderItem');
is($linked_items->[0]->qty*1, 0.1, 'no rounding: qty in delivery order');
is($linked_items->[0]->base_qty*1, 0.1, 'no rounding: base_qty in delivery order');

# reload order and orderitems to get changes to deliverd and ship
Rose::DB::Object::Helpers::forget_related($sales_order, 'orderitems');
$sales_order->load;

is($sales_order->items->[0]->ship*1, 0.1, 'no rounding: ship in related order');

clear_up();


########################################
# are wrong params detected?
########################################
%data = (
  from_date       => 'x01.04.2021',
);
$db_obj = SL::DB::BackgroundJob->new();
$db_obj->set_data(%data);
$job    = SL::BackgroundJob::ConvertTimeRecordings->new;

my $err_msg = '';
eval { $ret = $job->run($db_obj);  1; } or do {$err_msg = $@};
ok($err_msg =~ '^Cannot convert date.', 'wrong date string detected');

#####

$customer = new_customer()->save;
%data = (
  customernumbers => ['a fantasy', $customer->number],
);

$db_obj = SL::DB::BackgroundJob->new();
$db_obj->set_data(%data);
$job    = SL::BackgroundJob::ConvertTimeRecordings->new;

$err_msg = '';
eval { $ret = $job->run($db_obj);  1; } or do {$err_msg = $@};
ok($err_msg =~ '^Not all customer numbers are valid', 'wrong customer number detected');

#####

%data = (
  customernumbers => '123',
);

$db_obj = SL::DB::BackgroundJob->new();
$db_obj->set_data(%data);
$job    = SL::BackgroundJob::ConvertTimeRecordings->new;

$err_msg = '';
eval { $ret = $job->run($db_obj);  1; } or do {$err_msg = $@};
ok($err_msg =~ '^Customer numbers must be given in an array', 'wrong customer number data type detected');

#####

%data = (
  override_part_id => '123',
);

$db_obj = SL::DB::BackgroundJob->new();
$db_obj->set_data(%data);
$job    = SL::BackgroundJob::ConvertTimeRecordings->new;

$err_msg = '';
eval { $ret = $job->run($db_obj);  1; } or do {$err_msg = $@};
ok($err_msg =~ '^No valid part found by given override part id', 'invalid part id detected');

#####

$part = new_service(partnumber => 'Serv1', unit => 'Std', obsolete => 1)->save;
%data = (
  override_part_id => $part->id,
);

$db_obj = SL::DB::BackgroundJob->new();
$db_obj->set_data(%data);
$job    = SL::BackgroundJob::ConvertTimeRecordings->new;

$err_msg = '';
eval { $ret = $job->run($db_obj);  1; } or do {$err_msg = $@};
ok($err_msg =~ '^No valid part found by given override part id', 'obsolete part detected');

#####

%data = (
  override_project_id => 123,
);

$db_obj = SL::DB::BackgroundJob->new();
$db_obj->set_data(%data);
$job    = SL::BackgroundJob::ConvertTimeRecordings->new;

$err_msg = '';
eval { $ret = $job->run($db_obj);  1; } or do {$err_msg = $@};
ok($err_msg =~ '^No valid project found by given override project id', 'invalid project id detected');

#####

$project = create_project(projectnumber => 'p1', description => 'Project 1', valid => 0)->save;
%data = (
  override_project_id => $project->id,
);

$db_obj = SL::DB::BackgroundJob->new();
$db_obj->set_data(%data);
$job    = SL::BackgroundJob::ConvertTimeRecordings->new;

$err_msg = '';
eval { $ret = $job->run($db_obj);  1; } or do {$err_msg = $@};
ok($err_msg =~ '^No valid project found by given override project id', 'invalid project detected');

#####

clear_up();


########################################

$::locale = $old_locale;

1;

#####
# vim: ft=perl
# set emacs to perl mode
# Local Variables:
# mode: perl
# End:
