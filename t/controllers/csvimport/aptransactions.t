use Test::More;

use strict;

use lib 't';

use Carp;
use Support::TestSetup;
use Test::Exception;

use SL::Dev::ALL qw(:ALL);

use SL::Controller::CsvImport;

use_ok 'SL::Controller::CsvImport::APTransaction';

use SL::DB::AccTransaction;
use SL::DB::Buchungsgruppe;
use SL::DB::Chart;
use SL::DB::Currency;
use SL::DB::Employee;
use SL::DB::Invoice;
use SL::DB::TaxZone;
use SL::DB::Vendor;

my ($vendor, $currency_id, $employee, $taxzone, $project, $department);
my ($transdate, $transdate_string);

sub clear_up {
  SL::DB::Manager::AccTransaction->delete_all (all => 1);
  SL::DB::Manager::PurchaseInvoice->delete_all(all => 1);
  SL::DB::Manager::Vendor->delete_all         (all => 1);
  SL::DB::Manager::Project->delete_all        (all => 1);
  SL::DB::Manager::Department->delete_all     (all => 1);
};

sub reset_state {
  # Create test data
  my %params = @_;

  $transdate = DateTime->today_local;
  $transdate->set_year(2019) if $transdate->year == 2020; # hardcode for 2019 in 2020, because of tax rate change in Germany
  $transdate_string = $transdate->to_kivitendo;

  $params{$_} ||= {} for qw(buchungsgruppe vendor tax);

  clear_up();
  $employee    = SL::DB::Manager::Employee->current                          || croak "No employee";
  $taxzone     = SL::DB::Manager::TaxZone->find_by( description => 'Inland') || croak "No taxzone";
  $currency_id = $::instance_conf->get_currency_id;

  $vendor      = new_vendor(
    currency_id => $currency_id,
    taxzone_id  => $taxzone->id,
    %{ $params{vendor} },
  )->save;

  $project     = SL::DB::Project->new(
    projectnumber  => 'P1',
    description    => 'Project X',
    project_type   => SL::DB::Manager::ProjectType->find_by(description => 'Standard'),
    project_status => SL::DB::Manager::ProjectStatus->find_by(name => 'running'),
  )->save;

  $department  = SL::DB::Department->new(
    description => 'Department 1',
  )->save;
}

Support::TestSetup::login();

reset_state(vendor => {vendornumber => 2});

#####
sub test_import {
  my $file = shift;

  my $controller = SL::Controller::CsvImport->new(
    type => 'ap_transactions'
  );
  $controller->load_default_profile;
  $controller->profile->set(
    charset      => 'utf-8',
    sep_char     => ',',
    quote_char   => '"',
    numberformat => $::myconfig{numberformat},
    duplicates   => 'check_db',
    duplicates_vendor_and_invnumber => 1,
  );

  my $csv_aptransactions_import = SL::Controller::CsvImport::APTransaction->new(
    settings    => {'ap_column'          => 'Rechnung',
                    'transaction_column' => 'AccTransaction',
                    'max_amount_diff'    => 0.02
                  },
    controller => $controller,
    file       => $file,
  );

  $csv_aptransactions_import->run(test => 0);

  # don't try and save objects that have errors
  $csv_aptransactions_import->save_objects unless scalar @{$csv_aptransactions_import->controller->data->[0]->{errors}};

 return $csv_aptransactions_import->controller->data;
}

##### manually create an ap transaction from scratch, testing the methods
$::myconfig{numberformat} = '1000.00';
$::myconfig{dateformat}   = 'dd.mm.yyyy';
my $old_locale = $::locale;
# set locale to en so we can match errors
$::locale = Locale->new('en');

my $amount = 10;

my $ap = SL::DB::PurchaseInvoice->new(
  invoice      => 0,
  invnumber    => 'manual invoice',
  taxzone_id   => $taxzone->id,
  currency_id  => $currency_id,
  taxincluded  => 'f',
  vendor_id    => $vendor->id,
  transdate    => $transdate,
  employee_id  => SL::DB::Manager::Employee->current->id,
  transactions => [],
);

my $tax9 = SL::DB::Manager::Tax->find_by(rate => 0.19, taxkey => 9) || die "can't find tax with taxkey 9";
my $income_chart = SL::DB::Manager::Chart->find_by(accno => '3400') || die "can't find expense chart";

$ap->add_ap_amount_row(
  amount => $amount,
  chart  => $income_chart,
  tax_id => $tax9->id,
);

$ap->recalculate_amounts; # set amount and netamount from transactions
is $ap->amount, '10', 'amount of manual invoice is 10';
is $ap->netamount, '8.4', 'netamount of manual invoice is 10';

$ap->create_ap_row( chart => SL::DB::Manager::Chart->find_by(accno => '1600', link => 'AP') );
my $result = $ap->validate_acc_trans();
is $result, 1, 'manual $ap validates';

$ap->save;
is ${ $ap->transactions }[0]->chart->accno, '3400', 'assigned expense chart after save ok';
is ${ $ap->transactions }[2]->chart->accno, '1600', 'assigned payable chart after save ok';
is scalar @{$ap->transactions}, 3, 'manual invoice has 3 acc_trans entries';

$ap->pay_invoice(  chart_id      => SL::DB::Manager::Chart->find_by(accno => '1200')->id, # bank
                   amount        => $ap->open_amount,
                   transdate     => $transdate,
                   payment_type  => 'without_skonto',  # default if not specified
                  );
$result = $ap->validate_acc_trans();
is $result, 1, 'manual invoice validates after payment';

#####
reset_state(vendor => {vendornumber => 2});

my ($entries, $entry, $file);
my $saved_invoices = 0;

# starting test of csv imports
# to debug errors in certain tests, run after test_import:
#   $::lxdebug->dump(0, "entry 0 errors: ", $entry->{errors}->[0]);
##### basic test
$file = \<<"EOL";
datatype,vendornumber,currency_id,invnumber,taxincluded,apchart,transdate
datatype,accno,amount,taxkey
"Rechnung",2,1,"invoice 1",f,1600,"$transdate_string"
"AccTransaction",3400,159.48,9
EOL
$entries = test_import($file);
is $entries->[0]->{errors}->[0], undef, 'basic test: no errors in ap row';
is $entries->[1]->{errors}->[0], undef, 'basic test: no errors in acc_trans row';

$entry = $entries->[0];
is $entry->{object}->validate_acc_trans, 1, 'basic test: acc_trans validates';
is $entry->{object}->invnumber, 'invoice 1', 'basic test: invnumber ok';
is $entry->{object}->vendor_id, $vendor->id, 'basic test: vendor_id ok';
is scalar @{$entry->{object}->transactions}, 3, 'basic test: invoice 1 has 3 acc_trans entries';
is $::form->round_amount($entry->{object}->transactions->[0]->amount, 2), -159.48, 'basic test: invoice 1 ap amount is -159.48';
is $entry->{object}->direct_debit, '0', 'basic test: no direct debit';
is $entry->{object}->taxincluded, '0', 'basic test: taxincluded is false';
is $entry->{object}->amount, '189.78', 'basic test: ap amount tax not included is 189.78';
is $entry->{object}->netamount, '159.48', 'basic test: ap netamount tax not included is 159.48';

$saved_invoices++;

##### test for duplicate invnumber for same vendor
$file = \<<"EOL";
datatype,vendornumber,currency_id,invnumber,taxincluded,apchart,transdate
datatype,accno,amount,taxkey
"Rechnung",2,1,"invoice 1",f,1600,"$transdate_string"
"AccTransaction",3400,159.48,9
EOL

$entries = test_import($file);
$entry = $entries->[0];
is $entry->{errors}->[0], 'Duplicate in database', 'detects duplicate invnumer for same vendor';

##### test for duplicate invnumber for different vendor
my $different_vendor = new_vendor(
  name         => 'anderer Testlieferant',
  currency_id  => $currency_id,
  taxzone_id   => $taxzone->id,
  vendornumber => 777,
)->save;

$file = \<<"EOL";
datatype,vendornumber,currency_id,invnumber,taxincluded,apchart,transdate
datatype,accno,amount,taxkey
"Rechnung",777,1,"invoice 1",f,1600,"$transdate_string"
"AccTransaction",3400,159.48,9
EOL

$entries = test_import($file);
is $entries->[0]->{errors}->[0], undef, 'duplicate invnumber, different vendor: no errors in ap row';
is $entries->[1]->{errors}->[0], undef, 'duplicate invnumber, different vendor: no errors in acc_trans row';

$entry = $entries->[0];
is $entry->{object}->invnumber, 'invoice 1',           'duplicate invnumber, different vendor: invnumber ok';
is $entry->{object}->vendor_id, $different_vendor->id, 'duplicate invnumber, different vendor: vendor_id ok';

$saved_invoices++;

##### test for no invnumber given
$file = \<<"EOL";
datatype,vendornumber,currency_id,taxincluded,apchart,transdate
datatype,accno,amount,taxkey
"Rechnung",2,1,f,1600,"$transdate_string"
"AccTransaction",3400,159.48,9
EOL

$entries = test_import($file);
$entry = $entries->[0];
$entry->{object}->validate_acc_trans;
is $entry->{errors}->[0], 'Error: Invoice Number missing', 'detects missing invnubmer';


##### basic test without amounts in Rechnung, only specified in AccTransaction
$file = \<<"EOL";
datatype,vendornumber,currency_id,invnumber,taxincluded,apchart,transdate
datatype,accno,amount,taxkey
"Rechnung",2,1,"invoice 1 no amounts",f,1600,"$transdate_string"
"AccTransaction",3400,159.48,9
EOL
$entries = test_import($file);
is $entries->[0]->{errors}->[0], undef, 'basic test no amounts: no errors in ap row';
is $entries->[1]->{errors}->[0], undef, 'basic test no amounts: no errors in acc_trans row';

$entry = $entries->[0];
is $entry->{object}->validate_acc_trans, 1, 'basic test no amounts: acc_trans validates';
is $entry->{object}->invnumber, 'invoice 1 no amounts', 'basic test no amounts: invnumber ok';
is $entry->{object}->vendor_id, $vendor->id, 'basic test no amounts: vendor_id ok';
is scalar @{$entry->{object}->transactions}, 3, 'basic test no amounts: invoice 1 has 3 acc_trans entries';
is $::form->round_amount($entry->{object}->amount, 2), '189.78', 'basic test no amounts: not taxincluded ap amount';
is $::form->round_amount($entry->{object}->transactions->[0]->amount, 2), '-159.48', 'basic test no amounts: not taxincluded acc_trans netamount';
is $::form->round_amount($entry->{object}->netamount, 2), 159.48, 'basic test no amounts: invoice 1 ap netamount is 159.48';

$saved_invoices++;

##### basic test: credit_note
$file = \<<"EOL";
datatype,vendornumber,currency_id,invnumber,taxincluded,apchart,transdate
datatype,accno,amount,taxkey
"Rechnung",2,1,"credit note",f,1600,"$transdate_string"
"AccTransaction",3400,-159.48,9
EOL
$entries = test_import($file);
is $entries->[0]->{errors}->[0], undef, 'basic test: credit_note: no errors in ap row';
is $entries->[1]->{errors}->[0], undef, 'basic test: credit_note: no errors in acc_trans row';

$entry = $entries->[0];
is $entry->{object}->validate_acc_trans, 1, 'basic test: credit_note: acc_trans validates';
is $entry->{object}->invnumber, 'credit note', 'basic test: credit_note: invnumber ok';
is scalar @{$entry->{object}->transactions}, 3, 'basic test: credit_note: credit note has 3 acc_trans entries';
is $::form->round_amount($entry->{object}->amount, 2), '-189.78', 'basic test: credit_note: taxincluded ap amount';
is $::form->round_amount($entry->{object}->netamount, 2), '-159.48', 'basic test: credit_note: taxincluded ap net amount';
is $::form->round_amount($entry->{object}->transactions->[0]->amount, 2), 159.48, 'credit note ap amount is 159.48';

$saved_invoices++;

#### verify_amount differs: max_amount_diff = 0.02, 189.80 is ok, 189.81 is not
$file = \<<"EOL";
datatype,vendornumber,verify_amount,verify_netamount,currency_id,invnumber,taxincluded,apchart,transdate
datatype,accno,amount,taxkey
"Rechnung",2,189.81,159.48,1,"invoice amounts differing",f,1600,"$transdate_string"
"AccTransaction",3400,159.48,9
EOL
$entries = test_import($file);

$entry = $entries->[0];
is $entry->{errors}->[0], 'Amounts differ too much', 'detects verify_amount differences';

#####  direct debit
$file = \<<"EOL";
datatype,vendornumber,currency_id,invnumber,taxincluded,direct_debit,apchart,transdate
datatype,accno,amount,taxkey
"Rechnung",2,1,"invoice with direct debit",f,t,1600,"$transdate_string"
"AccTransaction",3400,159.48,9
EOL

$entries = test_import($file);
is $entries->[0]->{errors}->[0], undef, 'direct debit: no errors in ap row';
is $entries->[1]->{errors}->[0], undef, 'direct debit: no errors in acc_trans row';

$entry = $entries->[0];
is $entry->{object}->validate_acc_trans, 1, 'direct debit: acc_trans validates';
is $entry->{object}->direct_debit, '1', 'direct debit';

$saved_invoices++;

#### tax included
$file = \<<"EOL";
datatype,vendornumber,currency_id,invnumber,taxincluded,apchart,transdate
datatype,accno,amount,taxkey
"Rechnung",2,1,"invoice 1 tax included no amounts",t,1600,"$transdate_string"
"AccTransaction",3400,189.78,9
EOL

$entries = test_import($file);
$entry = $entries->[0];

is $entry->{errors}->[0], undef, 'tax included: no errors in ap row';
is $entry->{errors}->[1], undef, 'tax included: no errors in acc_trans row';

is $entry->{object}->validate_acc_trans, 1, 'tax included: acc_trans validates';

is $entry->{object}->taxincluded, '1', 'tax included: taxincluded is true';
is $::form->round_amount($entry->{object}->amount, 2), '189.78', 'tax included: ap amount';
is $::form->round_amount($entry->{object}->netamount, 2), '159.48', 'tax included: ap net amount';
is $::form->round_amount($entry->{object}->transactions->[0]->amount, 2), '-159.48', 'tax included: acc_trans netamount';

$saved_invoices++;

#### multiple tax included
$file = \<<"EOL";
datatype,vendornumber,currency_id,invnumber,taxincluded,apchart,transdate
datatype,accno,amount,taxkey
"Rechnung",2,1,"invoice multiple tax included",t,1600,"$transdate_string"
"AccTransaction",3400,94.89,9
"AccTransaction",3400,94.89,9
EOL

$entries = test_import($file);
is $entries->[0]->{errors}->[0], undef, 'multiple tax included: no errors in ap row';
is $entries->[1]->{errors}->[0], undef, 'multiple tax included: no errors in 1. acc_trans row';
is $entries->[2]->{errors}->[0], undef, 'multiple tax included: no errors in 2. acc_trans row';

$entry = $entries->[0];
is $entry->{object}->validate_acc_trans, 1, 'multiple tax included: acc_trans validates';

is $::form->round_amount($entry->{object}->amount, 2),    '189.78', 'multiple tax included: ap amount';
is $::form->round_amount($entry->{object}->netamount, 2), '159.48', 'multiple tax included: ap netamount';
is $::form->round_amount($entry->{object}->transactions->[0]->amount, 2), '-79.74', 'multiple tax included: amount';
is $::form->round_amount($entry->{object}->transactions->[1]->amount, 2), '-15.15', 'multiple tax included: tax';

$saved_invoices++;

# different payable chart
$file = \<<EOL;
datatype,vendornumber,currency_id,invnumber,taxincluded,apchart
datatype,accno,amount,taxkey
"Rechnung",2,1,"invoice mit apchart 1605",f,1605
"AccTransaction",3400,159.48,9
EOL

$entries = test_import($file);
is $entries->[0]->{errors}->[0], undef, 'different payable chart: no errors in ap row';
is $entries->[1]->{errors}->[0], undef, 'different payable chart: no errors in acc_trans row';

$entry = $entries->[0];
is $entry->{object}->validate_acc_trans, 1, 'different payable chart: acc_trans validates';
is $entry->{object}->transactions->[2]->chart->accno, '1605', 'different payable chart: apchart set to 1605';

$saved_invoices++;

# missing vendor
$file = \<<EOL;
datatype,currency_id,invnumber,taxincluded,apchart
datatype,accno,amount,taxkey
"Rechnung",1,"invoice missing vendor",f,1600
"AccTransaction",3400,159.48,9
EOL

$entries = test_import($file);
$entry = $entries->[0];
is $entry->{errors}->[0], 'Error: Vendor missing', 'detects missing vendor';

##### vendor by name
$file = \<<EOL;
datatype,vendor,currency_id,invnumber,taxincluded,apchart
datatype,accno,amount,taxkey
"Rechnung","Testlieferant",1,"invoice vendor name",f,1600
"AccTransaction",3400,159.48,9
EOL

$entries = test_import($file);
is $entries->[0]->{errors}->[0], undef, 'vendor by name: no errors in ap row';
is $entries->[1]->{errors}->[0], undef, 'vendor by name: no errors in acc_trans row';

$entry = $entries->[0];
is $entry->{object}->validate_acc_trans, 1, 'vendor by name: acc_trans validates';
is $entry->{object}->vendor->name, "Testlieferant", 'detects vendor by name';

$saved_invoices++;

##### detect missing chart
$file = \<<EOL;
datatype,currency_id,invnumber,vendor,apchart
datatype,amount,taxkey
"Rechnung",1,"invoice missing chart","Testlieferant",1600
"AccTransaction",4,9
EOL

$entries = test_import($file);

$entry = $entries->[1];
is $entry->{errors}->[0], 'Error: chart missing', 'detects missing chart (chart_id or accno)';

##### detect illegal chart by accno
$file = \<<EOL;
datatype,currency_id,invnumber,vendor,apchart
datatype,accno,amount,taxkey
"Rechnung",1,"invoice illegal chart accno","Testlieferant",1600
"AccTransaction",9999,4,9
EOL

$entries = test_import($file);

$entry = $entries->[1];
is $entry->{errors}->[0], 'Error: invalid chart (accno)', 'detects invalid chart (chart_id or accno)';

# ##### detect illegal apchart
$file = \<<EOL;
datatype,currency_id,invnumber,vendor,taxincluded,apchart
datatype,accno,amount,taxkey
"Rechnung",1,"invoice illegal apchart","Testlieferant",f,11600
"AccTransaction",3400,159.48,9
EOL

$entries = test_import($file);

$entry = $entries->[0];
is $entry->{errors}->[0], "Error: can't find ap chart with accno 11600", 'detects illegal payable chart (apchart)';

##### detect chart by id
$file = \<<EOL;
datatype,currency_id,invnumber,vendor,taxincluded,apchart
datatype,amount,chart_id,taxkey
"Rechnung",1,"invoice chart_id","Testlieferant",f,1600
"AccTransaction",159.48,37,9
EOL

$entries = test_import($file);
is $entries->[0]->{errors}->[0], undef, 'detect chart by id: no errors in ap row';
is $entries->[1]->{errors}->[0], undef, 'detect chart by id: no errors in acc_trans row';

$entry = $entries->[0];
is $entry->{object}->validate_acc_trans, 1, 'detect chart by id: acc_trans validates';

$entry = $entries->[1]; # acc_trans entry is at entry array pos 1
is $entry->{object}->chart->id, "37", 'detects chart by id';

$saved_invoices++;

##### detect chart by accno
$file = \<<EOL;
datatype,currency_id,invnumber,vendor,taxincluded,apchart
datatype,amount,accno,taxkey
"Rechnung",1,"invoice by chart accno","Testlieferant",f,1600
"AccTransaction",159.48,3400,9
EOL

$entries = test_import($file);
is $entries->[0]->{errors}->[0], undef, 'detect chart by accno: no errors in ap row';
is $entries->[1]->{errors}->[0], undef, 'detect chart by accno: no errors in acc_trans row';

$entry = $entries->[0];
is $entry->{object}->validate_acc_trans, 1, 'detect chart by accno: acc_trans validates';

$entry = $entries->[1];
is $entry->{object}->chart->accno, "3400", 'detects chart by accno';

$saved_invoices++;

##### detect chart isn't an ap_chart
$file = \<<EOL;
datatype,currency_id,invnumber,vendor,taxincluded,apchart
datatype,amount,accno,taxkey
"Rechnung",1,"invoice by chart accno","Testlieferant",f,1600
"AccTransaction",159.48,1600,9
EOL

$entries = test_import($file);

$entry = $entries->[1];
is $entry->{errors}->[0], 'Error: chart isn\'t an ap_amount chart', 'detects valid chart that is not an ap_amount chart';

# missing taxkey
$file = \<<EOL;
datatype,currency_id,invnumber,vendor,apchart
datatype,amount,accno
"Rechnung",1,"invoice missing taxkey chart accno","Testlieferant",1600
"AccTransaction",159.48,3400
EOL

$entries = test_import($file);

$entry = $entries->[1];
is $entry->{errors}->[0], 'Error: taxkey missing', 'detects missing taxkey (DATEV Steuerschlüssel)';

# illegal taxkey
$file = \<<EOL;
datatype,currency_id,invnumber,vendor,apchart
datatype,amount,accno,taxkey
"Rechnung",1,"invoice illegal taxkey","Testlieferant",1600
"AccTransaction",4,3400,123
EOL

$entries = test_import($file);

$entry = $entries->[1];
is $entry->{errors}->[0], 'Error: invalid taxkey', 'detects invalid taxkey (DATEV Steuerschlüssel)';

# taxkey
$file = \<<EOL;
datatype,vendornumber,currency_id,invnumber,apchart,taxincluded
datatype,accno,amount,taxkey
"Rechnung",2,1,"invoice by taxkey",1600,1
"AccTransaction",3400,4,9
EOL

$entries = test_import($file);
is $entries->[0]->{errors}->[0], undef, 'taxkey: no errors in ap row';
is $entries->[1]->{errors}->[0], undef, 'taxkey: no errors in acc_trans row';

$entry = $entries->[1];
is $entry->{object}->taxkey, 9, 'detects taxkey';

$saved_invoices++;

# acc_trans project
$file = \<<EOL;
datatype,vendornumber,currency_id,invnumber,apchart,taxincluded
datatype,accno,amount,taxkey,projectnumber
"Rechnung",2,1,"invoice with acc_trans project",1600,f
"AccTransaction",3400,159.48,9,P1
EOL

$entries = test_import($file);
is $entries->[0]->{errors}->[0], undef, 'acc_trans project: no errors in ap row';
is $entries->[1]->{errors}->[0], undef, 'acc_trans project: no errors in acc_trans row';

$entry = $entries->[1];
is $entry->{object}->project->projectnumber, 'P1', 'detects acc_trans project';

$saved_invoices++;

#####  various tests
$file = \<<EOL;
datatype,vendornumber,currency_id,invnumber,taxincluded,apchart,transdate,duedate,globalprojectnumber,department
datatype,accno,amount,taxkey,projectnumber
"Rechnung",2,1,"invoice various",t,1600,21.04.2016,30.04.2016,P1,Department 1
"AccTransaction",3400,119,9,P1
"AccTransaction",3300,107,8,P1
"AccTransaction",3559,100,0,P1
EOL

$entries = test_import($file);
is $entries->[0]->{errors}->[0], undef, 'various tests: errors in ap row';
is $entries->[1]->{errors}->[0], undef, 'various tests: no errors in 1. acc_trans row';
is $entries->[2]->{errors}->[0], undef, 'various tests: no errors in 2. acc_trans row';
is $entries->[3]->{errors}->[0], undef, 'various tests: no errors in 3. acc_trans row';

$entry = $entries->[0];
is $entry->{object}->validate_acc_trans, 1, 'various tests: acc_trans validates';

is $entry->{object}->duedate->to_kivitendo,      '30.04.2016',    'various tests: duedate';
is $entry->{object}->transdate->to_kivitendo,    '21.04.2016',    'various tests: transdate';
is $entry->{object}->globalproject->description, 'Project X',     'various tests: project';
is $entry->{object}->department->description,    'Department 1',  'various tests: department';
# 3300 is third entry after 3400 and tax for 3400
is $::form->round_amount($entry->{object}->transactions->[2]->amount),     '-100',       '3300 net amount: -100';
is $entry->{object}->transactions->[2]->taxkey,                            '8',          '3300 has taxkey 8';
is $entry->{object}->transactions->[2]->project_id,                        $project->id, 'AccTrans project';

$saved_invoices++;

#####  ap amount test
$file = \<<EOL;
datatype,vendornumber,currency_id,invnumber,taxincluded,apchart,transdate,duedate,globalprojectnumber,department
datatype,accno,amount,taxkey,projectnumber
"Rechnung",2,1,"invoice various 1",t,1600,21.04.2016,30.04.2016,P1,Department 1
"AccTransaction",3400,119,9,P1
"AccTransaction",3300,107,8,P1
"AccTransaction",3559,100,0,P1
"Rechnung",2,1,"invoice various 2",t,1600,21.04.2016,30.04.2016,P1,Department 1
"AccTransaction",3400,119,9,P1
"AccTransaction",3400,107,8,P1
"AccTransaction",3559,100,0,P1
EOL

$entries = test_import($file);
is $entries->[0]->{errors}->[0], undef, 'ap amount test: no errors in 1. ap row';
is $entries->[1]->{errors}->[0], undef, 'ap amount test: no errors in 1. acc_trans row (ap row 1)';
is $entries->[2]->{errors}->[0], undef, 'ap amount test: no errors in 2. acc_trans row (ap row 1)';
is $entries->[3]->{errors}->[0], undef, 'ap amount test: no errors in 3. acc_trans row (ap row 1)';
is $entries->[4]->{errors}->[0], undef, 'ap amount test: no errors in 2. ap row';
is $entries->[5]->{errors}->[0], undef, 'ap amount test: no errors in 1. acc_trans row (ap row 2)';
is $entries->[6]->{errors}->[0], undef, 'ap amount test: no errors in 2. acc_trans row (ap row 2)';
is $entries->[7]->{errors}->[0], undef, 'ap amount test: no errors in 3. acc_trans row (ap row 2)';

$entry = $entries->[0];
is $entry->{object}->validate_acc_trans,    1,               'ap amount test: acc_trans validates';
is $entry->{object}->duedate->to_kivitendo, '30.04.2016',    'duedate';
is $entry->{info_data}->{calc_amount},      '326.00',        "First calculated invoice amount displayed in info data";
$entry = $entries->[4];
is $entry->{info_data}->{calc_amount},      '326.00',        "Second calculated invoice amount displayed in info data";

$saved_invoices++;
$saved_invoices++;

# multiple entries, taxincluded = f
$file = \<<EOL;
datatype,vendornumber,currency_id,invnumber,taxincluded,apchart
datatype,accno,amount,taxkey
"Rechnung",2,1,"invoice 4 acc_trans",f,1600
"AccTransaction",3400,39.87,9
"AccTransaction",3400,39.87,9
"AccTransaction",3400,39.87,9
"AccTransaction",3400,39.87,9
"Rechnung",2,1,"invoice 4 acc_trans 2",f,1600
"AccTransaction",3400,39.87,9
"AccTransaction",3400,39.87,9
"AccTransaction",3400,39.87,9
"AccTransaction",3400,39.87,9
"Rechnung",2,1,"invoice 4 acc_trans 3",f,1600
"AccTransaction",3400,39.87,9
"AccTransaction",3400,39.87,9
"AccTransaction",3400,39.87,9
"AccTransaction",3400,39.87,9
"Rechnung",2,1,"invoice 4 acc_trans 4",f,1605
"AccTransaction",3400,39.87,9
"AccTransaction",3400,39.87,9
"AccTransaction",3400,39.87,9
"AccTransaction",3400,39.87,9
EOL

$entries = test_import($file);

my $i = 0;
foreach my $entry ( @$entries ) {
  next unless $entry->{object}->isa('SL::DB::PurchaseInvoice');
  $i++;
  is scalar @{$entry->{object}->transactions}, 9, "multiple entries: invoice $i: 'acc_trans' has 9 acc_trans entries";
  $entry->{object}->validate_acc_trans;
  is $entry->{object}->validate_acc_trans,     1, "multiple entries: invoice $i: 'acc_trans validates'";
}

$saved_invoices++;
$saved_invoices++;
$saved_invoices++;
$saved_invoices++;

##### missing acc_trans
$file = \<<EOL;
datatype,vendornumber,currency_id,invnumber,taxincluded,apchart,transdate,duedate,globalprojectnumber,department
datatype,accno,amount,taxkey,projectnumber
"Rechnung",2,1,"invoice acc_trans missing",t,1600,21.04.2016,30.04.2016,P1,Department 1
"Rechnung",2,1,"invoice various a",t,1600,21.04.2016,30.04.2016,P1,Department 1
"AccTransaction",3400,119,9,P1
"AccTransaction",3300,107,8,P1
EOL

$entries = test_import($file);

$entry = $entries->[0];
is $entry->{errors}->[0], "Error: ap transaction doesn't validate", 'detects invalid ap, maybe acc_trans entry missing';

##### taxkey differs from active_taxkey
$file = \<<EOL;
datatype,vendornumber,currency_id,invnumber,taxincluded,apchart
datatype,accno,amount,taxkey
"Rechnung",2,1,"invoice 2 tax included no amounts",t,1600
"AccTransaction",3400,189.78,8
EOL

$entries = test_import($file);
is $entries->[0]->{errors}->[0], undef, 'taxkey differs from active_taxkey: no errors in ap row';
is $entries->[1]->{errors}->[0], undef, 'taxkey differs from active_taxkey: no errors in acc_trans row';

$entry = $entries->[0];
is $entry->{object}->transactions->[1]->taxkey, '8', 'taxkey differs from active_taxkey';

$saved_invoices++;

##### verify amounts, error only once
$file = \<<EOL;
datatype,vendornumber,currency_id,invnumber,taxincluded,apchart,verify_netamount,verify_amount
datatype,accno,amount,taxkey
"Rechnung",2,1,"first invoice",f,1600,39.87,47.44
"AccTransaction",3400,39.87,9
"Rechnung",2,1,"second invoice",f,1600,39.78,78.39
"AccTransaction",3400,39.87,9
EOL

$entries = test_import($file);

$entry = $entries->[0];
is $entry->{errors}->[0], undef,                         'verify amounts, error only once: no error in first invoice';

$entry = $entries->[2];
is $entry->{errors}->[0], "Amounts differ too much",     'verify amounts, error only once: amount differs';
is $entry->{errors}->[1], "Net amounts differ too much", 'verify amounts, error only once: netamount differs';
is $entry->{errors}->[2], undef,                         'verify amounts, error only once: nothing else';

$saved_invoices++;

#####
my $number_of_imported_invoices = SL::DB::Manager::PurchaseInvoice->get_all_count;
is $number_of_imported_invoices, $saved_invoices, 'All invoices saved';

#####
clear_up(); # remove all data at end of tests

# end of tests
done_testing;

1;

#####
# vim: ft=perl
# set emacs to perl mode
# Local Variables:
# mode: perl
# End:
