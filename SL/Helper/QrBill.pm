package SL::Helper::QrBill;

use strict;
use warnings;

use Imager;
use Imager::QRCode;

my %Config = (
  cross_file => 'image/CH-Kreuz_7mm.png',
  out_file   => 'out.png',
);

sub new {
  my $class = shift;

  my $self = bless {}, $class;

  $self->_init_check(@_);
  $self->_init(@_);

  return $self;
}

sub _init {
  my $self = shift;
  my ($biller_information, $biller_data, $payment_information, $invoice_recipient_data, $ref_nr_data) = @_;

  $self->{data}{header} = [
    'SPC',  # QRType
    '0200', # Version
     1,     # Coding Type
  ];
  $self->{data}{biller_information} = [
    $biller_information->{iban},
  ];
  $self->{data}{biller_data} = [
    $biller_data->{address_type},
    $biller_data->{company},
    $biller_data->{address_row1},
    $biller_data->{address_row2},
    '',
    '',
    $biller_data->{countrycode},
  ];
  $self->{data}{payment_information} = [
    $payment_information->{amount},
    $payment_information->{currency},
  ];
  $self->{data}{invoice_recipient_data} = [
    $invoice_recipient_data->{address_type},
    $invoice_recipient_data->{name},
    $invoice_recipient_data->{address_row1},
    $invoice_recipient_data->{address_row2},
    '',
    '',
    $invoice_recipient_data->{countrycode},
  ];
  $self->{data}{ref_nr_data} = [
    $ref_nr_data->{type},
    $ref_nr_data->{ref_number},
  ];
  $self->{data}{additional_information} = [
    '',
    'EPD', # End Payment Data
  ];
}

sub _init_check {
  my $self = shift;
  my ($biller_information, $biller_data, $payment_information, $invoice_recipient_data, $ref_nr_data) = @_;

  my $check_re = sub {
    my ($href, $elem, $regex) = @_;
    defined $href->{$elem} && $href->{$elem} =~ $regex
      or die "parameter '$elem' not valid", "\n";
  };

  $check_re->($biller_information, 'iban', qr{^(?:CH|LI)[0-9a-zA-Z]{19}$});

  $check_re->($biller_data, 'address_type', qr{^[KS]$});
  $check_re->($biller_data, 'company', qr{^.{1,70}$});
  $check_re->($biller_data, 'address_row1', qr{^.{0,70}$});
  $check_re->($biller_data, 'address_row2', qr{^.{0,70}$});
  $check_re->($biller_data, 'countrycode', qr{^[A-Z]{2}$});

  $check_re->($payment_information, 'amount', qr{^(?:(?:0|[1-9][0-9]{0,8})\.[0-9]{2})?$});
  $check_re->($payment_information, 'currency', qr{^(?:CHF|EUR)$});

  $check_re->($invoice_recipient_data, 'address_type', qr{^[KS]$});
  $check_re->($invoice_recipient_data, 'name', qr{^.{1,70}$});
  $check_re->($invoice_recipient_data, 'address_row1', qr{^.{0,70}$});
  $check_re->($invoice_recipient_data, 'address_row2', qr{^.{0,70}$});
  $check_re->($invoice_recipient_data, 'countrycode', qr{^[A-Z]{2}$});

  my %ref_nr_regexes = (
    QRR => qr{^\d{27}$},
    NON => qr{^$},
  );
  $check_re->($ref_nr_data, 'type', qr{^(?:QRR|SCOR|NON)$});
  $check_re->($ref_nr_data, 'ref_number', $ref_nr_regexes{$ref_nr_data->{type}});
}

sub generate {
  my $self = shift;
  my $out_file = defined $_[0] ? $_[0] : $Config{out_file};

  $self->{qrcode} = $self->_qrcode();
  $self->{cross}  = $self->_cross();
  $self->{img}    = $self->_plot();

  $self->_paste();
  $self->_write($out_file);
}

sub _qrcode {
  my $self = shift;

  return Imager::QRCode->new(
    size   =>  4,
    margin =>  0,
    level  => 'M',
  );
}

sub _cross {
  my $self = shift;

  my $cross = Imager->new();
  $cross->read(file => $Config{cross_file}) or die $cross->errstr, "\n";

  return $cross->scale(xpixels => 27, ypixels => 27, qtype => 'mixing');
}

sub _plot {
  my $self = shift;

  my @data = (
    @{$self->{data}{header}},
    @{$self->{data}{biller_information}},
    @{$self->{data}{biller_data}},
    ('') x 7, # for future use
    @{$self->{data}{payment_information}},
    @{$self->{data}{invoice_recipient_data}},
    @{$self->{data}{ref_nr_data}},
    @{$self->{data}{additional_information}},
  );

  foreach (@data) {
    s/[\r\n]/ /g;
    s/ {2,}/ /g;
    s/^\s+//;
    s/\s+$//;
  }
                  # CR + LF
  my $text = join "\015\012", @data;

  return $self->{qrcode}->plot($text);
}

sub _paste {
  my $self = shift;

  $self->{img}->paste(
    src  => $self->{cross},
    left => ($self->{img}->getwidth  / 2) - ($self->{cross}->getwidth  / 2),
    top  => ($self->{img}->getheight / 2) - ($self->{cross}->getheight / 2),
  );
}

sub _write {
  my $self = shift;
  my ($out_file) = @_;

  $self->{img}->write(file => $out_file) or die $self->{img}->errstr, "\n";
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Helper::QrBill - Helper methods for generating Swiss QR-Code

=head1 SYNOPSIS

     use SL::Helper::QrBill;

     eval {
       my $qr_image = SL::Helper::QrBill->new(
         \%biller_information,
         \%biller_data,
         \%payment_information,
         \%invoice_recipient_data,
         \%ref_nr_data,
       );
       $qr_image->generate($outfile);
     } or do {
       local $_ = $@; chomp; my $error = $_;
       $::form->error($::locale->text('QR-Image generation failed: ' . $error));
     };

=head1 DESCRIPTION

This module generates the Swiss QR-Code with data provided to the constructor.

=head1 METHODS

=head2 C<new>

Creates a new object. Expects five references to hashes as arguments.

The hashes are structured as follows:

=over 4

=item C<%biller_information>

Fields: iban.

=over 4

=item C<iban>

Fixed length; 21 alphanumerical characters, only IBANs with CH- or LI-
country code.

=back

=item C<%biller_data>

Fields: address_type, company, address_row1, address_row2 and countrycode.

=over 4

=item C<address_type>

Fixed length; 1-digit, alphanumerical. 'K' implemented only.

=item C<company>

Maximum of 70 characters, name (surname allowable) or company.

=item C<address_row1>

Maximum of 70 characters, street/nr.

=item C<address_row2>

Maximum of 70 characters, postal code/place.

=item C<countrycode>

2-digit country code according to ISO 3166-1.

=back

=item C<%payment_information>

Fields: amount and currency.

=over 4

=item C<amount>

Decimal, no leading zeroes, maximum of 12 digits (inclusive decimal
separator and places). Only dot as decimal separator is permitted.

=item C<currency>

CHF/EUR.

=back

=item C<%invoice_recipient_data>

Fields: address_type, name, address_row1, address_row2 and countrycode.

=over 4

=item C<address_type>

Fixed length; 1-digit, alphanumerical. 'K' implemented only.

=item C<name>

Maximum of 70 characters, name (surname allowable) or company.

=item C<address_row1>

Maximum of 70 characters, street/nr.

=item C<address_row2>

Maximum of 70 characters, postal code/place.

=item C<countrycode>

2-digit country code according to ISO 3166-1.

=back

=item C<%ref_nr_data>

Fields: type and ref_number.

=over 4

=item C<type>

Maximum of 4 characters, alphanumerical. QRR/SCOR/NON.

=item C<ref_number>

QR-Reference: 27 characters, numerical; without Reference: empty.

=back

=back

=head2 C<generate>

Generates the QR-Code image. Accepts filename of image as argument.
Defaults to C<out.png>.

=head1 AUTHOR

Steven Schubiger E<lt>stsc@refcnt.orgE<gt>

=cut
