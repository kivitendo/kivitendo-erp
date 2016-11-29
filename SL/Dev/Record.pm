package SL::Dev::Record;

use strict;
use base qw(Exporter);
our @EXPORT = qw(create_sales_invoice create_invoice_item);

use SL::Dev::Part;
use SL::Dev::CustomerVendor;
use SL::DB::Invoice;
use SL::DB::InvoiceItem;
use SL::DB::Employee;
use DateTime;

sub create_sales_invoice {
  my (%params) = @_;

  my ($part1, $part2);
  my $invoiceitems;
  if ( $params{invoiceitems} ) {
    $invoiceitems = $params{invoiceitems};
    die "params invoiceitems must be an arrayref of InvoiceItem objects" if scalar @{$invoiceitems} == 0 or grep { ref($_) ne 'SL::DB::InvoiceItem' } @{$params{invoiceitems}};
  } else {
    $part1 = SL::Dev::Part::create_part(description  => 'Testpart 1',
                                        sellprice    => 12,
                                       )->save;
    $part2 = SL::Dev::Part::create_part(description  => 'Testpart 2',
                                        sellprice    => 10,
                                       )->save;
    my $invoice_item1 = create_invoice_item(part => $part1, qty => 5);
    my $invoice_item2 = create_invoice_item(part => $part2, qty => 8);
    $invoiceitems = [ $invoice_item1, $invoice_item2 ];
  }

  my $customer = $params{customer} // SL::Dev::CustomerVendor::create_customer(name => 'Testcustomer')->save;
  die "illegal customer" unless ref($customer) eq 'SL::DB::Customer';

  my $invoice = SL::DB::Invoice->new(
    invoice      => 1,
    type         => 'sales_invoice',
    customer_id  => $customer->id,
    taxzone_id   => $customer->taxzone->id,
    invnumber    => $params{invnumber}   // undef,
    currency_id  => $params{currency_id} // $::instance_conf->get_currency_id,
    taxincluded  => $params{taxincluded} // 0,
    employee_id  => $params{employee_id} // SL::DB::Manager::Employee->current->id,
    salesman_id  => $params{employee_id} // SL::DB::Manager::Employee->current->id,
    transdate    => $params{transdate}   // DateTime->today_local->to_kivitendo,
    payment_id   => $params{payment_id}  // undef,
    gldate       => DateTime->today_local->to_kivitendo,
    notes        => $params{notes}       // '',
    invoiceitems => $invoiceitems,
  );

  $invoice->post;
  return $invoice;
}

sub create_invoice_item {
  my (%params) = @_;

# is not automatically saved so it can get added as part of a the invoice transaction

  my $part = delete($params{part});
  die "no part passed to _create_invoice_item" unless $part && ref($part) eq 'SL::DB::Part';

  my $invoice_item = SL::DB::InvoiceItem->new(
    parts_id    => $part->id,
    lastcost    => $part->lastcost,
    sellprice   => $part->sellprice,
    description => $part->description,
    unit        => $part->unit,
    %params, # override any of the part defaults via %params
  );

  return $invoice_item;
}

1;

__END__

=head1 NAME

SL::Dev::Record - create record objects for testing, with minimal defaults

=head1 FUNCTIONS

=head2 C<create_sales_invoice %PARAMS>

Creates a new sales invoice (table ar, invoice = 1).

If neither customer nor invoiceitems are passed as params a customer and two
parts are created and used for building the invoice.

Minimal usage example:

  my $invoice = SL::Dev::Record::create_sales_invoice();

Example with params:

  my $invoice2 = SL::Dev::Record::create_sales_invoice(
    invnumber   => 777,
    transdate   => DateTime->today_local->subtract(days => 7),
    taxincluded => 1,
  );

=head2 C<create_invoice_item %PARAMS>

Creates an invoice item from a part object that can be added to an invoice.

Example including creation of part and of invoice:
  my $part    = SL::Dev::Part::create_part(partnumber => 'T4254')->save;
  my $item    = SL::Dev::Record::create_invoice_item(part => $part, qty => 2.5);
  my $invoice = SL::Dev::Record::create_sales_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item ],
  );

=head1 TODO

* create other types of records (order, purchase records, ar transactions, ...)

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
