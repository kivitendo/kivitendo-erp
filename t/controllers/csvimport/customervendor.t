use Test::More tests => 41;

use strict;

use lib 't';

use Support::TestSetup;
use List::MoreUtils qw(none any);

use SL::DB::Customer;
use SL::DB::CustomVariableConfig;
use SL::DB::Default;

use SL::Controller::CsvImport;
use_ok 'SL::Controller::CsvImport::CustomerVendor';

Support::TestSetup::login();

#####
sub do_import {
  my ($file, $settings) = @_;

  my $controller = SL::Controller::CsvImport->new(
    type => 'customers_vendors',
  );
  $controller->load_default_profile;
  $controller->profile->set(
    charset  => 'utf-8',
    sep_char => ';',
    %$settings
  );

  my $worker = SL::Controller::CsvImport::CustomerVendor->new(
    controller => $controller,
    file       => $file,
  );
  $worker->run(test => 0);

  return if $worker->controller->errors;

  # don't try and save objects that have errors
  $worker->save_objects unless scalar @{$worker->controller->data->[0]->{errors}};

  return $worker->controller->data;
}

sub _obj_of {
  return $_[0]->{object_to_save} || $_[0]->{object};
}

sub clear_up {
  SL::DB::Manager::Customer->delete_all(all => 1);
  SL::DB::Manager::CustomVariableConfig->delete_all(all => 1);

  SL::DB::Default->get->update_attributes(customernumber => '10000');

  # Reset request to clear caches. Here especially for cvar-configs.
  $::request = Support::TestSetup->create_new_request;
}

#####

# set numberformat and locale (so we can match errors)
my $old_numberformat      = $::myconfig{numberformat};
$::myconfig{numberformat} = '1.000,00';
my $old_locale            = $::locale;
$::locale                 = Locale->new('en');

clear_up;

#####
# import and update entries

my $file = \<<EOL;
name;street;
CustomerName;CustomerStreet
EOL

my $entries = do_import($file, {update_policy => 'update_existing'});

ok none {'Updating existing entry in database' eq $_} @{$entries->[0]->{information}}, 'import entry - information (customer)';
is _obj_of($entries->[0])->customernumber, '10001',          'import entry - number (customer)';
is _obj_of($entries->[0])->name,           'CustomerName',   'import entry - name (customer)';
is _obj_of($entries->[0])->street,         'CustomerStreet', 'import entry - street (customer)';
is _obj_of($entries->[0]),                 $entries->[0]->{object}, 'import entry - object not object_to_save (customer)';

my $default_customernumer = SL::DB::Default->get->load->customernumber;
is $default_customernumer, '10001', 'import entry - defaults range of numbers (customer)';

my $customer_id = _obj_of($entries->[0])->id;

$entries = undef;

$file = \<<EOL;
customernumber;name;street;
10001;CustomerName;NewCustomerStreet
EOL

$entries = do_import($file, {update_policy => 'update_existing'});

ok any {'Updating existing entry in database' eq $_} @{ $entries->[0]->{information} }, 'update entry - information (customer)';
is _obj_of($entries->[0])->customernumber, '10001',             'update entry - number (customer)';
is _obj_of($entries->[0])->name,           'CustomerName',      'update entry - name (customer)';
is _obj_of($entries->[0])->street,         'NewCustomerStreet', 'update entry - street (customer)';
is _obj_of($entries->[0]),                 $entries->[0]->{object_to_save}, 'update entry - object is object_to_save (customer)';
is _obj_of($entries->[0])->id,             $customer_id,        'update entry - same id (customer)';
$default_customernumer = SL::DB::Default->get->load->customernumber;
is $default_customernumer, '10001', 'update entry - defaults range of numbers (customer)';

$entries = undef;

$file = \<<EOL;
customernumber;name;street;
10001;WrongCustomerName;WrongCustomerStreet
EOL

$entries = do_import($file, {update_policy => 'skip'});

ok any {'Skipping due to existing entry in database' eq $_} @{ $entries->[0]->{errors} }, 'skip entry - error (customer)';

$default_customernumer = SL::DB::Default->get->load->customernumber;
is $default_customernumer, '10001', 'skip entry - defaults range of numbers (customer)';

$entries = undef;

clear_up;
#####

$file = \<<EOL;
name
CustomerName
EOL

$entries = do_import($file);

is scalar @$entries,             1,              'one entry - nuber of entries (customer)';
is _obj_of($entries->[0])->name, 'CustomerName', 'simple file - name only (customer)';

$entries = undef;
clear_up;

#####
$file = \<<EOL;
customernumber;name
1;CustomerName1
2;CustomerName2
EOL

$entries = do_import($file);

is scalar @$entries,                       2,               'two entries - number of entries (customer)';
is _obj_of($entries->[0])->name,           'CustomerName1', 'two entries, number and name - name  (customer)';
is _obj_of($entries->[0])->customernumber, '1',             'two entries, number and name - number  (customer)';
is _obj_of($entries->[1])->name,           'CustomerName2', 'two entries, number and name - name  (customer)';
is _obj_of($entries->[1])->customernumber, '2',             'two entries, number and name - number  (customer)';

$entries = undef;
clear_up;

#####
$file = \<<EOL;
name;creditlimit;discount
CustomerName1;1.280,50;0,035
EOL

$entries = do_import($file);

is scalar @$entries,                     1,              'creditlimit/discount - number of entries (customer)';
is _obj_of($entries->[0])->name,        'CustomerName1', 'creditlimit/discount - name  (customer)';
is _obj_of($entries->[0])->creditlimit, 1280.5,          'creditlimit/discount - creditlimit (customer))';
# Should discount be given in percent or in decimal?
is _obj_of($entries->[0])->discount,   0.035,            'creditlimit/discount - discount (customer)';

$entries = undef;
clear_up;

#####
# Test import with cvars.
# Customer/vendor cvars can have a default value, so the following cases are to be
# tested
# - new customer in csv - no cvars given -> one should be unset, the other one
#   should have the default value
# - new customer in csv - both cvars given -> cvars should have the given values
# - update customer with no cvars in csv -> cvars should not change
# - update customer with both cvars in csv -> cvars should have the given values
# (not explicitly testet: does an empty cvar field means to unset the cvar or to
# leave it untouched?)

# create cvars
SL::DB::CustomVariableConfig->new(
  module              => 'CT',
  name                => 'no_default',
  description         => 'no default',
  type                => 'text',
  searchable          => 1,
  sortkey             => 1,
  includeable         => 0,
  included_by_default => 0,
)->save;

SL::DB::CustomVariableConfig->new(
  module              => 'CT',
  name                => 'with_default',
  description         => 'with default',
  type                => 'text',
  default_value       => 'this is the default',
  searchable          => 1,
  sortkey             => 1,
  includeable         => 0,
  included_by_default => 0,
)->save;

# - new customer in csv - no cvars given -> one should be unset, the other one
#   should have the default value
$file = \<<EOL;
customernumber;name;
1;CustomerName1
EOL

$entries = do_import($file);

is _obj_of($entries->[0])->customernumber,                      '1',                   'cvar test - import customer 1 with no cvars - number (customer)';
is _obj_of($entries->[0])->cvar_by_name('no_default')->value,   undef,                 'cvar test - import customer 1 - do not set ungiven cvar which has no default';
is _obj_of($entries->[0])->cvar_by_name('with_default')->value, 'this is the default', 'cvar test - import customer 1 - do set ungiven cvar which has default';

$entries = undef;

# - new customer in csv - both cvars given -> cvars should have the given values
$file = \<<EOL;
customernumber;name;cvar_no_default;cvar_with_default
2;CustomerName2;"new cvar value abc";"new cvar value xyz"
EOL

$entries = do_import($file);

is _obj_of($entries->[0])->customernumber,                      '2',                  'cvar test - import customer 2 with cvars - number (customer)';
is _obj_of($entries->[0])->cvar_by_name('no_default')->value,   'new cvar value abc', 'cvar test - import customer 2 - do set given cvar which has default';
is _obj_of($entries->[0])->cvar_by_name('with_default')->value, 'new cvar value xyz', 'cvar test - import customer 2 - do set given cvar which has default';

$entries = undef;

# - update customer with no cvars in csv -> cvars should not change
$file = \<<EOL;
customernumber;name;street
1;CustomerName1;"street cs1"
EOL

$entries = do_import($file, {update_policy => 'update_existing'});
is _obj_of($entries->[0])->customernumber,                      '1',                   'cvar test - update customer 1 - number (customer)';
is _obj_of($entries->[0])->street,                              'street cs1',          'cvar test - update customer 1 - set new street (customer)';
is _obj_of($entries->[0])->cvar_by_name('no_default')->value,   undef,                 'cvar test - update customer 1 - do not set ungiven cvar which has no default';
is _obj_of($entries->[0])->cvar_by_name('with_default')->value, 'this is the default', 'cvar test - update customer 1 - do set ungiven cvar which has default';

$entries = undef;

# - update customer with both cvars in csv -> cvars should have the given values
$file = \<<EOL;
customernumber;name;street;cvar_no_default;cvar_with_default
1;CustomerName1;"new street cs1";totaly new cvar 123;totaly new cvar abc
EOL

$entries = do_import($file, {update_policy => 'update_existing'});
is _obj_of($entries->[0])->customernumber,                      '1',                   'cvar test - update customer 1 - number (customer)';
is _obj_of($entries->[0])->street,                              'new street cs1',      'cvar test - update customer 1 - set new street (customer)';
is _obj_of($entries->[0])->cvar_by_name('no_default')->value,   'totaly new cvar 123', 'cvar test - update customer 1 - do set given cvar which has no default (customer)';
is _obj_of($entries->[0])->cvar_by_name('with_default')->value, 'totaly new cvar abc', 'cvar test - update customer 1 - do set given cvar which has default (customer)';

$entries = undef;


clear_up;

$::myconfig{numberformat} = $old_numberformat;
$::locale                 = $old_locale;

1;

#####
# vim: ft=perl
# set emacs to perl mode
# Local Variables:
# mode: perl
# End:
