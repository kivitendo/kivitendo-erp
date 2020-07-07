use Test::More tests => 70;

use strict;

use lib 't';

use Carp;
use Data::Dumper;
use Support::TestSetup;
use Test::Exception;

use List::MoreUtils qw(pairwise);
use SL::Controller::CsvImport;

my $DEBUG = 0;

use_ok 'SL::Controller::CsvImport::ARTransaction';

use SL::DB::Buchungsgruppe;
use SL::DB::Currency;
use SL::DB::Customer;
use SL::DB::Employee;
use SL::DB::Invoice;
use SL::DB::TaxZone;
use SL::DB::Chart;
use SL::DB::AccTransaction;

my ($customer, $currency_id, $employee, $taxzone, $project, $department);
my ($transdate, $transdate_string);

sub reset_state {
  # Create test data
  my %params = @_;

  $transdate = DateTime->today_local;
  $transdate->set_year(2019) if $transdate->year == 2020; # hardcode for 2019 in 2020, because of tax rate change in Germany
  $transdate_string = $transdate->to_kivitendo;

  $params{$_} ||= {} for qw(buchungsgruppe customer tax);

  clear_up();
  $employee        = SL::DB::Manager::Employee->current                          || croak "No employee";
  $taxzone         = SL::DB::Manager::TaxZone->find_by( description => 'Inland') || croak "No taxzone";
  $currency_id     = $::instance_conf->get_currency_id;

  $customer     = SL::DB::Customer->new(
    name        => 'Test Customer',
    currency_id => $currency_id,
    taxzone_id  => $taxzone->id,
    %{ $params{customer} }
  )->save;

  $project     = SL::DB::Project->new(
    projectnumber  => 'P1',
    description    => 'Project X',
    project_type   => SL::DB::Manager::ProjectType->find_by(description => 'Standard'),
    project_status => SL::DB::Manager::ProjectStatus->find_by(name => 'running'),
  )->save;

  $department     = SL::DB::Department->new(
    description    => 'Department 1',
  )->save;
}

Support::TestSetup::login();

reset_state(customer => {id => 960, customernumber => 2});

#####
sub test_import {
  my $file = shift;

  my $controller = SL::Controller::CsvImport->new(
    type => 'ar_transactions'
  );
  $controller->load_default_profile;
  $controller->profile->set(
    charset      => 'utf-8',
    sep_char     => ',',
    quote_char   => '"',
    numberformat => $::myconfig{numberformat},
  );

  my $csv_artransactions_import = SL::Controller::CsvImport::ARTransaction->new(
    settings    => {'ar_column'          => 'Rechnung',
                    'transaction_column' => 'AccTransaction',
                    'max_amount_diff'    => 0.02
                  },
    controller => $controller,
    file       => $file,
  );

  # $csv_artransactions_import->init_vc_by;
  $csv_artransactions_import->run(test => 0);

  # don't try and save objects that have errors
  $csv_artransactions_import->save_objects unless scalar @{$csv_artransactions_import->controller->data->[0]->{errors}};

 return $csv_artransactions_import->controller->data;
}

##### manually create an ar transaction from scratch, testing the methods
$::myconfig{numberformat} = '1000.00';
$::myconfig{dateformat}   = 'dd.mm.yyyy';
my $old_locale = $::locale;
# set locale to en so we can match errors
$::locale = Locale->new('en');

my $amount = 10;

my $ar = SL::DB::Invoice->new(
  invoice      => 0,
  invnumber    => 'manual invoice',
  taxzone_id   => $taxzone->id,
  currency_id  => $currency_id,
  taxincluded  => 'f',
  customer_id  => $customer->id,
  transdate    => $transdate,
  employee_id  => SL::DB::Manager::Employee->current->id,
  transactions => [],
);

my $tax3 = SL::DB::Manager::Tax->find_by(rate => 0.19, taxkey => 3) || die "can't find tax with taxkey 3";
my $income_chart = SL::DB::Manager::Chart->find_by(accno => '8400') || die "can't find income chart";

$ar->add_ar_amount_row(
  amount => $amount,
  chart  => $income_chart,
  tax_id => $tax3->id,
);

$ar->recalculate_amounts; # set amount and netamount from transactions
is $ar->amount, '10', 'amount of manual invoice is 10';
is $ar->netamount, '8.4', 'netamount of manual invoice is 10';

$ar->create_ar_row( chart => SL::DB::Manager::Chart->find_by(accno => '1400', link => 'AR') );
my $result = $ar->validate_acc_trans(debug => 0);
is $result, 1, 'manual $ar validates';

$ar->save;
is ${ $ar->transactions }[0]->chart->accno, '8400', 'assigned income chart after save ok';
is ${ $ar->transactions }[2]->chart->accno, '1400', 'assigned receivable chart after save ok';
is scalar @{$ar->transactions}, 3, 'manual invoice has 3 acc_trans entries';

$ar->pay_invoice(  chart_id      => SL::DB::Manager::Chart->find_by(accno => '1200')->id, # bank
                   amount        => $ar->open_amount,
                   transdate     => $transdate,
                   payment_type  => 'without_skonto',  # default if not specified
                  );
$result = $ar->validate_acc_trans(debug => 0);
is $result, 1, 'manual invoice validates after payment';

reset_state(customer => {id => 960, customernumber => 2});

my ($entries, $entry, $file);

# starting test of csv imports
# to debug errors in certain tests, run after test_import:
#   die Dumper($entry->{errors});
##### basic test
$file = \<<"EOL";
datatype,customer_id,taxzone_id,currency_id,invnumber,taxincluded,archart,transdate
datatype,accno,amount,taxkey
"Rechnung",960,4,1,"invoice 1",f,1400,"$transdate_string"
"AccTransaction",8400,159.48,3
EOL
$entries = test_import($file);
$entry = $entries->[0];
$entry->{object}->validate_acc_trans;

is $entry->{object}->invnumber, 'invoice 1', 'simple invnumber ok (customer)';
is $entry->{object}->customer_id, '960', 'simple customer_id ok (customer)';
is scalar @{$entry->{object}->transactions}, 3, 'invoice 1 has 3 acc_trans entries';
is $::form->round_amount($entry->{object}->transactions->[0]->amount, 2), 159.48, 'invoice 1 ar amount is 159.48';
is $entry->{object}->direct_debit, '0', 'no direct debit';
is $entry->{object}->taxincluded, '0', 'taxincluded is false';
is $entry->{object}->amount, '189.78', 'ar amount tax not included is 189.78';
is $entry->{object}->netamount, '159.48', 'ar netamount tax not included is 159.48';

##### test for duplicate invnumber
$file = \<<"EOL";
datatype,customer_id,taxzone_id,currency_id,invnumber,taxincluded,archart,transdate
datatype,accno,amount,taxkey
"Rechnung",960,4,1,"invoice 1",f,1400,"$transdate_string"
"AccTransaction",8400,159.48,3
EOL
$entries = test_import($file);
$entry = $entries->[0];
$entry->{object}->validate_acc_trans;
is $entry->{errors}->[0], 'Error: invnumber already exists', 'detects verify_amount differences';

##### test for no invnumber given
$file = \<<"EOL";
datatype,customer_id,taxzone_id,currency_id,taxincluded,archart,transdate
datatype,accno,amount,taxkey
"Rechnung",960,4,1,f,1400,"$transdate_string"
"AccTransaction",8400,159.48,3
EOL
$entries = test_import($file);
$entry = $entries->[0];
$entry->{object}->validate_acc_trans;
is $entry->{object}->invnumber =~ /^\d+$/, 1, 'invnumber assigned automatically';

##### basic test without amounts in Rechnung, only specified in AccTransaction
$file = \<<"EOL";
datatype,customer_id,taxzone_id,currency_id,invnumber,taxincluded,archart,transdate
datatype,accno,amount,taxkey
"Rechnung",960,4,1,"invoice 1 no amounts",f,1400,"$transdate_string"
"AccTransaction",8400,159.48,3
EOL
$entries = test_import($file);
$entry = $entries->[0];
$entry->{object}->validate_acc_trans;

is $entry->{object}->invnumber, 'invoice 1 no amounts', 'simple invnumber ok (customer)';
is $entry->{object}->customer_id, '960', 'simple customer_id ok (customer)';
is scalar @{$entry->{object}->transactions}, 3, 'invoice 1 has 3 acc_trans entries';
is $::form->round_amount($entry->{object}->amount, 2), '189.78', 'not taxincluded ar amount';
is $::form->round_amount($entry->{object}->transactions->[0]->amount, 2), '159.48', 'not taxincluded acc_trans netamount';
is $::form->round_amount($entry->{object}->transactions->[0]->amount, 2), 159.48, 'invoice 1 ar amount is 159.48';

##### basic test: credit_note
$file = \<<"EOL";
datatype,customer_id,taxzone_id,currency_id,invnumber,taxincluded,archart,transdate
datatype,accno,amount,taxkey
"Rechnung",960,4,1,"credit note",f,1400,"$transdate_string"
"AccTransaction",8400,-159.48,3
EOL
$entries = test_import($file);
$entry = $entries->[0];
$entry->{object}->validate_acc_trans;

is $entry->{object}->invnumber, 'credit note', 'simple credit note ok';
is scalar @{$entry->{object}->transactions}, 3, 'credit note has 3 acc_trans entries';
is $::form->round_amount($entry->{object}->amount, 2), '-189.78', 'taxincluded ar amount';
is $::form->round_amount($entry->{object}->netamount, 2), '-159.48', 'taxincluded ar net amount';
is $::form->round_amount($entry->{object}->transactions->[0]->amount, 2), -159.48, 'credit note ar amount is -159.48';
is $entry->{object}->amount, '-189.78', 'credit note amount tax not included is 189.78';
is $entry->{object}->netamount, '-159.48', 'credit note netamount tax not included is 159.48';

#### verify_amount differs: max_amount_diff = 0.02, 189.80 is ok, 189.81 is not
$file = \<<"EOL";
datatype,customer_id,verify_amount,verify_netamount,taxzone_id,currency_id,invnumber,taxincluded,archart,transdate
datatype,accno,amount,taxkey
"Rechnung",960,189.81,159.48,4,1,"invoice amounts differing",f,1400,"$transdate_string"
"AccTransaction",8400,159.48,3
EOL
$entries = test_import($file);
$entry = $entries->[0];
is $entry->{errors}->[0], 'Amounts differ too much', 'detects verify_amount differences';

#####  direct debit
$file = \<<"EOL";
datatype,customer_id,taxzone_id,currency_id,invnumber,taxincluded,direct_debit,archart,transdate
datatype,accno,amount,taxkey
"Rechnung",960,4,1,"invoice with direct debit",f,t,1400,"$transdate_string"
"AccTransaction",8400,159.48,3
EOL

$entries = test_import($file);
$entry = $entries->[0];
$entry->{object}->validate_acc_trans;
is $entry->{object}->direct_debit, '1', 'direct debit';

#### tax included
$file = \<<"EOL";
datatype,customer_id,taxzone_id,currency_id,invnumber,taxincluded,archart,transdate
datatype,accno,amount,taxkey
"Rechnung",960,4,1,"invoice 1 tax included no amounts",t,1400,"$transdate_string"
"AccTransaction",8400,189.78,3
EOL

$entries = test_import($file);
$entry = $entries->[0];
$entry->{object}->validate_acc_trans(debug => 0);
is $entry->{object}->taxincluded, '1', 'taxincluded is true';
is $::form->round_amount($entry->{object}->amount, 2), '189.78', 'taxincluded ar amount';
is $::form->round_amount($entry->{object}->netamount, 2), '159.48', 'taxincluded ar net amount';
is $::form->round_amount($entry->{object}->transactions->[0]->amount, 2), '159.48', 'taxincluded acc_trans netamount';

#### multiple tax included
$file = \<<"EOL";
datatype,customer_id,taxzone_id,currency_id,invnumber,taxincluded,archart,transdate
datatype,accno,amount,taxkey
"Rechnung",960,4,1,"invoice multiple tax included",t,1400,"$transdate_string"
"AccTransaction",8400,94.89,3
"AccTransaction",8400,94.89,3
EOL

$entries = test_import($file);
$entry = $entries->[0];
$entry->{object}->validate_acc_trans;
is $::form->round_amount($entry->{object}->amount, 2),    '189.78', 'taxincluded ar amount';
is $::form->round_amount($entry->{object}->netamount, 2), '159.48', 'taxincluded ar netamount';
is $::form->round_amount($entry->{object}->transactions->[0]->amount, 2), '79.74', 'taxincluded amount';
is $::form->round_amount($entry->{object}->transactions->[1]->amount, 2), '15.15', 'taxincluded tax';

# different receivables chart
$file = \<<EOL;
datatype,customer_id,taxzone_id,currency_id,invnumber,taxincluded,archart
datatype,accno,amount,taxkey
"Rechnung",960,4,1,"invoice mit archart 1448",f,1448
"AccTransaction",8400,159.48,3
EOL
$entries = test_import($file);
$entry = $entries->[0];
$entry->{object}->validate_acc_trans;
is $entry->{object}->transactions->[2]->chart->accno, '1448', 'archart set to 1448';

# missing customer
$file = \<<EOL;
datatype,taxzone_id,currency_id,invnumber,taxincluded,archart
datatype,accno,amount,taxkey
"Rechnung",4,1,"invoice missing customer",f,1400
"AccTransaction",8400,159.48,3
EOL
$entries = test_import($file);
$entry = $entries->[0];
is $entry->{errors}->[0], 'Error: Customer/vendor missing', 'detects missing customer or vendor';


##### customer by name
$file = \<<EOL;
datatype,customer,taxzone_id,currency_id,invnumber,taxincluded,archart
datatype,accno,amount,taxkey
"Rechnung","Test Customer",4,1,"invoice customer name",f,1400
"AccTransaction",8400,159.48,3
EOL
$entries = test_import($file);
$entry = $entries->[0];
$entry->{object}->validate_acc_trans;
is $entry->{object}->customer->name, "Test Customer", 'detects customer by name';

##### detect missing chart
$file = \<<EOL;
datatype,taxzone_id,currency_id,invnumber,customer,archart
datatype,amount,taxkey
"Rechnung",4,1,"invoice missing chart","Test Customer",1400
"AccTransaction",4,3
EOL
$entries = test_import($file);
$entry = $entries->[1];
is $entry->{errors}->[0], 'Error: chart missing', 'detects missing chart (chart_id or accno)';

##### detect illegal chart by accno
$file = \<<EOL;
datatype,taxzone_id,currency_id,invnumber,customer,archart
datatype,accno,amount,taxkey
"Rechnung",4,1,"invoice illegal chart accno","Test Customer",1400
"AccTransaction",9999,4,3
EOL
$entries = test_import($file);
$entry = $entries->[1];
is $entry->{errors}->[0], 'Error: invalid chart (accno)', 'detects invalid chart (chart_id or accno)';

# ##### detect illegal archart
$file = \<<EOL;
datatype,taxzone_id,currency_id,invnumber,customer,taxincluded,archart
datatype,accno,amount,taxkey
"Rechnung",4,1,"invoice illegal archart","Test Customer",f,11400
"AccTransaction",8400,159.48,3
EOL
$entries = test_import($file);
$entry = $entries->[0];
is $entry->{errors}->[0], "Error: can't find ar chart with accno 11400", 'detects illegal receivables chart (archart)';

##### detect chart by id
$file = \<<EOL;
datatype,taxzone_id,currency_id,invnumber,customer,taxincluded,archart
datatype,amount,chart_id,taxkey
"Rechnung",4,1,"invoice chart_id","Test Customer",f,1400
"AccTransaction",159.48,184,3
EOL
$entries = test_import($file);
$entry = $entries->[1]; # acc_trans entry is at entry array pos 1
$entries->[0]->{object}->validate_acc_trans;
is $entry->{object}->chart->id, "184", 'detects chart by id';

##### detect chart by accno
$file = \<<EOL;
datatype,taxzone_id,currency_id,invnumber,customer,taxincluded,archart
datatype,amount,accno,taxkey
"Rechnung",4,1,"invoice by chart accno","Test Customer",f,1400
"AccTransaction",159.48,8400,3
EOL
$entries = test_import($file);
$entry = $entries->[1];
$entries->[0]->{object}->validate_acc_trans;
is $entry->{object}->chart->accno, "8400", 'detects chart by accno';

##### detect chart isn't an ar_chart
$file = \<<EOL;
datatype,taxzone_id,currency_id,invnumber,customer,taxincluded,archart
datatype,amount,accno,taxkey
"Rechnung",4,1,"invoice by chart accno","Test Customer",f,1400
"AccTransaction",159.48,1400,3
EOL
$entries = test_import($file);
$entry = $entries->[1];
$entries->[0]->{object}->validate_acc_trans;
is $entry->{errors}->[0], 'Error: chart isn\'t an ar_amount chart', 'detects valid chart that is not an ar_amount chart';

# missing taxkey
$file = \<<EOL;
datatype,taxzone_id,currency_id,invnumber,customer,archart
datatype,amount,accno
"Rechnung",4,1,"invoice missing taxkey chart accno","Test Customer",1400
"AccTransaction",159.48,8400
EOL
$entries = test_import($file);
$entry = $entries->[1];
is $entry->{errors}->[0], 'Error: taxkey missing', 'detects missing taxkey (DATEV Steuerschlüssel)';

# illegal taxkey
$file = \<<EOL;
datatype,taxzone_id,currency_id,invnumber,customer,archart
datatype,amount,accno,taxkey
"Rechnung",4,1,"invoice illegal taxkey","Test Customer",1400
"AccTransaction",4,8400,123
EOL
$entries = test_import($file);
$entry = $entries->[1];
is $entry->{errors}->[0], 'Error: invalid taxkey', 'detects invalid taxkey (DATEV Steuerschlüssel)';

# taxkey
$file = \<<EOL;
datatype,customer_id,taxzone_id,currency_id,invnumber,archart
datatype,accno,amount,taxkey
"Rechnung",960,4,1,"invoice by taxkey",1400
"AccTransaction",8400,4,3
EOL

$entries = test_import($file);
$entry = $entries->[1];
is $entry->{object}->taxkey, 3, 'detects taxkey';

# acc_trans project
$file = \<<EOL;
datatype,customer_id,taxzone_id,currency_id,invnumber,archart,taxincluded
datatype,accno,amount,taxkey,projectnumber
"Rechnung",960,4,1,"invoice with acc_trans project",1400,f
"AccTransaction",8400,159.48,3,P1
EOL

$entries = test_import($file);
$entry = $entries->[1];
# die Dumper($entries->[0]->{errors}) if scalar @{$entries->[0]->{errors}};
is $entry->{object}->project->projectnumber, 'P1', 'detects acc_trans project';

#####  various tests
$file = \<<EOL;
datatype,customer_id,taxzone_id,currency_id,invnumber,taxincluded,archart,transdate,duedate,globalprojectnumber,department
datatype,accno,amount,taxkey,projectnumber
"Rechnung",960,4,1,"invoice various",t,1400,21.04.2016,30.04.2016,P1,Department 1
"AccTransaction",8400,119,3,P1
"AccTransaction",8300,107,2,P1
"AccTransaction",8200,100,0,P1
EOL

$entries = test_import($file);
$entry = $entries->[0];
$entry->{object}->validate_acc_trans;
is $entry->{object}->duedate->to_kivitendo,      '30.04.2016',    'duedate';
is $entry->{object}->transdate->to_kivitendo,    '21.04.2016',    'transdate';
is $entry->{object}->globalproject->description, 'Project X',     'project';
is $entry->{object}->department->description,    'Department 1',  'department';
# 8300 is third entry after 8400 and tax for 8400
is $::form->round_amount($entry->{object}->transactions->[2]->amount),     '100',        '8300 net amount: 100';
is $::form->round_amount($entry->{object}->transactions->[2]->taxkey),     '2',          '8300 has taxkey 2';
is $::form->round_amount($entry->{object}->transactions->[2]->project_id), $project->id, 'AccTrans project';

#####  ar amount test
$file = \<<EOL;
datatype,customer_id,taxzone_id,currency_id,invnumber,taxincluded,archart,transdate,duedate,globalprojectnumber,department
datatype,accno,amount,taxkey,projectnumber
"Rechnung",960,4,1,"invoice various 1",t,1400,21.04.2016,30.04.2016,P1,Department 1
"AccTransaction",8400,119,3,P1
"AccTransaction",8300,107,2,P1
"AccTransaction",8200,100,0,P1
"Rechnung",960,4,1,"invoice various 2",t,1400,21.04.2016,30.04.2016,P1,Department 1
"AccTransaction",8400,119,3,P1
"AccTransaction",8300,107,2,P1
"AccTransaction",8200,100,0,P1
EOL

