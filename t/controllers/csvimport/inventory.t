use strict;

use Data::Dumper; # maybe in Tests available?
use Test::Deep qw(cmp_deeply superhashof ignore);
use Test::More;
use Test::Exception;

use lib 't';

use SL::Dev::Part qw(new_part new_assembly new_service);
use SL::Dev::Inventory qw(create_warehouse_and_bins set_stock);

use_ok 'Support::TestSetup';
use_ok 'SL::Controller::CsvImport';
use_ok 'SL::DB::Bin';
use_ok 'SL::DB::Part';
use_ok 'SL::DB::Warehouse';
use_ok 'SL::DB::Inventory';
use_ok 'SL::WH';
use_ok 'SL::Helper::Inventory';

Support::TestSetup::login();

my ($wh, $bin1, $bin2, $assembly1, $assembly_service, $part1, $part2, $wh_moon, $bin_moon, $service1);

sub reset_state {
  # Create test data

  clear_up();
  create_standard_stock();

}
reset_state();

#####
sub test_import {
  my ($file,$settings) = @_;

  my $controller = SL::Controller::CsvImport->new(
    type => 'inventories'
  );
  $controller->load_default_profile;
  $controller->profile->set(
    charset      => 'utf-8',
    sep_char     => ',',
    quote_char   => '"',
    numberformat => $::myconfig{numberformat},
  );
  my $csv_inventory_import = SL::Controller::CsvImport::Inventory->new(
    settings   => $settings,
    controller => $controller,
    file       => $file,
  );
  #print "profile param type=".$csv_part_import->settings->{parts_type}."\n";

  $csv_inventory_import->run(test => 0);

  # don't try and save objects that have errors
  $csv_inventory_import->save_objects unless scalar @{$csv_inventory_import->controller->data->[0]->{errors}};

  return $csv_inventory_import->controller->data;
}

$::myconfig{numberformat} = '1000.00';
my $old_locale = $::locale;
# set locale to en so we can match errors
$::locale = Locale->new('en');


my ($entries, $entry, $file);

# different settings for tests
#

my $settings1 = {
                  apply_comment => 'missing',
                  comment       => 'Lager Inventur Standard',
                };
#
#
# starting test of csv imports
# to debug errors in certain tests, run after test_import:
#   die Dumper($entry->{errors});


##### create complete bullshit
$file = \<<EOL;
bin,chargenumber,comment,employee_id,partnumber,qty,shippingdate,target_qty,warehouse
P1000;100.10;90.20;95.30;kg;111.11;122.22;133.33
EOL
$entries = test_import($file, $settings1);
$entry = $entries->[0];
is scalar @{ $entry->{errors} }, 3, "Three errors occurred";

cmp_deeply(\@{ $entry->{errors} }, [
                                    'Error: Warehouse not found',
                                    'Error: Bin not found',
                                    'Error: Part not found'
                                   ],
          "Errors for bullshit import are ok"
);

##### create minor bullshit
$file = \<<EOL;
warehouse,bin,partnumber,qty,chargenumber,comment,employee_id,qty,shippingdate,target_qty
Warehouse,"Bin 1","ap 1",3.4
EOL

$entries = test_import($file, $settings1);
$entry = $entries->[0];
is scalar @{ $entry->{errors} }, 1, "One error for minor bullshit occurred";

cmp_deeply(\@{ $entry->{errors} }, [
                                    'Error: A quantity and a target quantity could not be given both.'
                                   ],
          "Error for minor bullshit import are ok"
);


##### add some qty on earth, but we have something already stocked
set_stock(
  part => $part1,
  qty => 25,
  bin => $bin1,
);

is(SL::Helper::Inventory::get_stock(part => $part1), "25.00000", 'simple get_stock works');
is(SL::Helper::Inventory::get_onhand(part => $part1), "25.00000", 'simple get_onhand works');

my ($trans_id, $inv_obj, $tt);
# add some stuff

$file = \<<EOL;
warehouse,bin,partnumber,qty,chargenumber,comment,employee_id,shippingdate
Warehouse,"Bin 1","ap 1",3.4
EOL
$entries = test_import($file, $settings1);
$entry = $entries->[0];
is scalar @{ $entry->{errors} }, 0, "No error for valid data occurred";
is $entry->{object}->qty, "3.4", "Valid qty accepted";  # evals to text
is(SL::Helper::Inventory::get_stock(part => $part1),  "28.40000",  'simple add (stock) qty works');
is(SL::Helper::Inventory::get_onhand(part => $part1), "28.40000", 'simple add (onhand) qty works');

