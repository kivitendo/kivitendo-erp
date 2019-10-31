package SL::Dev::Record;

use strict;
use base qw(Exporter);
our @EXPORT_OK = qw(create_invoice_item
                    create_sales_invoice
                    create_credit_note
                    create_order_item
                    create_sales_order
                    create_purchase_order
                    create_delivery_order_item
                    create_sales_delivery_order
                    create_purchase_delivery_order
                    create_project create_department
                    create_ap_transaction
                    create_ar_transaction
                    create_gl_transaction
                   );
our %EXPORT_TAGS = (ALL => \@EXPORT_OK);

use SL::DB::Invoice;
use SL::DB::InvoiceItem;
use SL::DB::Employee;
use SL::Dev::Part qw(new_part);
use SL::Dev::CustomerVendor qw(new_vendor new_customer);
use SL::DB::Project;
use SL::DB::ProjectStatus;
use SL::DB::ProjectType;
use SL::Form;
use DateTime;
use List::Util qw(sum);
use Data::Dumper;
use SL::Locale::String qw(t8);
use SL::DATEV;

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

sub create_ap_transaction {
  my (%params) = @_;

  my $vendor = delete $params{vendor};
  if ( $vendor ) {
    die "vendor missing or not a SL::DB::Vendor object" unless ref($vendor) eq 'SL::DB::Vendor';
  } else {
    # use default SL/Dev vendor if it exists, or create a new one
    $vendor = SL::DB::Manager::Vendor->find_by(name => 'Testlieferant') // new_vendor->save;
  };

  my $taxincluded = $params{taxincluded} // 1;
  delete $params{taxincluded};

  my $bookings    = delete $params{bookings};
  # default bookings
  unless ( $bookings ) {
    my $chart_postage   = SL::DB::Manager::Chart->find_by(description => 'Porto');
    my $chart_telephone = SL::DB::Manager::Chart->find_by(description => 'Telefon');
    $bookings = [
                  {
                    chart  => $chart_postage,
                    amount => 1000,
                  },
                  {
                    chart  => $chart_telephone,
                    amount => $taxincluded ? 1190 : 1000,
                  },
                ]
  };

  # optional params:
  my $project_id         = delete $params{globalproject_id};

  # if amount or netamount are given, then it compares them to the final values, and dies if they don't match
  my $expected_amount    = delete $params{amount};
  my $expected_netamount = delete $params{netamount};

  my $dec = delete $params{dec} // 2;

  my $today      = DateTime->today_local;
  my $transdate  = delete $params{transdate} // $today;
  die "transdate hat to be DateTime object" unless ref($transdate) eq 'DateTime';

  my $gldate     = delete $params{gldate} // $today;
  die "gldate hat to be DateTime object" unless ref($gldate) eq 'DateTime';

  my $ap_chart = delete $params{ap_chart} // SL::DB::Manager::Chart->find_by( accno => '1600' );
  die "no ap_chart found or not an AP chart" unless $ap_chart and $ap_chart->link eq 'AP';

  my $ap_transaction = SL::DB::PurchaseInvoice->new(
    vendor_id        => $vendor->id,
    invoice          => 0,
    transactions     => [],
    globalproject_id => $project_id,
    invnumber        => delete $params{invnumber} // 'test ap_transaction',
    notes            => delete $params{notes}     // 'test ap_transaction',
    transdate        => $transdate,
    gldate           => $gldate,
    taxincluded      => $taxincluded,
    taxzone_id       => $vendor->taxzone_id, # taxzone_id shouldn't have any effect on ap transactions
    currency_id      => $::instance_conf->get_currency_id,
    type             => undef, # isn't set for ap
    employee_id      => SL::DB::Manager::Employee->current->id,
  );
  # assign any parameters that weren't explicitly handled above, e.g. itime
  $ap_transaction->assign_attributes(%params) if %params;

  foreach my $booking ( @{$bookings} ) {
    my $chart = delete $booking->{chart};
    die "illegal chart" unless ref($chart) eq 'SL::DB::Chart';

    my $tax = _transaction_tax_helper($booking, $chart, $transdate); # will die if tax can't be found

    $ap_transaction->add_ap_amount_row(
      amount     => $booking->{amount}, # add_ap_amount_row expects the user input amount, does its own calculate_tax
      chart      => $chart,
      tax_id     => $tax->id,
      project_id => $booking->{project_id},
    );
  }

  my $acc_trans_sum = sum map { $_->amount  } grep { $_->chart_link =~ 'AP_amount' } @{$ap_transaction->transactions};
  # $main::lxdebug->message(0, sprintf("accno: %s    amount: %s   chart_link: %s\n",
  #                                    $_->amount,
  #                                    $_->chart->accno,
  #                                    $_->chart_link
  #                                   )) foreach @{$ap_transaction->transactions};

  # determine netamount and amount from the transactions that were added via bookings
  $ap_transaction->netamount( -1 * sum map { $_->amount  } grep { $_->chart_link =~ 'AP_amount' } @{$ap_transaction->transactions} );
  # $main::lxdebug->message(0, sprintf('found netamount %s', $ap_transaction->netamount));

  my $taxamount = -1 * sum map { $_->amount  } grep { $_->chart_link =~ /tax/ } @{$ap_transaction->transactions};
  $ap_transaction->amount( $ap_transaction->netamount + $taxamount );
  # additional check, add up all transactions before AP-transaction is added
  my $refamount = -1 * sum map { $_->amount  } @{$ap_transaction->transactions};
  die "refamount = $refamount, ap_transaction->amount = " . $ap_transaction->amount unless $refamount == $ap_transaction->amount;

  # if amount or netamount were passed as params, check if the values are still
  # the same after recalculating them from the acc_trans entries
  if (defined $expected_amount) {
    die "amount doesn't match acc_trans amounts: $expected_amount != " . $ap_transaction->amount unless $expected_amount == $ap_transaction->amount;
  }
  if (defined $expected_netamount) {
    die "netamount doesn't match acc_trans netamounts: $expected_netamount != " . $ap_transaction->netamount unless $expected_netamount == $ap_transaction->netamount;
  }

  $ap_transaction->create_ap_row(chart => $ap_chart);
  $ap_transaction->save;
  # $main::lxdebug->message(0, sprintf("created ap_transaction with invnumber %s and trans_id %s",
  #                                     $ap_transaction->invnumber,
  #                                     $ap_transaction->id));
  return $ap_transaction;
}

sub create_ar_transaction {
  my (%params) = @_;

  my $customer = delete $params{customer};
  if ( $customer ) {
    die "customer missing or not a SL::DB::Customer object" unless ref($customer) eq 'SL::DB::Customer';
  } else {
    # use default SL/Dev vendor if it exists, or create a new one
    $customer = SL::DB::Manager::Customer->find_by(name => 'Testkunde') // new_customer->save;
  };

  my $taxincluded = $params{taxincluded} // 1;
  delete $params{taxincluded};

  my $bookings    = delete $params{bookings};
  # default bookings
  unless ( $bookings ) {
    my $chart_19 = SL::DB::Manager::Chart->find_by(accno => '8400');
    my $chart_7  = SL::DB::Manager::Chart->find_by(accno => '8300');
    my $chart_0  = SL::DB::Manager::Chart->find_by(accno => '8200');
    $bookings = [
                  {
                    chart  => $chart_19,
                    amount => $taxincluded ? 119 : 100,
                  },
                  {
                    chart  => $chart_7,
                    amount => $taxincluded ? 107 : 100,
                  },
                  {
                    chart  => $chart_0,
                    amount => 100,
                  },
                ]
  };

  # optional params:
  my $project_id = delete $params{globalproject_id};

  # if amount or netamount are given, then it compares them to the final values, and dies if they don't match
  my $expected_amount    = delete $params{amount};
  my $expected_netamount = delete $params{netamount};

  my $dec = delete $params{dec} // 2;

  my $today      = DateTime->today_local;
  my $transdate  = delete $params{transdate} // $today;
  die "transdate hat to be DateTime object" unless ref($transdate) eq 'DateTime';

  my $gldate     = delete $params{gldate} // $today;
  die "gldate hat to be DateTime object" unless ref($gldate) eq 'DateTime';

  my $ar_chart = delete $params{ar_chart} // SL::DB::Manager::Chart->find_by( accno => '1400' );
  die "no ar_chart found or not an AR chart" unless $ar_chart and $ar_chart->link eq 'AR';

  my $ar_transaction = SL::DB::Invoice->new(
    customer_id      => $customer->id,
    invoice          => 0,
    transactions     => [],
    globalproject_id => $project_id,
    invnumber        => delete $params{invnumber} // 'test ar_transaction',
    notes            => delete $params{notes}     // 'test ar_transaction',
    transdate        => $transdate,
    gldate           => $gldate,
    taxincluded      => $taxincluded,
    taxzone_id       => $customer->taxzone_id, # taxzone_id shouldn't have any effect on ar transactions
    currency_id      => $::instance_conf->get_currency_id,
    type             => undef, # isn't set for ar
    employee_id      => SL::DB::Manager::Employee->current->id,
  );
  # assign any parameters that weren't explicitly handled above, e.g. itime
  $ar_transaction->assign_attributes(%params) if %params;

  foreach my $booking ( @{$bookings} ) {
    my $chart = delete $booking->{chart};
    die "illegal chart" unless ref($chart) eq 'SL::DB::Chart';

    my $tax = _transaction_tax_helper($booking, $chart, $transdate); # will die if tax can't be found

    $ar_transaction->add_ar_amount_row(
      amount     => $booking->{amount}, # add_ar_amount_row expects the user input amount, does its own calculate_tax
      chart      => $chart,
      tax_id     => $tax->id,
      project_id => $booking->{project_id},
    );
  }

  my $acc_trans_sum = sum map { $_->amount  } grep { $_->chart_link =~ 'AR_amount' } @{$ar_transaction->transactions};
  # $main::lxdebug->message(0, sprintf("accno: %s    amount: %s   chart_link: %s\n",
  #                                    $_->amount,
  #                                    $_->chart->accno,
  #                                    $_->chart_link
  #                                   )) foreach @{$ar_transaction->transactions};

  # determine netamount and amount from the transactions that were added via bookings
  $ar_transaction->netamount( 1 * sum map { $_->amount  } grep { $_->chart_link =~ 'AR_amount' } @{$ar_transaction->transactions} );
  # $main::lxdebug->message(0, sprintf('found netamount %s', $ar_transaction->netamount));

  my $taxamount = 1 * sum map { $_->amount  } grep { $_->chart_link =~ /tax/ } @{$ar_transaction->transactions};
  $ar_transaction->amount( $ar_transaction->netamount + $taxamount );
  # additional check, add up all transactions before AP-transaction is added
  my $refamount = 1 * sum map { $_->amount  } @{$ar_transaction->transactions};
  die "refamount = $refamount, ar_transaction->amount = " . $ar_transaction->amount unless $refamount == $ar_transaction->amount;

  # if amount or netamount were passed as params, check if the values are still
  # the same after recalculating them from the acc_trans entries
  if (defined $expected_amount) {
    die "amount doesn't match acc_trans amounts: $expected_amount != " . $ar_transaction->amount unless $expected_amount == $ar_transaction->amount;
  }
  if (defined $expected_netamount) {
    die "netamount doesn't match acc_trans netamounts: $expected_netamount != " . $ar_transaction->netamount unless $expected_netamount == $ar_transaction->netamount;
  }

  $ar_transaction->create_ar_row(chart => $ar_chart);
  $ar_transaction->save;
  # $main::lxdebug->message(0, sprintf("created ar_transaction with invnumber %s and trans_id %s",
  #                                     $ar_transaction->invnumber,
  #                                     $ar_transaction->id));
  return $ar_transaction;
}

sub create_gl_transaction {
  my (%params) = @_;

  my $ob_transaction = delete $params{ob_transaction} // 0;
  my $cb_transaction = delete $params{cb_transaction} // 0;
  my $dec            = delete $params{rec} // 2;

  my $taxincluded = defined $params{taxincluded} ? $params{taxincluded} : 1;

  my $today      = DateTime->today_local;
  my $transdate  = delete $params{transdate} // $today;
  my $gldate     = delete $params{gldate}    // $today;

  my $reference   = delete $params{reference}   // 'reference';
  my $description = delete $params{description} // 'description';

  my $department_id = delete $params{department_id};

  my $bookings = delete $params{bookings};
  unless ( $bookings && scalar @{$bookings} ) {
    # default bookings if left empty
    my $expense_chart = SL::DB::Manager::Chart->find_by(accno => '4660') or die "Can't find expense chart 4660\n"; # Reisekosten
    my $cash_chart    = SL::DB::Manager::Chart->find_by(accno => '1000') or die "Can't find cash chart 1000\n";    # Kasse

    $taxincluded = 0;

    $reference   = 'Reise';
    $description = 'Reise';

    $bookings = [
                  {
                    chart  => $expense_chart, # has default tax of 19%
                    credit => 84.03,
                    taxkey => 9,
                  },
                  {
                    chart  => $cash_chart,
                    debit  => 100,
                    taxkey => 0,
                  },
    ];
  }

  my $gl_transaction = SL::DB::GLTransaction->new(
    reference      => $reference,
    description    => $description,
    transdate      => $transdate,
    gldate         => $gldate,
    taxincluded    => $taxincluded,
    type           => undef,
    ob_transaction => $ob_transaction,
    cb_transaction => $cb_transaction,
    storno         => 0,
    storno_id      => undef,
    transactions   => [],
  );
  # assign any parameters that weren't explicitly handled above, e.g. itime
  $gl_transaction->assign_attributes(%params) if %params;

  my @acc_trans;
  if ( scalar @{$bookings} ) {
    # there are several ways of determining the tax:
    # * tax_id : fetches SL::DB::Tax object via id (as used in dropdown in interface)
    # * tax : SL::DB::Tax object (where $tax->id = tax_id)
    # * taxkey : tax is determined from startdate
    # * none of the above defined: use the default tax for that chart

    foreach my $booking ( @{$bookings} ) {
      my $chart = delete $booking->{chart};
      die "illegal chart" unless ref($chart) eq 'SL::DB::Chart';

      die t8('Empty transaction!')
        unless $booking->{debit} or $booking->{credit}; # must exist and not be 0
      die t8('Cannot post transaction with a debit and credit entry for the same account!')
        if defined($booking->{debit}) and defined($booking->{credit});

      my $tax = _transaction_tax_helper($booking, $chart, $transdate); # will die if tax can't be found

      $gl_transaction->add_chart_booking(
        chart      => $chart,
        debit      => $booking->{debit},
        credit     => $booking->{credit},
        tax_id     => $tax->id,
        source     => $booking->{source} // '',
        memo       => $booking->{memo}   // '',
        project_id => $booking->{project_id}
      );
    }
  };

  $gl_transaction->post;

  return $gl_transaction;
}

sub _transaction_tax_helper {
  # checks for hash-entries with key tax, tax_id or taxkey
  # returns an SL::DB::Tax object
  # can be used for booking hashref in ar_transaction, ap_transaction and gl_transaction
  # will modify hashref, e.g. removing taxkey if tax_id was also supplied

  my ($booking, $chart, $transdate) = @_;

  die "_transaction_tax_helper: chart missing"     unless $chart && ref($chart) eq 'SL::DB::Chart';
  die "_transaction_tax_helper: transdate missing" unless $transdate && ref($transdate) eq 'DateTime';

  my $tax;

  if ( defined $booking->{tax_id} ) { # tax_id may be 0
    delete $booking->{taxkey}; # ignore any taxkeys that may have been added, tax_id has precedence
    $tax = SL::DB::Tax->new(id => $booking->{tax_id})->load( with => [ 'chart' ] );
  } elsif ( $booking->{tax} ) {
    die "illegal tax entry" unless ref($booking->{tax}) eq 'SL::DB::Tax';
    $tax = $booking->{tax};
  } elsif ( defined $booking->{taxkey} ) {
    # If a taxkey is given, find the taxkey entry for that chart that
    # matches the stored taxkey and with the correct transdate. This will only work
    # if kivitendo has that taxkey configured for that chart, i.e. it should barf if
    # e.g. the bank chart is called with taxkey 3.

    # example query:
    #   select *
    #     from taxkeys
    #    where     taxkey_id = 3
    #          and chart_id = (select id from chart where accno = '8400')
    #          and startdate <= '2018-01-01'
    # order by startdate desc
    #    limit 1;

    my $taxkey = SL::DB::Manager::TaxKey->get_first(
      query        => [ and => [ chart_id  => $chart->id,
                                 startdate => { le => $transdate },
                                 taxkey    => $booking->{taxkey}
                               ]
                      ],
      sort_by      => "startdate DESC",
      limit        => 1,
      with_objects => [ qw(tax) ],
    );
    die sprintf("Chart %s doesn't have a taxkey chart configured for taxkey %s", $chart->accno, $booking->{taxkey})
      unless $taxkey;

    $tax = $taxkey->tax;
  } else {
    # use default tax for that chart if neither tax_id, tax or taxkey were defined
    my $active_taxkey = $chart->get_active_taxkey($transdate);
    $tax = $active_taxkey->tax;
    # $main::lxdebug->message(0, sprintf("found default taxrate %s for chart %s", $tax->rate, $chart->displayable_name));
  };

  die "no tax" unless $tax && ref($tax) eq 'SL::DB::Tax';
  return $tax;
};

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

Example including creation of parts and of credit_note:

  my $part1 = SL::Dev::Part::new_part(   partnumber => 'T4254')->save;
  my $part2 = SL::Dev::Part::new_service(partnumber => 'Serv1')->save;
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


Example including creation of part and of sales order:

  my $part1 = SL::Dev::Part::new_part(   partnumber => 'T4254')->save;
  my $part2 = SL::Dev::Part::new_service(partnumber => 'Serv1')->save;
  my $order = SL::Dev::Record::create_sales_order(
    save         => 1,
    taxincluded  => 0,
    orderitems => [ SL::Dev::Record::create_order_item(part => $part1, qty =>  3, sellprice => 70),
                    SL::Dev::Record::create_order_item(part => $part2, qty => 10, sellprice => 50),
                  ]
  );

Example: create 100 orders with the same part for 100 new customers:

  my $part1 = SL::Dev::Part::new_part(partnumber => 'T6256')->save;
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

Required params:

  record_type (sales_invoice, sales_order, sales_delivery_order)
  part        (an SL::DB::Part object)

Example including creation of part and of invoice:

  my $part    = SL::Dev::Part::new_part(  partnumber  => 'T4254')->save;
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

=head2 C<create_ap_transaction %PARAMS>

Creates a new AP transaction (table ap, invoice = 0), and will try to add as
many defaults as possible.

Possible parameters:
 * vendor (SL::DB::Vendor object, defaults to SL::Dev default vendor)
 * taxincluded (0 or 1, defaults to 1)
 * transdate (DateTime object, defaults to current date)
 * bookings (arrayref for the charts to be booked, see examples below)
 * amount (to check if final amount matches this amount)
 * netamount (to check if final amount matches this amount)
 * dec (number of decimals to round to, defaults to 2)
 * ap_chart (SL::DB::Chart object, default to accno 1600)
 * invnumber (defaults to 'test ap_transaction')
 * notes (defaults to 'test ap_transaction')
 * globalproject_id

Currently doesn't support exchange rates.

Minimal usage example, creating an AP transaction with a default vendor and
default bookings (telephone, postage):

  use SL::Dev::Record qw(create_ap_transaction);
  my $invoice = create_ap_transaction();

Create an AP transaction with a specific vendor and specific charts:

  my $vendor = SL::Dev::CustomerVendor::new_vendor(name => 'My Vendor')->save;
  my $chart_postage   = SL::DB::Manager::Chart->find_by(description => 'Porto');
  my $chart_telephone = SL::DB::Manager::Chart->find_by(description => 'Telefon');

  my $ap_transaction = create_ap_transaction(
    vendor      => $vendor,
    invnumber   => 'test invoice taxincluded',
    taxincluded => 1,
    amount      => 2190, # optional param for checking whether final amount matches
    netamount   => 2000, # optional param for checking whether final netamount matches
    bookings    => [
                     {
                       chart  => $chart_postage,
                       amount => 1000,
                     },
                     {
                       chart  => $chart_telephone,
                       amount => 1190,
                     },
                   ]
  );

Or the same example with tax not included, but an old transdate and old taxrate (16%):

  my $ap_transaction = create_ap_transaction(
    vendor      => $vendor,
    invnumber   => 'test invoice tax not included',
    transdate   => DateTime->new(year => 2000, month => 10, day => 1),
    taxincluded => 0,
    amount      => 2160, # optional param for checking whether final amount matches
    netamount   => 2000, # optional param for checking whether final netamount matches
    bookings    => [
                     {
                       chart  => $chart_postage,
                       amount => 1000,
                     },
                     {
                       chart  => $chart_telephone,
                       amount => 1000,
                     },
                 ]
  );

Don't use the default tax, e.g. postage with 19%:

  my $tax_9          = SL::DB::Manager::Tax->find_by(taxkey => 9, rate => 0.19);
  my $chart_postage  = SL::DB::Manager::Chart->find_by(description => 'Porto');
  my $ap_transaction = create_ap_transaction(
    invnumber   => 'postage with tax',
    taxincluded => 0,
    bookings    => [
                     {
                       chart  => $chart_postage,
                       amount => 1000,
                       tax    => $tax_9,
                     },
                   ],
  );

=head2 C<create_ar_transaction %PARAMS>

See C<create_ap_transaction>, except use customer instead of vendor.

=head2 C<create_gl_transaction %PARAMS>

Creates a new GL transaction (table gl), which is basically a wrapper around
SL::DB::GLTransaction->new(...) and add_chart_booking and post, while setting
as many defaults as possible.

Possible parameters:

 * taxincluded (0 or 1, defaults to 1)
 * transdate (DateTime object, defaults to current date)
 * dec (number of decimals to round to, defaults to 2)
 * bookings (arrayref for the charts and taxes to be booked, see examples below)

bookings must include a least:

 * chart as an SL::DB::Chart object
 * credit or debit, as positive numbers
 * tax_id, tax (an SL::DB::Tax object) or taxkey (e.g. 9)

Can't be used to create storno transactions.

Minimal usage example, using all the defaults, creating a GL transaction with
travel expenses:

  use SL::Dev::Record qw(create_gl_transaction);
  $gl_transaction = create_gl_transaction();

Create a GL transaction with a specific charts and taxes (the default taxes for
those charts are used if none are explicitly given in bookings):

  my $cash           = SL::DB::Manager::Chart->find_by( description => 'Kasse'          );
  my $betriebsbedarf = SL::DB::Manager::Chart->find_by( description => 'Betriebsbedarf' );
  $gl_transaction = create_gl_transaction(
    reference   => 'betriebsbedarf',
    taxincluded => 1,
    bookings    => [
                     {
                       chart  => $betriebsbedarf,
                       memo   => 'foo 1',
                       source => 'foo 1',
                       credit => 119,
                     },
                     {
                       chart  => $betriebsbedarf,
                       memo   => 'foo 2',
                       source => 'foo 2',
                       credit => 119,
                     },
                     {
                       chart  => $cash,
                       debit  => 238,
                       memo   => 'foo 1+2',
                       source => 'foo 1+2',
                     },
                   ],
  );


=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitec.deE<gt>

=cut
