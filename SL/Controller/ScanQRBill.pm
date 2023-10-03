package SL::Controller::ScanQRBill;

use strict;
use parent qw(SL::Controller::Base);

use List::Util qw(first);
use URI::Escape;

use SL::Helper::QrBillParser;
use SL::DB::Vendor;
use SL::DB::Chart;
use SL::DB::Tax;
use SL::DB::ValidityToken;

use Rose::Object::MakeMethods::Generic(
  #scalar => [ qw() ],
  'scalar --get_set_init' => [ qw(vendors accounts_AP_amount accounts_AP taxcharts) ],
);

# check permissions
__PACKAGE__->run_before(sub { $::auth->assert('ap_transactions'); });

################ actions #################

sub action_scan_view {
  my ($self) = @_;

  $::request->layout->add_javascripts('html5-qrcode.js');
  $::request->layout->add_javascripts('kivi.ScanQRBill.js');

  $self->render('scan_qrbill/scan_view',
    transaction_success => $::form->{transaction_success} // '0',
    invoice_number => $::form->{invnumber} // '',
    developer => $::auth->assert('developer', 1) ? '1' : '0',
  );
}

sub action_handle_scan_result {
  my ($self) = @_;

  my $qrtext = $::form->{qrtext};

  # load text into object
  $self->{qr_obj} = SL::Helper::QrBillParser->new($qrtext);

  # check if valid qr-bill
  if (!$self->{qr_obj}->is_valid) {
    return $self->js
      ->run('kivi.ScanQRBill.popupInvalidQRBill', $self->{qr_obj}->error)
      ->render();
  }

  my $vendor_name = $self->{qr_obj}->{creditor}->{name};
  $self->{vendor} = first { $_->{name} eq $vendor_name } @{ $self->vendors };

  if (!$self->{vendor}) {
    return $self->js
      ->run('kivi.ScanQRBill.popupVendorNotFound', $vendor_name)
      ->render();
  }

  $self->prepare_add_purchase_transaction();
}

################# internal ###############

sub prepare_add_purchase_transaction {
  my ($self) = @_;

  my $qr_obj = $self->{qr_obj};

  my $token = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_PURCHASE_INVOICE_POST())->token;

  my $html = $self->render('scan_qrbill/_add_purchase_transaction',
    { output => 0 },
    vendor => {
      name => $self->{vendor}->{name},
      number => $self->{vendor}->{vendornumber},
      id => $self->{vendor}->{id},
    },
    qrbill => {
      unstructured_message => $qr_obj->{additional_information}->{unstructured_message},
      reference_type => $qr_obj->{payment_reference}->{reference_type},
      reference => $qr_obj->{payment_reference}->{reference},
      amount => $qr_obj->{payment_amount_information}->{amount},
      currency => $qr_obj->{payment_amount_information}->{currency},
      data_encoded => uri_escape($qr_obj->raw_data),
    },
    accounts_AP_amount => $self->accounts_AP_amount,
    accounts_AP => $self->accounts_AP,
    taxcharts => $self->taxcharts,
    form_validity_token => $token,
  );

  $self->js->html('#main-content', $html)->render();
}

sub init_vendors {
  SL::DB::Manager::Vendor->get_all();
}

sub init_accounts_AP_amount {
  [ map { {
      text => "$_->{accno} - $_->{description}",
      accno => $_->{accno},
      id => $_->{id},
      chart_id => $_->{id},
    } } @{ SL::DB::Manager::Chart->get_all(
      query   => [ SL::DB::Manager::Chart->link_filter('AP_amount') ],
      sort_by => 'accno ASC') }
  ];
}

sub init_accounts_AP {
  [ map { {
      text => "$_->{accno} - $_->{description}",
      accno => $_->{accno},
      id => $_->{id},
      chart_id => $_->{id},
    } } @{ SL::DB::Manager::Chart->get_all(
      query   => [ SL::DB::Manager::Chart->link_filter('AP') ],
      sort_by => 'accno ASC') }
  ];
}

sub init_taxcharts {
  [ map { {
      text => "$_->{taxkey} - $_->{taxdescription} " . ($_->{rate} * 100) .' %',
      id => "$_->{id}--$_->{rate}",
    } } @{ SL::DB::Manager::Tax->get_all(
    where   => [ chart_categories => { like => '%E%' }],
    sort_by => 'taxkey, rate') }
  ];
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

SL::Controller::ScanQRBill - Controller for scanning swiss QR-Bills using the mobile template

=head1 DESCRIPTION

Renders the scan view in the mobile template and handles the scan result.

The scanned QR-Bill data is parsed and the vendor is searched in the database.

If everything is valid an add purchase transaction view is rendered and
the QR-Bill can be saved as a purchase transaction.

The post function from ap.pl is used to save the purchase transaction.

The raw data of the QR-Bill is stored with the purchase transaction in the ap table
in the field qrbill_data.
The data can later be accessed again using the parser module SL::Helper::QrBillParser.

=head1 SECURITY CONSIDERATIONS

In theory an attacker could try to insert a malicious Javascript code into a qr code,
that is then scanned, and redisplayed in the browser (XSS).

Therefore it is important to escape any data coming from the qr code when it is rendered
in the templates. For this we use the template toolkit html filter: [% qrdata | html %],
Jquery's text function: $('#qrdata').text(qrdata);, and URI::Escape; for the raw data.

For database insertion we use prepared statements (AP.pm).

=head1 TESTING

To simplify testing the scan view shows some buttons to send example qr codes, when in
developer mode. Sending is implemented in Javascript in js/kivi.ScanQRBill.js.

=head1 URL ACTIONS

=over 4

=item C<scan_view>

Renders the scan view in the mobile template.

=item C<handle_scan_result>

Handles the scan result and renders the add purchase transaction view.

=back

=head1 TODO

=head2 Additional features:

=over 4

=item * automatically extract invoice number and dates etc. from "SWICO-String" if present

=item * Option to add the vendor if not found

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Cem Aydin E<lt>cem.aydin@revamp-it.chE<gt>

=cut