# now check the real Inventory entry
$trans_id = $entry->{object}->trans_id;
$inv_obj = SL::DB::Manager::Inventory->find_by(trans_id => $trans_id);

# we expect one entry for one trans_id
is ref $inv_obj, "SL::DB::Inventory",             "One inventory object, no array or undef";
is $inv_obj->qty == 3.4, 1,                       "Valid qty accepted";  # evals to text
is $inv_obj->comment, 'Lager Inventur Standard',  "Valid comment accepted";  # evals to text
is $inv_obj->employee_id, 1,                      "Employee valid";  # evals to text
is ref $inv_obj->shippingdate, 'DateTime',        "Valid DateTime for shippingdate";
is $inv_obj->shippingdate, DateTime->today_local, "Default shippingdate set";

$tt = SL::DB::Manager::TransferType->find_by(id => $inv_obj->trans_type_id);

is ref $tt, 'SL::DB::TransferType',       "Valid TransferType, no undef";
is $tt->direction, 'in',                  "Transfer direction correct";
is $tt->description, 'correction',        "Transfer description correct";

# remove some stuff

$file = \<<EOL;
warehouse,bin,partnumber,qty,chargenumber,comment,employee_id,shippingdate
Warehouse,"Bin 1","ap 1",-13.4
EOL
$entries = test_import($file, $settings1);
$entry = $entries->[0];
is scalar @{ $entry->{errors} }, 0, "No error for valid data occurred";
is $entry->{object}->qty, "-13.4", "Valid qty accepted";  # evals to text
is(SL::Helper::Inventory::get_stock(part => $part1),  "15.00000",  'simple add (stock) qty works');
is(SL::Helper::Inventory::get_onhand(part => $part1), "15.00000", 'simple add (onhand) qty works');

# now check the real Inventory entry
$trans_id = $entry->{object}->trans_id;
$inv_obj = SL::DB::Manager::Inventory->find_by(trans_id => $trans_id);

# we expect one entry for one trans_id
is ref $inv_obj, "SL::DB::Inventory",             "One inventory object, no array or undef";
is $inv_obj->qty == -13.4, 1,                       "Valid qty accepted";  # evals to text
is $inv_obj->comment, 'Lager Inventur Standard',  "Valid comment accepted";  # evals to text
is $inv_obj->employee_id, 1,                      "Employee valid";  # evals to text
is ref $inv_obj->shippingdate, 'DateTime',        "Valid DateTime for shippingdate";
is $inv_obj->shippingdate, DateTime->today_local, "Default shippingdate set";

$tt = SL::DB::Manager::TransferType->find_by(id => $inv_obj->trans_type_id);

is ref $tt, 'SL::DB::TransferType',       "Valid TransferType, no undef";
is $tt->direction, 'out',                  "Transfer direction correct";
is $tt->description, 'correction',        "Transfer description correct";

# repeat both test cases but with target qty instead of qty (should throw an error for neg. case)
# and customise comment
# add some stuff

$file = \<<EOL;
warehouse,bin,partnumber,target_qty,comment
Warehouse,"Bin 1","ap 1",3.4,"Alter, wir haben uns voll verhauen bei der aktuellen Zielmenge!"
EOL
$entries = test_import($file, $settings1);
$entry = $entries->[0];
is scalar @{ $entry->{errors} }, 0, "No error for valid data occurred";
is $entry->{object}->qty, "-11.6", "Valid qty accepted";  # evals to text qty = target_qty - actual_qty
is(SL::Helper::Inventory::get_stock(part => $part1),  "3.40000",  'simple add (stock) qty works');
is(SL::Helper::Inventory::get_onhand(part => $part1), "3.40000", 'simple add (onhand) qty works');

# now check the real Inventory entry
$trans_id = $entry->{object}->trans_id;
$inv_obj = SL::DB::Manager::Inventory->find_by(trans_id => $trans_id);

# we expect one entry for one trans_id
is ref $inv_obj, "SL::DB::Inventory",             "One inventory object, no array or undef";
is $inv_obj->qty == -11.6, 1,                       "Valid qty accepted";
is $inv_obj->comment,
  "Alter, wir haben uns voll verhauen bei der aktuellen Zielmenge!",  "Valid comment accepted";
is $inv_obj->employee_id, 1,                      "Employee valid";
is ref $inv_obj->shippingdate, 'DateTime',        "Valid DateTime for shippingdate";
is $inv_obj->shippingdate, DateTime->today_local, "Default shippingdate set";

$tt = SL::DB::Manager::TransferType->find_by(id => $inv_obj->trans_type_id);

is ref $tt, 'SL::DB::TransferType',       "Valid TransferType, no undef";
is $tt->direction, 'out',                  "Transfer direction correct";
is $tt->description, 'correction',        "Transfer description correct";

# remove some stuff, but too much

$file = \<<EOL;
warehouse,bin,partnumber,target_qty,comment
Warehouse,"Bin 1","ap 1",-13.4,"Jetzt stimmt aber alles"
EOL
$entries = test_import($file, $settings1);
$entry = $entries->[0];
is scalar @{ $entry->{errors} }, 1, "One error for invalid data occurred";
is $entry->{object}->qty, undef, "No data accepted";  # evals to text
is(SL::Helper::Inventory::get_stock(part => $part1),  "3.40000",  'simple add (stock) qty works');
is(SL::Helper::Inventory::get_onhand(part => $part1), "3.40000", 'simple add (onhand) qty works');

# now check the real Inventory entry
$trans_id = $entry->{object}->trans_id;
$inv_obj = SL::DB::Manager::Inventory->find_by(trans_id => $trans_id);

is ref $trans_id, '',         "No trans_id -> undef";
is ref $inv_obj,  '',         "No inventory object -> undef";

# add some stuff, but realistic value

$file = \<<EOL;
warehouse,bin,partnumber,target_qty,comment
Warehouse,"Bin 1","ap 1",33.75,"Jetzt wirklich"
EOL
$entries = test_import($file, $settings1);
$entry = $entries->[0];
is scalar @{ $entry->{errors} }, 0, "No error for valid data occurred";
is $entry->{object}->qty, "30.35", "Valid qty accepted";  # evals to text qty = target_qty - actual_qty
is(SL::Helper::Inventory::get_stock(part => $part1),  "33.75000",  'simple add (stock) qty works');
is(SL::Helper::Inventory::get_onhand(part => $part1), "33.75000", 'simple add (onhand) qty works');

# now check the real Inventory entry
$trans_id = $entry->{object}->trans_id;
$inv_obj = SL::DB::Manager::Inventory->find_by(trans_id => $trans_id);

# we expect one entry for one trans_id
is ref $inv_obj, "SL::DB::Inventory",             "One inventory object, no array or undef";
is $inv_obj->qty == 30.35, 1,                       "Valid qty accepted";
is $inv_obj->comment,
  "Jetzt wirklich",  "Valid comment accepted";
is $inv_obj->employee_id, 1,                      "Employee valid";
is ref $inv_obj->shippingdate, 'DateTime',        "Valid DateTime for shippingdate";
is $inv_obj->shippingdate, DateTime->today_local, "Default shippingdate set";

$tt = SL::DB::Manager::TransferType->find_by(id => $inv_obj->trans_type_id);

is ref $tt, 'SL::DB::TransferType',       "Valid TransferType, no undef";
is $tt->direction, 'in',                  "Transfer direction correct";
is $tt->description, 'correction',        "Transfer description correct";


clear_up(); # remove all data at end of tests

# end of tests

done_testing();

sub clear_up {
  SL::DB::Manager::Inventory->delete_all(all => 1);
  SL::DB::Manager::Assembly->delete_all(all => 1);
  SL::DB::Manager::Part->delete_all(all => 1);
  SL::DB::Manager::Bin->delete_all(all => 1);
  SL::DB::Manager::Warehouse->delete_all(all => 1);
}

sub create_standard_stock {
  ($wh, $bin1)          = create_warehouse_and_bins();
  ($wh_moon, $bin_moon) = create_warehouse_and_bins(
      warehouse_description => 'Our warehouse location at the moon',
      bin_description       => 'Lunar crater',
    );
  $bin2 = SL::DB::Bin->new(description => "Bin 2", warehouse => $wh)->save;
  $wh->load;

  $assembly1  =  new_assembly(number_of_parts => 2)->save;
  ($part1, $part2) = map { $_->part } $assembly1->assemblies;

  $service1 = new_service(partnumber  => "service number 1",
                          description => "We really need this service",
                         )->save;
  my $assembly_items;
  push( @{$assembly_items}, SL::DB::Assembly->new(parts_id => $part1->id,
                                                  qty      => 12,
                                                  position => 1,
                                                  ));
  push( @{$assembly_items}, SL::DB::Assembly->new(parts_id => $part2->id,
                                                  qty      => 6.34,
                                                  position => 2,
                                                  ));
  push( @{$assembly_items}, SL::DB::Assembly->new(parts_id => $service1->id,
                                                  qty      => 1.2,
                                                  position => 3,
                                                  ));
  $assembly_service  =  new_assembly(description    => 'Ein Erzeugnis mit Dienstleistungen',
                                     assembly_items => $assembly_items
                                    )->save;
}




1;
