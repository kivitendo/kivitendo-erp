use Test::More;
use Test::Exception;

use strict;

use lib 't';
use utf8;

use Carp;
use Data::Dumper;
use Support::TestSetup;
use Test::Exception;
use List::Util qw(pairs);

use SL::DB::PaymentTerm;
use SL::DB::DeliveryTerm;
use SL::DB::Employee;
use SL::DB::Language;
use SL::DB::ReclamationReason;
use SL::DB::Translation;
use SL::Model::Record;

use SL::Dev::ALL qw(:ALL);

my ($customer, $vendor, $employee, $payment_term, $delivery_term, @parts, $reclamation_reason, $language1, $language2);
my ($dbh);

my ($sales_quotation1,    $sales_order1,    $sales_invoice1,    $sales_delivery_order1,    $sales_reclamation1);
my ($purchase_quotation1, $purchase_order1, $purchase_invoice1, $purchase_delivery_order1, $purchase_reclamation1);

Support::TestSetup::login();
$dbh = SL::DB->client->dbh;

# set locale to en so we can match errors
local $::locale = Locale->new('en');

note "testing deletions";
reset_state();
reset_basic_sales_records();
reset_basic_purchase_records();

is(SL::DB::Manager::Order->get_all_count(
    where => [ or  => ['record_type'  => 'sales_quotation', 'record_type'  => 'request_quotation' ]]),
  2, 'number of quotations before delete ok');
is(SL::DB::Manager::Order->get_all_count(
    where => [ and => ['!record_type' => 'sales_quotation', '!record_type' => 'request_quotation' ]]),
  2, 'number of orders before delete ok');
is(SL::DB::Manager::DeliveryOrder->get_all_count(), 2, 'number of delivery orders before delete ok');
is(SL::DB::Manager::Reclamation->get_all_count(), 2, 'number of reclamations before delete ok');
# is(SL::DB::Manager::Invoice->get_all_count(), 1, 'number of invoices before delete ok'); # no purchase_invoice was created

foreach my $record ( ($sales_quotation1,
                      $sales_order1,
                      $sales_reclamation1,
                      $purchase_quotation1,
                      $purchase_order1,
                      $purchase_reclamation1
                     )
                   ) {

  my $delete_return  = SL::Model::Record->delete($record);
  my $record_history = SL::DB::Manager::History->find_by(trans_id => $record->id, addition => 'DELETED');
  # just test if snumbers contains "_", not whether it actually is correct
  ok($record_history->snumbers =~ m/_/, "history snumbers of record " . $record_history->snumbers . " ok");
};

is(SL::DB::Manager::Order->get_all_count(
    where => [ or  => ['record_type'  => 'sales_quotation', 'record_type'  => 'request_quotation' ]]),
  0, 'number of quotations after delete ok');
is(SL::DB::Manager::Order->get_all_count(
    where => [ and => ['!record_type' => 'sales_quotation', '!record_type' => 'request_quotation' ]]),
  0, 'number of orders after delete ok');
# is(SL::DB::Manager::Invoice->get_all_count(), 0, 'number of invoices after delete ok');
is(SL::DB::Manager::Reclamation->get_all_count(), 0, 'number of orders after delete ok');

note "testing workflows";
reset_state();
reset_basic_sales_records();
reset_basic_purchase_records();

note "testing subversion of order";
# make current version a final version, currently this is handled via frontend/controller
is($sales_order1->ordnumber, "ord-01", "ordnumber before increment_subversion ok");
SL::DB::OrderVersion->new(oe_id => $sales_order1->id, version => 1, final_version => 1)->save;
# feature incrementing subversion disabled throws an error
throws_ok {
  local $::instance_conf->data->{lock_oe_subversions} = 0;
  SL::Model::Record->increment_subversion($sales_order1);
} qr{Subversions are not supported or disabled for this record type.}, 'feature subversion disabled throws error when trying to increment';
{
  local $::instance_conf->data->{lock_oe_subversions} = 1;
  SL::Model::Record->increment_subversion($sales_order1);
}
is($sales_order1->ordnumber, "ord-01-2", "ordnumber after increment_subversion ok");
is(SL::DB::Manager::Order->get_all_count(
    where => [ and => ['!record_type' => 'sales_quotation', '!record_type' => 'request_quotation' ]]),
  2, 'number of orders after incremented subversion ok');


note "testing new_from_workflow for quotation";
foreach my $target_record_type (qw(sales_order sales_delivery_order)) {
  # TODO: invoice
  note "  testing from quotation -> $target_record_type";
  my $new_record = SL::Model::Record->new_from_workflow($sales_quotation1, $target_record_type);

  is($new_record->closed, 0, "new quotation is open");
  # in the future closing sales quotations should probably happen as an after-save hook of orders,
  # but for now we copy the behaviour of the controller and pass the sales quotations as an argument
  SL::Model::Record->save($new_record, objects_to_close => [ $sales_quotation1 ]);

  $new_record->load;
  cmp_ok($new_record->netamount, '==', 710, "converted $target_record_type netamount ok") if $new_record->can('netamount');

  # test whether quotations get closed when sales_order is created
  if ( $target_record_type eq 'sales_order' ) {
    $sales_quotation1->load;
    is($sales_quotation1->closed, 1, "quotation is closed after creating an order");
  }

  # TODO: test whether orders get closed when all items are deliverd

  my $record_history = SL::DB::Manager::History->find_by(trans_id => $new_record->id, addition => 'SAVED');
  ok($record_history->snumbers =~ m/_/, "history snumbers of record " . $record_history->snumbers . " ok");
  test_record_links($new_record, "converted $target_record_type");
};

note "testing new_from_workflow for order";
foreach my $target_record_type (qw(sales_delivery_order sales_reclamation)) {
  # TODO: invoice
  note "  testing from quotation -> $target_record_type";
  my $new_record = SL::Model::Record->new_from_workflow($sales_order1, $target_record_type);
  if ( 'SL::DB::Reclamation' eq ref($new_record) ) {
    $_->reason($reclamation_reason) foreach @{ $new_record->items };
  };
  SL::Model::Record->save($new_record);
  $new_record->load;
  my $record_history = SL::DB::Manager::History->find_by(trans_id => $new_record->id, what_done => $target_record_type, addition => 'SAVED');

  ok($record_history->snumbers =~ m/_/, "history snumbers of record " . $record_history->snumbers . " ok");

  cmp_ok($new_record->netamount, '==', 710, "converted $target_record_type netamount ok") if $new_record->can('netamount');
  test_record_links($new_record, "converted $target_record_type");
};

note ('testing multi');
reset_state();
reset_basic_sales_records();
reset_basic_purchase_records();

note('combining several sales orders to one combined order');
my @sales_orders;
push(@sales_orders, SL::Model::Record->new_from_workflow($sales_quotation1, 'sales_order')->save->load) for 1 .. 3;
my $combined_order = SL::Model::Record->new_from_workflow_multi(\@sales_orders, 'sales_order', sort_sources_by => 'transdate');
SL::Model::Record->save($combined_order);
cmp_ok($combined_order->netamount, '==', 3*710, "netamount of combined order ok");


note "testing get price and discount sources";
reset_state();
reset_basic_sales_records();
reset_basic_purchase_records();

$purchase_quotation1->items_sorted->[0]->part->sellprice(500);
$purchase_quotation1->items_sorted->[0]->part->lastcost(300);
$purchase_quotation1->vendor->discount(5.0);

my ($price_source, $discount_source) = SL::Model::Record->get_best_price_and_discount_source($purchase_quotation1,
                                                                                             $purchase_quotation1->items_sorted->[0],
                                                                                             ignore_given => 1);
is($price_source->source_description, 'Master Data', 'get price source right with ignore_given');
is($price_source->price, 300, 'get price source purchase price right with ignore_given');
is($discount_source->source_description, 'Vendor Discount', 'get discount source right with ignore_given');
is($discount_source->discount, 5, 'get discount source purchase discount right with ignore_given');

$purchase_quotation1->items_sorted->[0]->discount(3);

($price_source, $discount_source)    = SL::Model::Record->get_best_price_and_discount_source($purchase_quotation1,
                                                                                             $purchase_quotation1->items_sorted->[0],
                                                                                             ignore_given => 0);
is($price_source->source_description, 'None (PriceSource)', 'get price source right with given price');
is($price_source->price, 70, 'get price source purchase price right with given price');
is($discount_source->source_description, 'None (PriceSource Discount)', 'get price source right with given price');
is($discount_source->discount, 3, 'get discount source purchase discount right with given price');

note "testing get part texts";
reset_state();
reset_basic_sales_records();

# part as obj
my $texts = SL::Model::Record->get_part_texts($sales_quotation1->items_sorted->[0]->part);
is_deeply($texts, {description => $sales_quotation1->items_sorted->[0]->part->description, longdescription => undef},
          'get_part_texts: simple texts via part obj');

$texts = SL::Model::Record->get_part_texts($sales_quotation1->items_sorted->[0]->part->id);
is_deeply($texts, {description => $sales_quotation1->items_sorted->[0]->part->description, longdescription => undef},
          'get_part_texts: simple texts via part id');

$texts = SL::Model::Record->get_part_texts($sales_quotation1->items_sorted->[1]->part);
is_deeply($texts, {description => 'b part', longdescription => 'note to b part'},
          'get_part_texts: all untranslated texts');

$texts = SL::Model::Record->get_part_texts($sales_quotation1->items_sorted->[1]->part, $language1);
is_deeply($texts, {description => 'B-Teil', longdescription => 'Bemerkung zu B-Teil'},
          'get_part_texts: get one translation via lang obj');

$texts = SL::Model::Record->get_part_texts($sales_quotation1->items_sorted->[1]->part, $language2->id);
is_deeply($texts, {description => 'partie B', longdescription => 'Note pour la partie B'},
          'get_part_texts: get another translation via lang id');

$texts = SL::Model::Record->get_part_texts($sales_quotation1->items_sorted->[1]->part, $language1, description => 'default', longdescription => 'default');
is_deeply($texts, {description => 'B-Teil', longdescription => 'Bemerkung zu B-Teil'},
                  'get_part_texts: no defaults with translation');

$texts = SL::Model::Record->get_part_texts($sales_quotation1->items_sorted->[0]->part, $language1, description => 'default', longdescription => 'default');
is_deeply($texts, {description => 'default', longdescription => 'default'},
                  'get_part_texts: defaults with missing translation');

clear_up();
done_testing;

sub test_record_links {
  my $record = shift;
  my $text = shift;

  is(@{ $record->linked_records }, 1, "1 record link for $text created ok"); # just check if one exists, not if it is actually correct
  my $number_of_item_record_links;
  foreach my $item ( @{ $record->items } ) {
    $number_of_item_record_links += scalar @{ $item->linked_records };
  };
  is($number_of_item_record_links, 2, "2 record links for $text items created ok"); # just check if they exist, not if they are actually correct
}

sub clear_up {
  foreach (qw(InvoiceItem Invoice
              DeliveryOrderItem DeliveryOrder
              OrderItem Order OrderVersion
              Reclamation ReclamationItem ReclamationReason
              Part Customer Vendor PaymentTerm DeliveryTerm
              Translation Language)
          ) {
    "SL::DB::Manager::${_}"->delete_all(all => 1);
  }
  SL::DB::Manager::History->delete_all(all => 1);
  SL::DB::Manager::Employee->delete_all(where => [ login => 'testuser' ]);
};

sub reset_basic_sales_records {
  $dbh->do("UPDATE defaults SET sonumber = 'ord-00', sqnumber = 'quo-00', sdonumber = 'do-00', s_reclamation_record_number = 'srecl-00'");

  $sales_quotation1 = create_sales_quotation(
    save       => 1,
    customer   => $customer,
    orderitems => [ create_order_item(part => $parts[0], qty =>  3, sellprice => 70),
                    create_order_item(part => $parts[1], qty => 10, sellprice => 50),
                  ]
  );

  $sales_order1 = create_sales_order(
    save       => 1,
    customer   => $customer,
    orderitems => [ create_order_item(part => $parts[0], qty =>  3, sellprice => 70),
                    create_order_item(part => $parts[1], qty => 10, sellprice => 50),
                  ]
  );

  $sales_delivery_order1 = create_sales_delivery_order(
    save       => 1,
    customer   => $customer,
    orderitems => [ create_delivery_order_item(part => $parts[0], qty =>  3, sellprice => 70),
                    create_delivery_order_item(part => $parts[1], qty => 10, sellprice => 50),
                  ]
  );

  $sales_reclamation1 = create_sales_reclamation(
    save              => 1,
    employee          => $employee,
    reclamation_items => [ create_reclamation_item(part => $parts[0], qty =>  3, sellprice => 70, reason => $reclamation_reason),
                           create_reclamation_item(part => $parts[1], qty => 10, sellprice => 50, reason => $reclamation_reason),
                         ]
  );

  # disabled sales_invoice
  # $sales_invoice1 = create_sales_invoice(
  #   save        => 1,
  #   customer    => $customer,
  #   invoiceitems => [ create_invoice_item(part => $parts[0], qty =>  3, sellprice => 70),
  #                     create_invoice_item(part => $parts[1], qty => 10, sellprice => 50),
  #                   ]
  # );
}

sub reset_basic_purchase_records {
  $dbh->do("UPDATE defaults SET rfqnumber = 'rfq-00', ponumber = 'po-00', pdonumber = 'pdo-00', p_reclamation_record_number = 'precl-00'");

  $purchase_quotation1 = create_purchase_quotation (
    save        => 1,
    vendor      => $vendor,
    orderitems  => [ create_order_item(part => $parts[0], qty =>  3, sellprice => 70),
                     create_order_item(part => $parts[1], qty => 10, sellprice => 50),
                   ]
  );

  $purchase_order1 = create_purchase_order (
    save        => 1,
    vendor      => $vendor,
    orderitems  => [ create_order_item(part => $parts[0], qty =>  3, sellprice => 70),
                     create_order_item(part => $parts[1], qty => 10, sellprice => 50),
                   ]
  );

  $purchase_delivery_order1 = create_purchase_delivery_order(
    save       => 1,
    vendor     => $vendor,
    orderitems => [ create_delivery_order_item(part => $parts[0], qty =>  3, sellprice => 70),
                    create_delivery_order_item(part => $parts[1], qty => 10, sellprice => 50),
                  ]
  );

  $purchase_reclamation1 = create_purchase_reclamation(
    save              => 1,
    employee          => $employee,
    reclamation_items => [ create_reclamation_item(part => $parts[0], qty =>  3, sellprice => 70, reason => $reclamation_reason),
                           create_reclamation_item(part => $parts[1], qty => 10, sellprice => 50, reason => $reclamation_reason),
                         ]
  );
}

sub reset_state {
  my %params = @_;

  clear_up();

  $customer = new_customer()->save;
  $vendor   = new_vendor()->save;

  $employee = SL::DB::Employee->new(
    'login' => 'testuser',
    'name'  => 'Test User',
  )->save;

  $payment_term = create_payment_terms(
     'description'      => '14Tage 2%Skonto, 30Tage netto',
     'description_long' => "Innerhalb von 14 Tagen abzüglich 2 % Skonto, innerhalb von 30 Tagen rein netto.|Bei einer Zahlung bis zum <%skonto_date%> gewähren wir 2 % Skonto (EUR <%skonto_amount%>) entspricht EUR <%total_wo_skonto%>.Bei einer Zahlung bis zum <%netto_date%> ist der fällige Betrag in Höhe von <%total%> <%currency%> zu überweisen.",
     'percent_skonto'   => '0.02',
     'terms_netto'      => 30,
     'terms_skonto'     => 14
  );

  $delivery_term = SL::DB::DeliveryTerm->new(
    'description'      => 'Test Delivey Term',
    'description_long' => 'Test Delivey Term Test Delivey Term',
  )->save;

  # some languages
  $language1 = SL::DB::Language->new(description => 'lang1', template_code => 'L1')->save;
  $language2 = SL::DB::Language->new(description => 'lang2', template_code => 'L2')->save;

  # some parts/services
  @parts = ();
  push @parts, new_part(
    partnumber => 'a',
  )->save;
  push @parts, new_part(
    partnumber => 'b',
    description => 'b part',
    notes       => 'note to b part',
    translations => [SL::DB::Translation->new(language_id => $language1->id, translation => 'B-Teil',   longdescription => 'Bemerkung zu B-Teil'),
                     SL::DB::Translation->new(language_id => $language2->id, translation => 'partie B', longdescription => 'Note pour la partie B')
    ]
  )->save;

  $reclamation_reason = SL::DB::ReclamationReason->new(
    name        => "test_reason",
    description => "",
    position    => 1,
  );

}

1;

# set emacs to perl mode
# Local Variables:
# mode: perl
# End:
