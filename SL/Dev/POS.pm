package SL::Dev::POS;

use strict;
use base qw(Exporter);
use Data::Dumper;
our @EXPORT_OK = qw(
  create_ec_terminal
  create_tse_terminal
  create_tse_device
  create_receipt_printer
  create_pos
  create_printer
  build_tse_json_response
  build_process_data
  build_tse_response
  create_tse_transaction
);
our %EXPORT_TAGS = (ALL => \@EXPORT_OK);

use SL::DB::ECterminal;
use SL::DB::ReceiptPrinter;
use SL::DB::PointOfSale;
use SL::DB::TSEterminal;
use SL::DB::TSEDevice;
use SL::DB::TSETransaction;
use SL::DB::Printer;
use SL::POS;
use SL::Dev::Record;
use SL::JSON;


sub build_process_data {
  # process_data only depends on payments
  # only needed for testing, or maybe later for parsing
  my ($payments) = @_;
  die unless ref($payments) eq 'ARRAY';
  die "no payments" if @$payments == 0;

  my $process_data;

  # for now only handle one cash payment
  my $payment = shift @$payments;
  my $formatted_amount = _format_paid_amount($payment->{amount});

  if ($payment->{type} eq 'cash' && $formatted_amount > 0 ) {
    $process_data = 'Beleg^' . $formatted_amount . '_0.00_0.00_0.00_0.00^' . $formatted_amount . ':Bar';
  } else {
    die "Dev build_process_data can currently only handle one cash payment:" . Dumper($payment);
  };
  return $process_data;
}

sub build_tse_json_response {
  my (%params) = @_;

  my $utc_now = DateTime->now();
  my $default_process_data = 'Beleg^100.00_0.00_0.00_0.00_0.00^100.00:Bar';

  my $response = {
    client_id => $params{client_id} // "POS5",
    signature => $params{signature} // "1231313",
    process_type => $params{process_type} // 'Kassenbeleg-V1',
    process_data => SL::POS::encode_process_data($params{process_data} // $default_process_data),
    sig_counter => $params{sig_counter} //_get_next_sig_counter(),
    start_timestamp => $params{start_timestamp} // $utc_now->subtract('seconds' => 2)->iso8601 . "Z",
    finish_timestamp => $params{finish_timestamp} // $utc_now->iso8601 . "Z",
    transaction_number => $params{transaction_number} // _get_next_transaction_number(),
  };

  SL::JSON::encode_json($response);
}

sub build_tse_response {
  my ($params) = @_;

  my %params = %$params;

  my $signature = $params{signature} // "123123123123131";

  my $process_data = $params{process_data} // 'Beleg^100.00_0.00_0.00_0.00_0.00^100.00:Bar';
  my $encoded_process_data = SL::POS::encode_process_data($process_data);

  my $utc_now = DateTime->now();

  my %tse_response = (
    process_type => $params{process_type} // 'Kassenbeleg-V1',
    sig_counter => $params{sig_counter} //_get_next_sig_counter(),
    process_data => $encoded_process_data,
    signature => $params{signature} // "123123123123131",
    start_timestamp => $params{start_timestamp} // $utc_now->subtract('seconds' => 2),
    finish_timestamp => $params{finish_timestamp} // $utc_now,
    transaction_number => $params{transaction_number} // _get_next_transaction_number(),
  );
  return \%tse_response;
}

sub create_tse_transaction {
  my (%params) = @_;

  my $pos          = $params{pos}          // create_pos();
  my $tse_device   = $params{tse_device}   // create_tse_device();
  my $ar           = $params{ar}           // SL::Dev::Record::create_sales_invoice();
  my $tse_response = $params{tse_response} // build_tse_response();

  # SL::POS::create_tse_transaction($pos,
  SL::POS::create_tse_transaction($pos, $tse_device, $ar, $tse_response);
  # SL::DB::TSETransaction->new(
  #   pos_id => $pos->id,
  #   pos_serial_number => $pos->serial_number,
  #   process_data => $tse_response->{process_data},
  #   process_type => $tse_response->{process_type},
  #   sig_counter => $tse_response->{sig_counter},
  #   signature => $tse_response->{signature},
  #   start_timestamp => $tse_response->{start_timestamp},
  #   finish_timestamp => $tse_response->{finish_timestamp},
  #   transaction_number => $tse_response->{transaction_number},
  #   tse_device_id => $tse_device->id,
  #   client_id => $params{client} ? $params{client} : 'TEST', # should be tse_device->description?
  #   ar_id => $ar->id,
  # )->save;
}

sub create_printer {
  my (%params) = @_;
  SL::DB::Printer->new(
    printer_description => $params{printer_description} // "printer1",
    printer_command => $params{printer_command} // "",
    template_code => $params{template_code} // ""
  )->save;
}

sub create_ec_terminal {
  my (%params) = @_;

  my $ec_terminal = SL::DB::ECterminal->new(
    name => $params{name} // 'EC1',
    ip_address => $params{ip_address} // 'localhost',
    transfer_chart_id => $params{transfer_chart_id} // SL::DB::Manager::Chart->find_by(description => 'Kasse')->id,
    # %params
  )->save;
}

sub create_tse_terminal {
  my (%params) = @_;

  my $tse_terminal = SL::DB::TSEterminal->new(
    # defaults that may be overridden via params
    name => $params{name} // 'TSE Terminal 1',
    ip_address => $params{ip_address} // 'localhost'
  )->save;
}

sub create_tse_device {
  my (%params) = @_;

  my $default_device_id = 'TSE_439A361F12696C620D7F904DBF3C5283681C0C950875747492603093927FD5_3';

  my $tse_device = SL::DB::Manager::TSEDevice->find_by(device_id => $default_device_id)
    # defaults that may be overridden via params
    // SL::DB::TSEDevice->new(
    description => $params{description} // 'TSE Device 1',
    device_id   => $params{device_id}   // $default_device_id,
    serial      => $params{serial}      // "439A361F12696C620D7F904DBF3C5283681C0C950875747492603093927FD5",
    active      => 1
  );
  $tse_device->assign_attributes( %params );
  $tse_device->save;
}

sub create_receipt_printer {
  my (%params) = @_;

  my $pos = SL::DB::ReceiptPrinter->new(
    name => delete $params{name} // 'RP1',
    ip_address => delete $params{ip_address} // 'localhost'
  )->save;
}

sub create_pos {
  my (%params) = @_;

  my $pos = SL::DB::PointOfSale->new(
    name => delete $params{name} // 'POS1',
    #ip_address => delete $params{ip_address} // 'localhost',
    cash_chart_id => $params{cash_chart_id} // SL::DB::Manager::Chart->find_by(description => 'Kasse')->id,
    receipt_printer_id => $params{receipt_printer_id} // SL::DB::Manager::ReceiptPrinter->get_first->id,
    project_id => $params{project_id} // SL::DB::Manager::Project->get_first->id,
    delivery_order_printer_id => $params{delivery_order_printer_id} // SL::DB::Manager::Project->get_first->id,
    invoice_printer_id => $params{invoice_printer_id} // SL::DB::Manager::Printer->get_first->id,
    delivery_order_printer_id => $params{delivery_order_printer_id} // SL::DB::Manager::Printer->get_first->id,
    ec_terminal_id => $params{ec_terminal_id} // SL::DB::Manager::ECterminal->get_first->id,
    tse_terminal_id => $params{ec_terminal_id} // SL::DB::Manager::TSEterminal->get_first->id,
    invoice_template => $params{invoice_template} // "",
    delivery_order_template => $params{invoice_template} // "",
    invoice_copies => $params{invoice_copies} // 1,
    delivery_order_copies => $params{delivery_order_copies} // 1,
    serial_number => $params{serial_number} // "POS1",
    # %params  # all fields are not null
  )->save;
}

sub _get_next_sig_counter {
  my $last_sig_counter = SL::DB::Manager::TSETransaction->get_objects(
    select => [ \"MAX(sig_counter) AS sig_counter" ],
    limit  => 1,
  )->[0]->{sig_counter} // 0;
  $last_sig_counter + 1;
}

sub _get_next_transaction_number {
  my $last_transaction_counter = SL::DB::Manager::TSETransaction->get_objects(
    select => [ \"MAX(transaction_number) AS transaction_number" ],
    limit  => 1,
  )->[0]->{transaction_number} // 0;
  $last_transaction_counter + 1;
}

sub _format_paid_amount {
  my $amount = shift;
  sprintf("%.2f", $amount);
}

1;

__END__

=head1 NAME

SL::Dev::POS - create POS objects for testing, with minimal defaults

=head1 FUNCTIONS

=head2 C<create_ec_terminal %PARAMS>

Creates a new EC terminal object.

  my $ec_terminal = SL::Dev::POS::create_ec_terminal();


=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