$entries = test_import($file);
$entry = $entries->[0];
$entry->{object}->validate_acc_trans;
is $entry->{object}->duedate->to_kivitendo,      '30.04.2016',    'duedate';
is $entry->{info_data}->{amount}, '326', "First invoice amount displayed in info data";
is $entries->[4]->{info_data}->{amount}, '326', "Second invoice amount displayed in info data";

# multiple entries, taxincluded = f
$file = \<<EOL;
datatype,customer_id,taxzone_id,currency_id,invnumber,taxincluded,archart
datatype,accno,amount,taxkey
"Rechnung",960,4,1,"invoice 4 acc_trans",f,1400
"AccTransaction",8400,39.87,3
"AccTransaction",8400,39.87,3
"AccTransaction",8400,39.87,3
"AccTransaction",8400,39.87,3
"Rechnung",960,4,1,"invoice 4 acc_trans 2",f,1400
"AccTransaction",8400,39.87,3
"AccTransaction",8400,39.87,3
"AccTransaction",8400,39.87,3
"AccTransaction",8400,39.87,3
"Rechnung",960,4,1,"invoice 4 acc_trans 3",f,1400
"AccTransaction",8400,39.87,3
"AccTransaction",8400,39.87,3
"AccTransaction",8400,39.87,3
"AccTransaction",8400,39.87,3
"Rechnung",960,4,1,"invoice 4 acc_trans 4",f,1448
"AccTransaction",8400,39.87,3
"AccTransaction",8400,39.87,3
"AccTransaction",8400,39.87,3
"AccTransaction",8400,39.87,3
EOL
$entries = test_import($file);

my $i = 0;
foreach my $entry ( @$entries ) {
  next unless $entry->{object}->isa('SL::DB::Invoice');
  $i++;
  is scalar @{$entry->{object}->transactions}, 9, "invoice $i: 'invoice 4 acc_trans' has 9 acc_trans entries";
  $entry->{object}->validate_acc_trans;
};

##### missing acc_trans
$file = \<<EOL;
datatype,customer_id,taxzone_id,currency_id,invnumber,taxincluded,archart,transdate,duedate,globalprojectnumber,department
datatype,accno,amount,taxkey,projectnumber
"Rechnung",960,4,1,"invoice acc_trans missing",t,1400,21.04.2016,30.04.2016,P1,Department 1
"Rechnung",960,4,1,"invoice various a",t,1400,21.04.2016,30.04.2016,P1,Department 1
"AccTransaction",8400,119,3,P1
"AccTransaction",8300,107,2,P1
EOL

$entries = test_import($file);
$entry = $entries->[0];
is $entry->{errors}->[0], "Error: ar transaction doesn't validate", 'detects invalid ar, maybe acc_trans entry missing';

my $number_of_imported_invoices = SL::DB::Manager::Invoice->get_all_count;
is $number_of_imported_invoices, 19, 'All invoices saved';

#### taxkey differs from active_taxkey
$file = \<<EOL;
datatype,customer_id,taxzone_id,currency_id,invnumber,taxincluded,archart
datatype,accno,amount,taxkey
"Rechnung",960,4,1,"invoice 1 tax included no amounts",t,1400
"AccTransaction",8400,189.78,2
EOL

$entries = test_import($file);
$entry = $entries->[0];
$entry->{object}->validate_acc_trans(debug => 0);

clear_up(); # remove all data at end of tests
# end of tests


sub clear_up {
  SL::DB::Manager::AccTransaction->delete_all(all => 1);
  SL::DB::Manager::Invoice->delete_all       (all => 1);
  SL::DB::Manager::Customer->delete_all      (all => 1);
  SL::DB::Manager::Project->delete_all       (all => 1);
  SL::DB::Manager::Department->delete_all    (all => 1);
};


1;

#####
# vim: ft=perl
# set emacs to perl mode
# Local Variables:
# mode: perl
# End:
