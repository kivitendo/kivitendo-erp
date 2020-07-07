use Test::More tests => 41;

use strict;

use lib 't';
use utf8;

use Support::TestSetup;

use Carp;
use Data::Dumper;
use Support::TestSetup;
use Test::Exception;

use SL::DB::Buchungsgruppe;
use SL::DB::Currency;
use SL::DB::Customer;
use SL::DB::Employee;
use SL::DB::Invoice;
use SL::DB::Order;
use SL::DB::DeliveryOrder;
use SL::DB::Part;
use SL::DB::Unit;

use SL::Dev::ALL qw(:ALL);

my ($customer, $employee, $payment_do, $unit, @parts, $department);
my ($transdate);

my $VISUAL_TEST = 0;  # just a sleep to click around

sub clear_up {
  foreach (qw(DeliveryOrderItem DeliveryOrder InvoiceItem Invoice Part Customer Department PaymentTerm)) {
    "SL::DB::Manager::${_}"->delete_all(all => 1);
  }
  SL::DB::Manager::Employee->delete_all(where => [ login => 'testuser' ]);
};

sub reset_state {
  my %params = @_;

  clear_up();

  $transdate = DateTime->today_local;
  $transdate->set_year(2019) if $transdate->year == 2020; # use year 2019 in 2020, because of tax rate change in Germany

  $unit     = SL::DB::Manager::Unit->find_by(name => 'kg') || die "Can't find unit 'kg'";
  $customer = new_customer()->save;

  $employee = SL::DB::Employee->new(
    'login' => 'testuser',
    'name'  => 'Test User',
  )->save;

  $department = SL::DB::Department->new(
    'description' => 'Test Department',
  )->save;

  $payment_do = create_payment_terms(
     'description'      => '14Tage 2%Skonto, 30Tage netto',
     'description_long' => "Innerhalb von 14 Tagen abzüglich 2 % Skonto, innerhalb von 30 Tagen rein netto.|Bei einer Zahlung bis zum <%skonto_date%> gewähren wir 2 % Skonto (EUR <%skonto_amount%>) entspricht EUR <%total_wo_skonto%>.Bei einer Zahlung bis zum <%netto_date%> ist der fällige Betrag in Höhe von <%total%> <%currency%> zu überweisen.",
     'percent_skonto'   => '0.02',
     'terms_netto'      => 30,
     'terms_skonto'     => 14
  );

  # two real parts
  @parts = ();
  push @parts, new_part(
    description => "description 1",
    lastcost    => '49.95000',
    listprice   => '0.00000',
    partnumber  => 'v-519160549',
    sellprice   => '242.20000',
    unit        => $unit->name,
    weight      => '0.79',
  )->save;

  push @parts, new_part(
    description => "description 2",
    lastcost    => '153.00000',
    listprice   => '0.00000',
    partnumber  => 'v-120160086',
    sellprice   => '344.30000',
    unit        => $unit->name,
    weight      => '0.9',
  )->save;

}

Support::TestSetup::login();

reset_state();

# we create L20199 with two items
my $do1 = create_sales_delivery_order(
  'department_id' => $department->id,
  'transdate'     => $transdate,
  'donumber'      => 'L20199',
  'employee_id'   => $employee->id,
  'intnotes'      => 'some intnotes',
  'ordnumber'     => 'A16399',
  'payment_id'    => $payment_do->id,
  'salesman_id'   => $employee->id,
  'shippingpoint' => 'sendtome',
  'shipvia'       => 'DHL, Versand am 06.03.2015, 1 Paket  17,00 kg',
  'cusordnumber'  => 'b84da',
  'customer_id'   => $customer->id,
  'notes'         => '<ul><li><strong>fett</strong></li><li><strong>und</strong></li><li><strong>mit</strong></li><li><strong>bullets</strong></li><li>&nbsp;</li></ul>',
  orderitems => [
                  create_delivery_order_item(
                    part               => $parts[0],
                    discount           => '0.25',
                    lastcost           => '49.95000',
                    longdescription    => "<ol><li>27</li><li>28</li><li>29</li><li><sub>asdf</sub></li><li><sub>asdf</sub></li><li><sup>oben</sup></li></ol><p><s>kommt nicht mehr vor</s></p>",
                    marge_price_factor => 1,
                    qty                => '2.00000',
                    sellprice          => '242.20000',
                    unit               => $unit->name,
                  ),
                  create_delivery_order_item(
                    part            => $parts[1],
                    discount        => '0.25',
                    lastcost        => '153.00000',
                    qty             => '3.00000',
                    sellprice       => '344.30000',
                    transdate       => '06.03.2015',
                    unit            => $unit->name,
                  )
                ]
);


# TESTS

my $do1_item1 = $do1->orderitems->[0];
my $do1_item2 = $do1->orderitems->[1];

# test delivery order before any conversion
ok($do1->donumber eq "L20199", 'Delivery Order Number created');
ok($do1->notes eq '<ul><li><strong>fett</strong></li><li><strong>und</strong></li><li><strong>mit</strong></li><li><strong>bullets</strong></li><li>&nbsp;</li></ul>', "do RichText notes saved");
ok((not $do1->closed) , 'Delivery Order is not closed');
is($do1_item1->parts_id, $parts[0]->id, 'doi linked with part');
ok($do1_item1->qty == 2, 'qty check doi');
ok($do1_item1->longdescription eq  "<ol><li>27</li><li>28</li><li>29</li><li><sub>asdf</sub></li><li><sub>asdf</sub></li><li><sup>oben</sup></li></ol><p><s>kommt nicht mehr vor</s></p>",
     "do item1 rich text longdescripition");
ok ($do1_item2->position == 2, 'doi2 position check');
is (SL::DB::Manager::DeliveryOrderItem->get_all_count(where => [ delivery_order_id => $do1->id ]), 2 , 'two doi linked');


# convert this do to invoice
my $invoice = $do1->convert_to_invoice(transdate => $transdate);

sleep (300) if $VISUAL_TEST; # we can do a real visual test via gui login
# test invoice afterwards

ok ($invoice->shipvia eq "DHL, Versand am 06.03.2015, 1 Paket  17,00 kg", "ship via check");
ok ($invoice->shippingpoint eq "sendtome", "shipping point check");
ok ($invoice->ordnumber eq "A16399", "ordnumber check");
ok ($invoice->donumber eq "L20199", "donumber check");
ok ($invoice->notes eq '<ul><li><strong>fett</strong></li><li><strong>und</strong></li><li><strong>mit</strong></li><li><strong>bullets</strong></li><li>&nbsp;</li></ul>', "do RichText notes saved");
ok(($do1->closed) , 'Delivery Order is closed after conversion');
is($invoice->payment_terms->description, "14Tage 2%Skonto, 30Tage netto", 'payment term description check');

$invoice->load;

is($invoice->cusordnumber            , 'b84da'           , 'cusordnumber check');
is($invoice->department->description , "Test Department" , 'department description ok');
is($invoice->amount                  , '1354.20000'      , 'amount check');
is($invoice->marge_percent           , '50.88666'        , 'marge percent check');
is($invoice->marge_total             , '579.08000'       , 'marge total check');
is($invoice->netamount               , '1137.98000'      , 'netamount check');

# some item checks
is($invoice->items_sorted->[0]->parts_id         , $parts[0]->id , 'invoiceitem 1 linked with part');
is(scalar @{ $invoice->invoiceitems }            , 2             , 'two invoice items linked with invoice');
is($invoice->items_sorted->[0]->position         , 1             , "position 1 order correct");
is($invoice->items_sorted->[1]->position         , 2             , "position 2 order correct");
is($invoice->items_sorted->[0]->part->partnumber , 'v-519160549' , "partnumber 1 correct");
is($invoice->items_sorted->[1]->part->partnumber , 'v-120160086' , "partnumber 2 correct");
is($invoice->items_sorted->[0]->qty              , '2.00000'     , "pos 1 qty");
is($invoice->items_sorted->[1]->qty              , '3.00000'     , "pos 2 qty");
is($invoice->items_sorted->[0]->discount         , 0.25          , "pos 1 discount");
is($invoice->items_sorted->[1]->discount         , 0.25          , "pos 2 discount");
is($invoice->items_sorted->[0]->longdescription  , "<ol><li>27</li><li>28</li><li>29</li><li><sub>asdf</sub></li><li><sub>asdf</sub></li><li><sup>oben</sup></li></ol><p><s>kommt nicht mehr vor</s></p>",
     "invoice item1 rich text longdescripition");
# more ideas: check onhand, lastcost (parsed lastcost)



# check linked records AND linked items

# we expect something like this in record links:
# delivery_order_items |  144736 | invoice  |     9 | 2015-09-02 16:29:32.362562 |  5
# delivery_order_items |  144737 | invoice  |    10 | 2015-09-02 16:29:32.362562 |  6
# delivery_orders      |  464003 | ar       |     5 | 2015-09-02 16:29:32.362562 |  7
# wir erwarten:
# verkn�pfter beleg$VAR1 = {
#           'from_id' => 464003,
#           'from_table' => 'delivery_orders',
#           'to_id' => 11,
#           'to_table' => 'ar'
#         };
# verkn�pfte positionen$VAR1 = {
#           'from_id' => 144737,
#           'from_table' => 'delivery_order_items',
#           'to_id' => 22,
#           'to_table' => 'invoice'
#         };
# $VAR2 = {
#           'from_id' => 144736,
#           'from_table' => 'delivery_order_items',
#           'to_id' => 21,
#           'to_table' => 'invoice'
#         };


my @links_record    = RecordLinks->get_links('from_table' => 'delivery_orders',
                                             'to_table'   => 'ar',
                                             'from_id'    => $do1->id,
                                            );

is($links_record[0]->{from_id}    , $do1->id          , "record from id check");
is($links_record[0]->{from_table} , 'delivery_orders' , "record from table check");
is($links_record[0]->{to_table}   , 'ar'              , "record to table check");

foreach ( $do1_item1->id, $do1_item2->id ) {
  my @links_record_item1 = RecordLinks->get_links('from_table' => 'delivery_order_items',
                                                  'to_table'   => 'invoice',
                                                  'from_id'    => $_,
                                                 );

  is($links_record_item1[0]->{from_id}    , $_                     , "record from id check $_");
  is($links_record_item1[0]->{from_table} , 'delivery_order_items' , "record from table check $_");
  is($links_record_item1[0]->{to_table}   , 'invoice'              , "record to table check $_");
}

clear_up();

1;

# vim: ft=perl
# set emacs to perl mode
# Local Variables:
# mode: perl
# End:
