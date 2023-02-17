use Test::More;

use strict;

use lib 't';
use utf8;

use Carp;
use Data::Dumper;
use Support::TestSetup;
use Test::Exception;

use SL::DB::PaymentTerm;
use SL::DB::DeliveryTerm;
use SL::DB::Employee;
use SL::DB::ReclamationReason;
use SL::Model::Record;

use SL::Dev::ALL qw(:ALL);

my ($customer, $vendor, $employee, $payment_term, $delivery_term, @parts, $reclamation_reason);
my ($dbh);

my ($sales_quotation1,    $sales_order1,    $sales_invoice1,    $sales_delivery_order1,    $sales_reclamation1);
my ($purchase_quotation1, $purchase_order1, $purchase_invoice1, $purchase_delivery_order1, $purchase_reclamation1);

Support::TestSetup::login();
$dbh = SL::DB->client->dbh;

note "testing deletions";
reset_state();
reset_basic_sales_records();
reset_basic_purchase_records();

is(SL::DB::Manager::Order->get_all_count(where => [ quotation => 1 ]), 2, 'number of quotations before delete ok');
is(SL::DB::Manager::Order->get_all_count(where => [ quotation => 0 ]), 2, 'number of orders before delete ok');
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

is(SL::DB::Manager::Order->get_all_count(where => [ quotation => 1 ]), 0, 'number of quotations after delete ok');
is(SL::DB::Manager::Order->get_all_count(where => [ quotation => 0 ]), 0, 'number of orders after delete ok');
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
SL::Model::Record->increment_subversion($sales_order1);
is($sales_order1->ordnumber, "ord-01-2", "ordnumber after increment_subversion ok");
is(SL::DB::Manager::Order->get_all_count(where => [quotation => 0]), 2, 'number of orders after incremented subversion ok');


note "testing new_from_workflow for quotation";
foreach my $target_record_type ( qw(sales_order sales_delivery_order) ) {
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
foreach my $target_record_type ( qw(sales_delivery_order sales_reclamation) ) {
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

die;

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
              Part Customer Vendor PaymentTerm DeliveryTerm)
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

  # some parts/services
  @parts = ();
  push @parts, new_part(
    partnumber => 'a',
  )->save;
  push @parts, new_part(
    partnumber => 'b',
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
