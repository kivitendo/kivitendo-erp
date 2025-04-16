package SL::POS;

use strict;
use warnings;

use Data::Dumper;
use SL::Model::Record;
use SL::DB::ValidityToken;
use SL::DB::Order::TypeData qw(:types);
use SL::DB::DeliveryOrder::TypeData qw(:types);
use SL::DB::Invoice::TypeData qw(:types);
use SL::Controller::DeliveryOrder; # yuck
use SL::JSON;
use SL::Helper::DateTime;
use SL::Locale::String qw(t8);
use SL::POS::TSEAPI;

use SL::Dev::POS; # qw(build_tse_json_response);

sub pay_order_with_amounts {
  my ($point_of_sale, $tse_device, $transaction_number, $order, $validity_token, $cash_amount, $terminal_amount) = @_;

  # TODO: need $client_id and $transaction_number from start_transaction

  my @payments;
  my $invoice;

  SL::DB->client->with_transaction(sub {
    $invoice = SL::POS::order_to_invoice($order, $validity_token);

    if ($cash_amount) {
      my $payment = SL::POS::pay_pos_cash($invoice, $point_of_sale, $cash_amount);
      push(@payments, $payment);
    };

    if ($terminal_amount) {
      my $payment = SL::POS::pay_pos_terminal($invoice, $point_of_sale, $terminal_amount);
      push(@payments, $payment);
    };
    die "nothing to pay" if @payments == 0;
    # payments should be e.g.: @payments = ({ type => 'cash', amount => 11.90 });

    # TODO:
    # currently TSE is started and saved after the sale is completed
    # still need to start transaction when first item is added, and finish transaction here
    my ($tse_device, $tse_response) = finish_tse_transaction($tse_device, $transaction_number, $point_of_sale, $invoice, \@payments);
    my $tse_transaction = store_tse_transaction($point_of_sale, $tse_device, $transaction_number, $invoice, $tse_response); # transaction_number should already be in $tse_response
    # need to check if this succeeded, log errors and notify user if not, deal with unsuccessful TSE case

    1;
  }) || do {
    die t8("Creating receipt failed: #1", SL::DB->client->error);
  };

  return $invoice;
}

sub order_to_delivery_order {
  my ($order, $validity_token) = @_;

  my $delivery_order = SL::Model::Record->new_from_workflow(
    $order,
    SALES_DELIVERY_ORDER_TYPE(),
    {
      # no_linked_records => 1, # order is not saved   # do we want this?
    }
  );

  SL::DB->client->with_transaction(sub {
    SL::Model::Record->save(
      $delivery_order,
      with_validity_token => {
        scope => SL::DB::ValidityToken::SCOPE_ORDER_SAVE(),
        token => $validity_token
      },
    );

    $delivery_order = SL::Controller::DeliveryOrder::_add_default_transfer_to_delivery_order(
      $delivery_order
    );

    # save created delivery_order_stock_entries
    # they will be used in _do_stock_transfer
    $delivery_order->save(cascade => 1);

    $delivery_order = SL::Controller::DeliveryOrder::_do_stock_transfer(
      $delivery_order, 'out', 1
    );
    # returns saved $delivery_order
  }) || do {
    die t8("Creating delivery order failed: #1", SL::DB->client->error);
  };
}

sub order_to_invoice {
  my ($order, $validity_token) = @_;

  SL::DB->client->with_transaction(sub {
    my $delivery_order = order_to_delivery_order($order, $validity_token);

    my $invoice = SL::Model::Record->new_from_workflow(
      $delivery_order,
      INVOICE_TYPE()
    );

    $invoice->post();
  }) || do {
    die t8("Creating invoice failed: #1", SL::DB->client->error);
  };
}

sub pay_pos_cash {
  my ($invoice, $pos, $amount) = @_;

  $invoice->pay_invoice(
    chart_id  => $pos->cash_chart_id,
    amount    => $amount,
    transdate => DateTime->now->to_kivitendo,
    source    => t8('POS cash payment'),
    memo      => $pos->name,
  );

  return { type => 'cash', amount => $amount };
}

sub pay_pos_terminal {
  my ($invoice, $pos, $amount) = @_;

   $invoice->pay_invoice(
     chart_id  => $pos->ec_terminal->transfer_chart_id,
     amount    => $amount,
     transdate => DateTime->now->to_kivitendo,
     source    => t8('POS terminal payment'),
     memo      => $pos->ec_terminal->name,
   );
}

sub store_tse_transaction {
  my ($pos, $tse_device, $transaction_number, $ar, $tse_response) = @_;

  die "store_tse_transaction: invalid pos" unless ref($pos) eq 'SL::DB::PointOfSale';
  die "store_tse_transaction: invalid tse_device" unless ref($tse_device) eq 'SL::DB::TSEDevice';
  die "store_tse_transaction: invalid invoice" unless ref($ar) eq 'SL::DB::Invoice';
  die "store_tse_transaction: invalid tse_response" unless ref($tse_response) eq 'HASH';

  SL::DB::TSETransaction->new(
    ar_id => $ar->id,
    pos_id => $pos->id,
    tse_device_id => $tse_device->id,
    client_id => $tse_device->description,
    pos_serial_number => $pos->serial_number,
    transaction_number => $transaction_number,
    %$tse_response   # fields in tse_response currently match fields in DB exactly
    # process_data => $tse_response->{process_data},
    # process_type => $tse_response->{process_type},
    # sig_counter => $tse_response->{sig_counter},
    # signature => $tse_response->{signature},
    # start_timestamp => $tse_response->{start_timestamp},
    # finish_timestamp => $tse_response->{finish_timestamp},
    # transaction_number => $tse_response->{transaction_number},
    # json => $tse_response->{json}
  )->save;
}

sub finish_tse_transaction {
  my ($tse_device, $transaction_number, $pos, $invoice, $payments) = @_;
  # currently $tse_terminal isn't used
  die "missing TSEDevice" unless ref($tse_device) eq 'SL::DB::TSEDevice';
  die unless ref($pos) eq 'SL::DB::PointOfSale';
  die unless ref($invoice) eq 'SL::DB::Invoice';
  die unless ref($payments) eq 'ARRAY';

  my %finish_tse_data = (
    tse_device => $tse_device,
    transaction_number => $transaction_number,
    payments => $payments,
  );
  ##### Fake API response ######
  my $tse_response = SL::POS::TSEAPI::finish_tse_transaction(\%finish_tse_data);
  return ($tse_device, $tse_response);
}

sub parse_tse_response {
  my $json = shift;

  my %unparsed_data = %{ SL::JSON::decode_json($json) };

  my $client_id = delete $unparsed_data{"client_id"} // die "missing client_id";
  my $signature = delete $unparsed_data{"signature"} // die "missing signature";
  my $sig_counter = delete $unparsed_data{"sig_counter"};
  my $transaction_number = delete $unparsed_data{"transaction_number"};
  my $process_type = delete $unparsed_data{"process_type"};
  my $process_data = delete $unparsed_data{"process_data"};
  my $start_timestamp = DateTime->from_ymdhms(delete $unparsed_data{"start_timestamp"})->set_time_zone('UTC');
  my $finish_timestamp = DateTime->from_ymdhms(delete $unparsed_data{"finish_timestamp"})->set_time_zone('UTC');

  die "keys left over when parsing TSE: " . Dumper(\%unparsed_data)
    if keys %unparsed_data > 0;

  my %parsed_tse_response = (
    client_id => $client_id,
    signature => $signature,
    transaction_number => $transaction_number,
    start_timestamp => $start_timestamp,
    finish_timestamp => $finish_timestamp,
    process_type => $process_type,
    process_data => $process_data,
    sig_counter => $sig_counter,
    transaction_number => $transaction_number,
    json => $json,
  );
  return \%parsed_tse_response;
}

sub encode_process_data {
  MIME::Base64::encode_base64(shift, '');
}

1;
