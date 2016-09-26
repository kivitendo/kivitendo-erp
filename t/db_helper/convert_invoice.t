use Test::More tests => 42;

use strict;

use lib 't';
use utf8;

use Support::TestSetup;

use Carp;
use Data::Dumper;
use Support::TestSetup;
use Test::Exception;
use List::Util qw(max);

use SL::DB::Buchungsgruppe;
use SL::DB::Currency;
use SL::DB::Customer;
use SL::DB::Employee;
use SL::DB::Invoice;
use SL::DB::Order;
use SL::DB::DeliveryOrder;
use SL::DB::Part;
use SL::DB::Unit;
use SL::DB::TaxZone;

my ($customer, $currency_id, $buchungsgruppe, $employee, $vendor, $taxzone, $buchungsgruppe7, $tax, $tax7,
    $unit, @parts);

my $VISUAL_TEST = 0;  # just a sleep to click around

sub clear_up {
  foreach (qw(DeliveryOrderItem DeliveryOrder InvoiceItem PurchaseInvoice Invoice Part Customer Vendor Department PaymentTerm)) {
    "SL::DB::Manager::${_}"->delete_all(all => 1);
  }
  SL::DB::Manager::Employee->delete_all(where => [ id => 31915 ]);
};

sub reset_state {
  my %params = @_;

  clear_up();

  $buchungsgruppe   = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 19%', %{ $params{buchungsgruppe} }) || croak "No accounting group 19\%";
  $buchungsgruppe7  = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 7%', %{ $params{buchungsgruppe} })  || croak "No accounting group 7\%";
  $taxzone          = SL::DB::Manager::TaxZone->find_by( description => 'Inland')                                           || croak "No taxzone";
  $tax              = SL::DB::Manager::Tax->find_by(taxkey => 3, rate => 0.19, %{ $params{tax} })                           || croak "No tax for 19\%";
  $tax7             = SL::DB::Manager::Tax->find_by(taxkey => 2, rate => 0.07)                                              || croak "No tax for 7\%";
  $unit             = SL::DB::Manager::Unit->find_by(name => 'kg', %{ $params{unit} })                                      || croak "No unit";
  $currency_id     = $::instance_conf->get_currency_id;

  $customer     = SL::DB::Customer->new(
    name        => '520484567dfaedc9e60fc',
    currency_id => $currency_id,
    taxzone_id  => $taxzone->id,
    %{ $params{customer} }
  )->save;

  # some od.rnr real anonym data
  my $employee_bk = SL::DB::Employee->new(
                'id' => 31915,
                'login' => 'barbuschka.kappes',
                'name' => 'Barbuschka Kappes',
  )->save;

  my $department_do = SL::DB::Department->new(
                 'description' => 'Maisenhaus-Versand',
                 'id' => 32149,
                 'itime' => undef,
                 'mtime' => undef
  )->save;

  my $payment_do = SL::DB::PaymentTerm->new(
                 'description' => '14Tage 2%Skonto, 30Tage netto',
                 'description_long' => "Innerhalb von 14 Tagen abzüglich 2 % Skonto, innerhalb von 30 Tagen rein netto.|Bei einer Zahlung bis zum <%skonto_date%> gewähren wir 2 % Skonto (EUR <%skonto_amount%>) entspricht EUR <%total_wo_skonto%>.Bei einer Zahlung bis zum <%netto_date%> ist der fällige Betrag in Höhe von <%total%> <%currency%> zu überweisen.",
                 'id' => 11276,
                 'itime' => undef,
                 'mtime' => undef,
                 'percent_skonto' => '0.02',
                 'ranking' => undef,
                 'sortkey' => 4,
                 'terms_netto' => 30,
                 'auto_calculation' => undef,
                 'terms_skonto' => 14
  )->save;

  # two real parts
  @parts = ();
  push @parts, SL::DB::Part->new(
                 'id' => 26321,
                 'image' => '',
                 'lastcost' => '49.95000',
                 'listprice' => '0.00000',
                 'onhand' => '5.00000',
                 'partnumber' => 'v-519160549',
                 #'partsgroup_id' => 111645,
                 'rop' => '0',
                 'sellprice' => '242.20000',
                 #'warehouse_id' => 64702,
                 'weight' => '0.79',
                 description        => "Pflaumenbaum, Gr.5, Unterfilz weinrot, genietet[[Aufschnittbreite: 11,0, Kernform: US]]\"" ,
                 buchungsgruppen_id => $buchungsgruppe->id,
                 unit               => $unit->name,
                 id                 => 26321,
  )->save;

  push @parts, SL::DB::Part->new(
                 'description' => "[[0640]]Flügel Hammerstiele bestehend aus:
70 Stielen Standard in Weißbuche und
20 Stielen Diskant abgekehlt in Weißbuche
mit Röllchen aus Synthetikleder,
Kapseln mit Yamaha Profil, Kerbenabstand 3,6 mm mit eingedrehten Abnickschrauben",
                 'id' => 25505,
                 'lastcost' => '153.00000',
                 'listprice' => '0.00000',
                 'onhand' => '9.00000',
                 'partnumber' => 'v-120160086',
                 # 'partsgroup_id' => 111639,
                 'rop' => '0',
                 'sellprice' => '344.30000',
                 'weight' => '0.9',
                  buchungsgruppen_id => $buchungsgruppe->id,
                  unit               => $unit->name,
  )->save;
}

sub new_delivery_order {
  my %params  = @_;

  return SL::DB::DeliveryOrder->new(
   currency_id => $currency_id,
   taxzone_id  => $taxzone->id,
    %params,
  )->save;
}

Support::TestSetup::login();

reset_state();

# we create L20199 with two items
my $do1 = new_delivery_order('department_id'    => 32149,
                             'donumber'         => 'L20199',
                             'employee_id'      => 31915,
                             'intnotes'         => 'Achtung: Neue Lieferadresse ab 16.02.2015 in der Otto-Merck-Str. 7a!   13.02.2015/MH

                                            Yamaha-Produkte (201...) immer plus 25% dazu rechnen / BK 13.02.2014',
                              'ordnumber'       => 'A16399',
                              'payment_id'      => 11276,
                              'salesman_id'     => 31915,
                              'shippingpoint'   => 'Maisenhaus',
                              # 'shipto_id'     => 451463,
                              'is_sales'        => 'true',
                              'shipvia'         => 'DHL, Versand am 06.03.2015, 1 Paket  17,00 kg',
                              'taxzone_id'      => 4,
                              'closed'          => undef,
                              # 'currency_id'   => 1,
                              'cusordnumber'    => 'b84da',
                              'customer_id'     => $customer->id,
                              'id'              => 464003,
                              'notes'           => '<ul><li><strong>fett</strong></li><li><strong>und</strong></li><li><strong>mit</strong></li><li><strong>bullets</strong></li><li>&nbsp;</li></ul>',
);

my $do1_item1 = SL::DB::DeliveryOrderItem->new('delivery_order_id' => 464003,
                                               'description' => "Flügel Hammerkopf bestehend aus:
                                                                 Bass/Diskant 26/65 Stück, Gesamtlänge 80/72, Bohrlänge 56/48
                                                                 Pflaumenbaum, Gr.5, Unterfilz weinrot, genietet[[Aufschnittbreite: 11,0, Kernform: US]]",
                                               'discount' => '0.25',
                                               'id' => 144736,
                                               'lastcost' => '49.95000',
                                               'longdescription'    => "<ol><li>27</li><li>28</li><li>29</li><li><sub>asdf</sub></li><li><sub>asdf</sub></li><li><sup>oben</sup></li></ol><p><s>kommt nicht mehr vor</s></p>",
                                               'marge_price_factor' => 1,
                                               'mtime' => undef,
                                               'ordnumber' => 'A16399',
                                               'parts_id' => 26321,
                                               'position' => 1,
                                               'price_factor' => 1,
                                               'qty' => '2.00000',
                                               'sellprice' => '242.20000',
                                               'transdate' => '06.03.2015',
                                               'unit' => 'kg')->save;

my $do1_item2 = SL::DB::DeliveryOrderItem->new('delivery_order_id' => 464003,
                 'description' => "[[0640]]Flügel Hammerstiele bestehend aus:
70 Stielen Standard in Weißbuche und
20 Stielen Diskant abgekehlt in Weißbuche
mit Röllchen aus Synthetikleder,
Kapseln mit Yamaha Profil, Kerbenabstand 3,6 mm mit eingedrehten Abnickschrauben",
                 'discount' => '0.25',
                 'id' => 144737,
                 'itime' => undef,
                 'lastcost' => '153.00000',
                 'longdescription' => '',
                 'marge_price_factor' => 1,
                 'mtime' => undef,
                 'ordnumber' => 'A16399',
                 'parts_id' => 25505,
                 'position' => 2,
                 'price_factor' => 1,
                 'price_factor_id' => undef,
                 'pricegroup_id' => undef,
                 'project_id' => undef,
                 'qty' => '3.00000',
                 'reqdate' => undef,
                 'sellprice' => '344.30000',
                 'serialnumber' => '',
                 'transdate' => '06.03.2015',
                 'unit' => 'kg')->save;

# TESTS


# test delivery order before any conversion
ok($do1->donumber eq "L20199", 'Delivery Order Number created');
ok($do1->notes eq '<ul><li><strong>fett</strong></li><li><strong>und</strong></li><li><strong>mit</strong></li><li><strong>bullets</strong></li><li>&nbsp;</li></ul>', "do RichText notes saved");
ok((not $do1->closed) , 'Delivery Order is not closed');
ok($do1_item1->parts_id eq '26321', 'doi linked with part');
ok($do1_item1->qty == 2, 'qty check doi');
ok($do1_item1->longdescription eq  "<ol><li>27</li><li>28</li><li>29</li><li><sub>asdf</sub></li><li><sub>asdf</sub></li><li><sup>oben</sup></li></ol><p><s>kommt nicht mehr vor</s></p>",
     "do item1 rich text longdescripition");
ok ($do1_item2->position == 2, 'doi2 position check');
ok (2 ==  scalar@{ SL::DB::Manager::DeliveryOrderItem->get_all(where => [ delivery_order_id => $do1->id ]) }, 'two doi linked');


# convert this do to invoice
my $invoice = $do1->convert_to_invoice();

sleep (300) if $VISUAL_TEST; # we can do a real visual test via gui login
# test invoice afterwards

ok ($invoice->shipvia eq "DHL, Versand am 06.03.2015, 1 Paket  17,00 kg", "ship via check");
ok ($invoice->shippingpoint eq "Maisenhaus", "shipping point check");
ok ($invoice->ordnumber eq "A16399", "ordnumber check");
ok ($invoice->donumber eq "L20199", "donumber check");
ok ($invoice->notes eq '<ul><li><strong>fett</strong></li><li><strong>und</strong></li><li><strong>mit</strong></li><li><strong>bullets</strong></li><li>&nbsp;</li></ul>', "do RichText notes saved");
ok(($do1->closed) , 'Delivery Order is closed after conversion');
ok (SL::DB::PaymentTerm->new(id => $invoice->{payment_id})->load->description eq "14Tage 2%Skonto, 30Tage netto", 'payment term description check');

# some test data from original client invoice console (!)
# my $invoice3 = SL::DB::Manager::Invoice->find_by( ordnumber => 'A16399' );
# which will fail due to PTC Calculation differs from GUI-Calculation, see issue: http://redmine.kivitendo-premium.de/issues/82
# pp $invoice3
# values from gui should be:
#ok($invoice->amount == 1354.20000, 'amount check');
#ok($invoice->marge_percent == 50.88666, 'marge percent check');
#ok($invoice->marge_total == 579.08000, 'marge total check');
#ok($invoice->netamount == 1137.98000, 'netamount check');


# the values change if one reloads the object
# without reloading we get this failures
#not ok 17 - amount check
#   Failed test 'amount check'
#   at t/db_helper/convert_invoice.t line 272.
#          got: '1354.17'
#     expected: '1354.17000'
#not ok 18 - marge percent check
#   Failed test 'marge percent check'
#   at t/db_helper/convert_invoice.t line 273.
#          got: '50.8857956342929'
#     expected: '50.88580'
#not ok 19 - marge total check
#   Failed test 'marge total check'
#   at t/db_helper/convert_invoice.t line 274.
#          got: '579.06'
#     expected: '579.06000'
#not ok 20 - netamount check
#   Failed test 'netamount check'
#   at t/db_helper/convert_invoice.t line 275.
#          got: '1137.96'
#     expected: '1137.96000'

$invoice->load;

ok($invoice->currency_id eq '1', 'currency_id');
ok($invoice->cusordnumber eq 'b84da', 'cusordnumber check');
ok(SL::DB::Department->new(id => $invoice->{department_id})->load->description eq "Maisenhaus-Versand", 'department description');
is($invoice->amount, '1354.17000', 'amount check');
is($invoice->marge_percent, '50.88580', 'marge percent check');
is($invoice->marge_total, '579.06000', 'marge total check');
is($invoice->netamount, '1137.96000', 'netamount check');

# some item checks
ok(@ {$invoice->items_sorted}[0]->parts_id eq '26321', 'invoiceitem 1 linked with part');
ok(2 ==  scalar@{ $invoice->invoiceitems }, 'two invoice items linked with invoice');
is(@ {$invoice->items_sorted}[0]->position, 1, "position 1 order correct");
is(@ {$invoice->items_sorted}[1]->position, 2, "position 2 order correct");
is(@ {$invoice->items_sorted}[0]->longdescription, "<ol><li>27</li><li>28</li><li>29</li><li><sub>asdf</sub></li><li><sub>asdf</sub></li><li><sup>oben</sup></li></ol><p><s>kommt nicht mehr vor</s></p>",
     "invoice item1 rich text longdescripition");
is(@ {$invoice->items_sorted}[0]->part->partnumber, 'v-519160549', "partnumber 1 correct");
is(@ {$invoice->items_sorted}[1]->part->partnumber, 'v-120160086', "partnumber 2 correct");
is(@ {$invoice->items_sorted}[0]->qty, '2.00000', "pos 1 qty");
is(@ {$invoice->items_sorted}[1]->qty, '3.00000', "pos 2 qty");
is(@ {$invoice->items_sorted}[0]->discount, 0.25, "pos 1 discount");
is(@ {$invoice->items_sorted}[1]->discount, 0.25, "pos 2 discount");

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
                                             'from_id'      => 464003);
is($links_record[0]->{from_id}, '464003', "record from id check");
is($links_record[0]->{from_table}, 'delivery_orders', "record from table check");
is($links_record[0]->{to_table}, 'ar', "record to table check");

foreach (qw(144736 144737)) {
  my @links_record_item1 = RecordLinks->get_links('from_table' => 'delivery_order_items',
                                                 'to_table'   => 'invoice',
                                                 'from_id'      => $_);
  is($links_record_item1[0]->{from_id}, $_, "record from id check $_");
  is($links_record_item1[0]->{from_table}, 'delivery_order_items', "record from table check $_");
  is($links_record_item1[0]->{to_table}, 'invoice', "record to table check $_");
}


clear_up();

1;
