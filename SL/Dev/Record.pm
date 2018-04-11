package SL::Dev::Record;

use strict;
use base qw(Exporter);
our @EXPORT_OK = qw(create_invoice_item create_sales_invoice create_credit_note create_order_item  create_sales_order create_purchase_order create_delivery_order_item create_sales_delivery_order create_purchase_delivery_order create_project create_department);
our %EXPORT_TAGS = (ALL => \@EXPORT_OK);

use SL::DB::Invoice;
use SL::DB::InvoiceItem;
use SL::DB::Employee;
use SL::Dev::Part qw(new_part);
use SL::Dev::CustomerVendor qw(new_vendor new_customer);
use SL::DB::Project;
use SL::DB::ProjectStatus;
use SL::DB::ProjectType;
use DateTime;

my %record_type_to_item_type = ( sales_invoice        => 'SL::DB::InvoiceItem',
                                 credit_note          => 'SL::DB::InvoiceItem',
                                 sales_order          => 'SL::DB::OrderItem',
                                 purchase_order       => 'SL::DB::OrderItem',
                                 sales_delivery_order => 'SL::DB::DeliveryOrderItem',
                               );

sub create_sales_invoice {
  my (%params) = @_;

  my $record_type = 'sales_invoice';
  my $invoiceitems = delete $params{invoiceitems} // _create_two_items($record_type);
  _check_items($invoiceitems, $record_type);

  my $customer = delete $params{customer} // new_customer(name => 'Testcustomer')->save;
  die "illegal customer" unless defined $customer && ref($customer) eq 'SL::DB::Customer';

  my $invoice = SL::DB::Invoice->new(
    invoice      => 1,
    type         => 'invoice',
    customer_id  => $customer->id,
    taxzone_id   => $customer->taxzone->id,
    invnumber    => delete $params{invnumber}   // undef,
    currency_id  => $params{currency_id} // $::instance_conf->get_currency_id,
    taxincluded  => $params{taxincluded} // 0,
    employee_id  => $params{employee_id} // SL::DB::Manager::Employee->current->id,
    salesman_id  => $params{employee_id} // SL::DB::Manager::Employee->current->id,
    transdate    => $params{transdate}   // DateTime->today_local->to_kivitendo,
    payment_id   => $params{payment_id}  // undef,
    gldate       => DateTime->today,
    invoiceitems => $invoiceitems,
  );
  $invoice->assign_attributes(%params) if %params;

  $invoice->post;
  return $invoice;
}

sub create_credit_note {
  my (%params) = @_;

  my $record_type = 'credit_note';
  my $invoiceitems = delete $params{invoiceitems} // _create_two_items($record_type);
  _check_items($invoiceitems, $record_type);

  my $customer = delete $params{customer} // new_customer(name => 'Testcustomer')->save;
  die "illegal customer" unless defined $customer && ref($customer) eq 'SL::DB::Customer';

  # adjust qty for credit note items
  $_->qty( $_->qty * -1) foreach @{$invoiceitems};

  my $invoice = SL::DB::Invoice->new(
    invoice      => 1,
    type         => 'credit_note',
    customer_id  => $customer->id,
    taxzone_id   => $customer->taxzone->id,
    invnumber    => delete $params{invnumber}   // undef,
    currency_id  => $params{currency_id} // $::instance_conf->get_currency_id,
    taxincluded  => $params{taxincluded} // 0,
    employee_id  => $params{employee_id} // SL::DB::Manager::Employee->current->id,
    salesman_id  => $params{employee_id} // SL::DB::Manager::Employee->current->id,
    transdate    => $params{transdate}   // DateTime->today_local->to_kivitendo,
    payment_id   => $params{payment_id}  // undef,
    gldate       => DateTime->today,
    invoiceitems => $invoiceitems,
  );
  $invoice->assign_attributes(%params) if %params;

  $invoice->post;
  return $invoice;
}

sub create_sales_delivery_order {
  my (%params) = @_;

  my $record_type = 'sales_delivery_order';
  my $orderitems = delete $params{orderitems} // _create_two_items($record_type);
  _check_items($orderitems, $record_type);

  my $customer = $params{customer} // new_customer(name => 'Testcustomer')->save;
  die "illegal customer" unless ref($customer) eq 'SL::DB::Customer';

  my $delivery_order = SL::DB::DeliveryOrder->new(
    'is_sales'   => 'true',
    'closed'     => undef,
    customer_id  => $customer->id,
    taxzone_id   => $customer->taxzone_id,
    donumber     => $params{donumber}    // undef,
    currency_id  => $params{currency_id} // $::instance_conf->get_currency_id,
    taxincluded  => $params{taxincluded} // 0,
    employee_id  => $params{employee_id} // SL::DB::Manager::Employee->current->id,
    salesman_id  => $params{employee_id} // SL::DB::Manager::Employee->current->id,
    transdate    => $params{transdate}   // DateTime->today,
    orderitems   => $orderitems,
  );
  $delivery_order->assign_attributes(%params) if %params;
  $delivery_order->save;
  return $delivery_order;
}

sub create_purchase_delivery_order {
  my (%params) = @_;

  my $record_type = 'purchase_delivery_order';
  my $orderitems = delete $params{orderitems} // _create_two_items($record_type);
  _check_items($orderitems, $record_type);

  my $vendor = $params{vendor} // new_vendor(name => 'Testvendor')->save;
  die "illegal customer" unless ref($vendor) eq 'SL::DB::Vendor';

  my $delivery_order = SL::DB::DeliveryOrder->new(
    'is_sales'   => 'false',
    'closed'     => undef,
    vendor_id    => $vendor->id,
    taxzone_id   => $vendor->taxzone_id,
    donumber     => $params{donumber}    // undef,
    currency_id  => $params{currency_id} // $::instance_conf->get_currency_id,
    taxincluded  => $params{taxincluded} // 0,
    employee_id  => $params{employee_id} // SL::DB::Manager::Employee->current->id,
    salesman_id  => $params{employee_id} // SL::DB::Manager::Employee->current->id,
    transdate    => $params{transdate}   // DateTime->today,
    orderitems   => $orderitems,
  );
  $delivery_order->assign_attributes(%params) if %params;
  $delivery_order->save;
  return $delivery_order;
}

sub create_sales_order {
  my (%params) = @_;

  my $record_type = 'sales_order';
  my $orderitems = delete $params{orderitems} // _create_two_items($record_type);
  _check_items($orderitems, $record_type);

  my $save = delete $params{save} // 0;

  my $customer = $params{customer} // new_customer(name => 'Testcustomer')->save;
  die "illegal customer" unless ref($customer) eq 'SL::DB::Customer';

  my $order = SL::DB::Order->new(
    customer_id  => delete $params{customer_id} // $customer->id,
    taxzone_id   => delete $params{taxzone_id}  // $customer->taxzone->id,
    currency_id  => delete $params{currency_id} // $::instance_conf->get_currency_id,
    taxincluded  => delete $params{taxincluded} // 0,
    employee_id  => delete $params{employee_id} // SL::DB::Manager::Employee->current->id,
    salesman_id  => delete $params{employee_id} // SL::DB::Manager::Employee->current->id,
    transdate    => delete $params{transdate}   // DateTime->today,
    orderitems   => $orderitems,
  );
  $order->assign_attributes(%params) if %params;

  if ( $save ) {
    $order->calculate_prices_and_taxes;
    $order->save;
  }
  return $order;
}

sub create_purchase_order {
  my (%params) = @_;

  my $record_type = 'purchase_order';
  my $orderitems = delete $params{orderitems} // _create_two_items($record_type);
  _check_items($orderitems, $record_type);

  my $save = delete $params{save} // 0;

  my $vendor = $params{vendor} // new_vendor(name => 'Testvendor')->save;
  die "illegal vendor" unless ref($vendor) eq 'SL::DB::Vendor';

  my $order = SL::DB::Order->new(
    vendor_id    => delete $params{vendor_id}   // $vendor->id,
    taxzone_id   => delete $params{taxzone_id}  // $vendor->taxzone->id,
    currency_id  => delete $params{currency_id} // $::instance_conf->get_currency_id,
    taxincluded  => delete $params{taxincluded} // 0,
    transdate    => delete $params{transdate}   // DateTime->today,
    'closed'     => undef,
    orderitems   => $orderitems,
  );
  $order->assign_attributes(%params) if %params;

  if ( $save ) {
    $order->calculate_prices_and_taxes; # not tested for purchase orders
    $order->save;
  }
  return $order;
};

sub _check_items {
  my ($items, $record_type) = @_;

  if  ( scalar @{$items} == 0 or grep { ref($_) ne $record_type_to_item_type{"$record_type"} } @{$items} ) {
    die "Error: items must be an arrayref of " . $record_type_to_item_type{"$record_type"} . "objects.";
  }
}

sub create_invoice_item {
  my (%params) = @_;

  return _create_item(record_type => 'sales_invoice', %params);
}

sub create_order_item {
  my (%params) = @_;

  return _create_item(record_type => 'sales_order', %params);
}

sub create_delivery_order_item {
  my (%params) = @_;

  return _create_item(record_type => 'sales_delivery_order', %params);
}

sub _create_item {
  my (%params) = @_;

  my $record_type = delete($params{record_type});
  my $part        = delete($params{part});

  die "illegal record type: $record_type, must be one of: " . join(' ', keys %record_type_to_item_type) unless $record_type_to_item_type{ $record_type };
  die "part missing as param" unless $part && ref($part) eq 'SL::DB::Part';

  my ($sellprice, $lastcost);

  if ( $record_type =~ /^sales/ ) {
    $sellprice = delete $params{sellprice} // $part->sellprice;
    $lastcost  = delete $params{lastcost}  // $part->lastcost;
  } else {
    $sellprice = delete $params{sellprice} // $part->lastcost;
    $lastcost  = delete $params{lastcost}  // 0; # $part->lastcost;
  }

  my $item = "$record_type_to_item_type{$record_type}"->new(
    parts_id    => $part->id,
    sellprice   => $sellprice,
    lastcost    => $lastcost,
    description => $part->description,
    unit        => $part->unit,
    qty         => $params{qty} || 5,
  );
  $item->assign_attributes(%params) if %params;
  return $item;
}

sub _create_two_items {
  my ($record_type) = @_;

  my $part1 = new_part(description => 'Testpart 1',
                       sellprice   => 12,
                      )->save;
  my $part2 = new_part(description => 'Testpart 2',
                       sellprice   => 10,
                      )->save;
  my $item1 = _create_item(record_type => $record_type, part => $part1, qty => 5);
  my $item2 = _create_item(record_type => $record_type, part => $part2, qty => 8);
  return [ $item1, $item2 ];
}

sub create_project {
  my (%params) = @_;
  my $project = SL::DB::Project->new(
    projectnumber     => delete $params{projectnumber} // 1,
    description       => delete $params{description} // "Test project",
    active            => 1,
    valid             => 1,
    project_status_id => SL::DB::Manager::ProjectStatus->find_by(name => "running")->id,
    project_type_id   => SL::DB::Manager::ProjectType->find_by(description => "Standard")->id,
  )->save;
  $project->assign_attributes(%params) if %params;
  return $project;
}

sub create_department {
  my (%params) = @_;

  my $department = SL::DB::Department->new(
    'description' => delete $params{description} // 'Test Department',
  )->save;

  $department->assign_attributes(%params) if %params;
  return $department;

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
    transdate   => DateTime->today->subtract(days => 7),
    taxincluded => 1,
  );

=head2 C<create_credit_note %PARAMS>

Create a credit note (sales). Use positive quantities when adding items.

Example including creation of parts and of credit_note
  my $part1 = SL::Dev::Part::create_part(   partnumber => 'T4254')->save;
  my $part2 = SL::Dev::Part::create_service(partnumber => 'Serv1')->save;
  my $credit_note = SL::Dev::Record::create_credit_note(
    invnumber    => '34',
    taxincluded  => 0,
    invoiceitems => [ SL::Dev::Record::create_invoice_item(part => $part1, qty =>  3, sellprice => 70),
                      SL::Dev::Record::create_invoice_item(part => $part2, qty => 10, sellprice => 50),
                    ]
  );

=head2 C<create_sales_order %PARAMS>

Examples:

Create a sales order and save it directly via rose, without running
calculate_prices_and_taxes:

 my $order = SL::Dev::Record::create_sales_order()->save;

Let create_sales_order run calculate_prices_and_taxes and save:

 my $order = SL::Dev::Record::create_sales_order(save => 1);


Example including creation of part and of sales order.
  my $part1 = SL::Dev::Part::create_part(   partnumber => 'T4254')->save;
  my $part2 = SL::Dev::Part::create_service(partnumber => 'Serv1')->save;
  my $order = SL::Dev::Record::create_sales_order(
    save         => 1,
    taxincluded  => 0,
    orderitems => [ SL::Dev::Record::create_order_item(part => $part1, qty =>  3, sellprice => 70),
                    SL::Dev::Record::create_order_item(part => $part2, qty => 10, sellprice => 50),
                  ]
  );

Example: create 100 orders with the same part for 100 new customers:

  my $part1 = SL::Dev::Part::create_part(partnumber => 'T6256')->save;
  SL::Dev::Record::create_sales_order(
    save         => 1,
    taxincluded  => 0,
    orderitems => [ SL::Dev::Record::create_order_item(part => $part1, qty => 1, sellprice => 9) ]
  ) for 1 .. 100;

=head2 C<create_purchase_order %PARAMS>

See comments for C<create_sales_order>.

Example:
 my $purchase_order = SL::Dev::Record::create_purchase_order(save => 1);


=head2 C<create_item %PARAMS>

Creates an item from a part object that can be added to a record.

Required params: record_type (sales_invoice, sales_order, sales_delivery_order)
                 part        (an SL::DB::Part object)

Example including creation of part and of invoice:
  my $part    = SL::Dev::Part::create_part(  partnumber  => 'T4254')->save;
  my $item    = SL::Dev::Record::create_invoice_item(part => $part, qty => 2.5);
  my $invoice = SL::Dev::Record::create_sales_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item ],
  );

=head2 C<create_project %PARAMS>

Creates a default project.

Minimal example, creating a project with status "running" and type "Standard":
  my $project = SL::Dev::Record::create_project();

  $project = SL::Dev::Record::create_project(
    projectnumber => 'p1',
    description   => 'Test project',
  )

If C<$params{description}> or C<$params{projectnumber}> exists, this will override the
default value 'Test project'.

C<%params> should only contain alterable keys from the object Project.

=head2 C<create_department %PARAMS>

Creates a default department.

Minimal example:
  my $department = SL::Dev::Record::create_department();

  my $department = SL::Dev::Record::create_department(
    description => 'Hawaii',
  )

If C<$params{description}> exists, this will override the
default value 'Test Department'.

C<%params> should only contain alterable keys from the object Department.


=head1 TODO

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
