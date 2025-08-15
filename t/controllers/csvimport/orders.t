use Test::More;

use strict;

use lib 't';
use utf8;

use Support::TestSetup;

use List::MoreUtils qw(none any);

use SL::Controller::CsvImport;
use_ok 'SL::Controller::CsvImport::Order';

use SL::DB::Order::TypeData qw(:types);
use SL::Dev::ALL qw(:ALL);

Support::TestSetup::login();

#####
sub do_import {
  my ($file, $settings) = @_;

  my $controller = SL::Controller::CsvImport->new(
    type => 'orders',
  );
  $controller->load_default_profile;
  $controller->profile->set(
    charset  => 'utf-8',
    sep_char => ';',
    %$settings
  );

  my $worker = SL::Controller::CsvImport::Order->new(
    controller => $controller,
    file       => $file,
  );
  $worker->run(test => 0);

  return if $worker->controller->errors;

  # don't try and save objects that have errors
  $worker->save_objects unless scalar @{$worker->controller->data->[0]->{errors}};

  return $worker->controller->data;
}

sub clear_up {
  foreach (qw(RecordLink Order Customer Part)) {
    "SL::DB::Manager::${_}"->delete_all(all => 1);
  }
  SL::DB::Manager::Employee->delete_all(where => [ '!login' => 'unittests' ]);
}

#####

# set numberformat and locale (so we can match errors)
local $::myconfig{numberformat} = '1.000,00';
local $::locale                 = Locale->new('en');

clear_up;

#####
my @customers;
my @vendors;
my @parts;
my @orders;
my $file;
my $entries;
my $entry;

@customers = (new_customer(name => 'TestCustomer1', discount => 0)->save);
@vendors   = (new_vendor  (name => 'TestVendor1',   discount => 0)->save);
@parts = (
  new_part(description => 'TestPart1', ean => '')->save,
  new_part(description => 'TestPart2', ean => '')->save
);

#####
# simple import
#####
$file = \<<EOL;
datatype;customer
datatype;description;qty
Order;TestCustomer1
OrderItem;TestPart1;5
OrderItem;TestPart2;10
EOL

$entries = do_import($file);

$entry = $entries->[0];
is $entry->{object}->customer_id, $customers[0]->id, 'simple import: customer_id';

$entry = $entries->[1];
is $entry->{object}->parts_id,    $parts[0]->id,     'simple import: part 1: parts_id';
is $entry->{object}->qty,         5,                 'simple import: part 1: qty';

$entry = $entries->[2];
is $entry->{object}->parts_id,    $parts[1]->id,     'simple import: part 2: parts_id';
is $entry->{object}->qty,         10,                'simple import: part 2: qty';


$entries = undef;

#####
# test handling of record type
#####
$file = \<<EOL;
datatype;customer;vendor
datatype;description;qty
Order;TestCustomer1
OrderItem;TestPart1;5
Order;;TestVendor1
OrderItem;TestPart2;10
EOL

$entries = do_import($file);

$entry = $entries->[0];
is $entry->{object}->record_type, SALES_ORDER_TYPE, 'record type is sales order when customer given';

$entry = $entries->[2];
is $entry->{object}->record_type, PURCHASE_ORDER_TYPE, 'record type is purchase order when vendor given';

$entries = undef;

$file = \<<EOL;
datatype;customer;vendor;record_type
datatype;description;qty
Order;TestCustomer1;;sales_order
OrderItem;TestPart1;1
Order;;TestVendor1;purchase_order
OrderItem;TestPart2;2
Order;TestCustomer1;;sales_quotation
OrderItem;TestPart1;3
Order;;TestVendor1;request_quotation
OrderItem;TestPart1;4
Order;;TestVendor1;purchase_quotation_intake
OrderItem;TestPart1;5
Order;TestCustomer1;;sales_order_intake
OrderItem;TestPart1;6
Order;;TestVendor1;purchase_order_confirmation
OrderItem;TestPart1;7
EOL

$entries = do_import($file);

$entry = $entries->[0];
is $entry->{object}->record_type, SALES_ORDER_TYPE, '"sales_order" as explicitly given record type works';
$entry = $entries->[2];
is $entry->{object}->record_type, PURCHASE_ORDER_TYPE, '"purchase_order" as explicitly given record type works';
$entry = $entries->[4];
is $entry->{object}->record_type, SALES_QUOTATION_TYPE, '"sales_quatation" as explicitly given record type works';
$entry = $entries->[6];
is $entry->{object}->record_type, REQUEST_QUOTATION_TYPE, '"request_quotation" as explicitly given record type works';
$entry = $entries->[8];
is $entry->{object}->record_type, PURCHASE_QUOTATION_INTAKE_TYPE, '"purchase_quotation_intake" as explicitly given record type works';
$entry = $entries->[10];
is $entry->{object}->record_type, SALES_ORDER_INTAKE_TYPE, '"sales_order_intake" as explicitly given record type works';
$entry = $entries->[12];
is $entry->{object}->record_type, PURCHASE_ORDER_CONFIRMATION_TYPE, '"purchase_order_confirmation" as explicitly given record type works';

#####
$entries = undef;
clear_up;

done_testing();

#####

1;

#####
# vim: ft=perl
# set emacs to perl mode
# Local Variables:
# mode: perl
# End:
