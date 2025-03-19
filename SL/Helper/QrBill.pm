# This module consists of helper methods for generating Swiss
# billing QR-Code.
package SL::Helper::QrBill;

use strict;
use warnings;

use File::Spec ();
use Imager ();
use Imager::QRCode ();

our $VERSION = '0.02';

my %Config = (
  img_dir    => 'image',
  cross_file => 'CH-Kreuz_7mm.png',
  out_file   => 'out.png',
);

# Validate data, populate structures and return a
# SL::Helper::QrBill object.
sub new {
  my $class = shift;

  my $self = bless {}, $class;

  $self->_init_check(@_);
  $self->_init(@_);

  return $self;
}

# Populate the data structures with data received by the
# constructor.
sub _init {
  my $self = shift;
  my ($biller_information, $biller_data, $payment_information, $invoice_recipient_data, $ref_nr_data, $additional_information) = @_;

  my $address = sub {
    my ($href) = @_;
    my $address_type = $href->{address_type};
    return ((map $href->{$_}, qw(address_row1 address_row2)), '', '')
      if $address_type eq 'K';
    return  (map $href->{$_}, qw(street street_no postalcode city))
      if $address_type eq 'S';
  };

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
    $address->($biller_data),
    $biller_data->{countrycode},
  ];
  $self->{data}{payment_information} = [
    $payment_information->{amount},
    $payment_information->{currency},
  ];
  $self->{data}{invoice_recipient_data} = [
    $invoice_recipient_data->{address_type},
    $invoice_recipient_data->{name},
    $address->($invoice_recipient_data),
    $invoice_recipient_data->{countrycode},
  ];
  $self->{data}{ref_nr_data} = [
    $ref_nr_data->{type},
    $ref_nr_data->{ref_number},
  ];
  $self->{data}{additional_information} = [
    $additional_information->{unstructured_message},
    'EPD', # End Payment Data
  ];
}

# Return the regular expressions used for validating data.
sub _get_regexes {
  return (
    'biller information' => [
      [ 'iban', qr{^(?:CH|LI)[0-9a-zA-Z]{19}$} ],
    ],
    'biller data' => [
      [ 'address_type', qr{^[KS]$}     ],
      [ 'company',      qr{^.{1,70}$}  ],
      [ 'address_row1', qr{^.{0,70}$}  ], # combined (K)
      [ 'address_row2', qr{^.{0,70}$}  ], # "
      [ 'street',       qr{^.{0,70}$}  ], # structured (S)
      [ 'street_no',    qr{^.{0,16}$}  ], # "
      [ 'postalcode',   qr{^.{0,16}$}  ], # "
      [ 'city',         qr{^.{0,35}$}  ], # "
      [ 'countrycode',  qr{^[A-Z]{2}$} ],
    ],
    'payment information' => [
      [ 'amount',   qr{^(?:(?:0|[1-9][0-9]{0,8})\.[0-9]{2})?$} ],
      [ 'currency', qr{^(?:CHF|EUR)$}                          ],
    ],
    'invoice recipient data' => [
      [ 'address_type', qr{^[KS]$}     ],
      [ 'name',         qr{^.{1,70}$}  ],
      [ 'address_row1', qr{^.{0,70}$}  ], # combined (K)
      [ 'address_row2', qr{^.{0,70}$}  ], # "
      [ 'street',       qr{^.{0,70}$}  ], # structured (S)
      [ 'street_no',    qr{^.{0,16}$}  ], # "
      [ 'postalcode',   qr{^.{0,16}$}  ], # "
      [ 'city',         qr{^.{0,35}$}  ], # "
      [ 'countrycode',  qr{^[A-Z]{2}$} ],
    ],
    'reference number data' => [
      [ 'type', qr{^(?:QRR|NON)$} ],
    ],
    'additional information' => [
      [ 'unstructured_message', qr{^.{0,140}$} ],
    ],
    additional => {
      'ref_nr'  => {
        QRR => qr{^\d{27}$},
        NON => qr{^$},
      },
      'qr_iban' => qr{^.{4}3[01][0-9]{3}.{12}$},
    },
  );
}

# Validate the data with regular expressions and exit ungracefully
# if conditions are not matched.
sub _init_check {
  my $self = shift;
  my ($biller_information, $biller_data, $payment_information, $invoice_recipient_data, $ref_nr_data, $additional_information) = @_;

  my $check_re = sub {
    my ($group, $href, $elem, $regex) = @_;
    my $error = undef;
    if (!exists $href->{$elem}) {
      $error = 'does not exist';
    } elsif (!defined $href->{$elem}) {
      $error = 'is not defined';
    } elsif ($href->{$elem} !~ $regex) {
      $error = 'is not valid';
    }
    die "field '$elem' in group '$group' $error", "\n" if defined $error;
  };

  my %regexes = _get_regexes();

  my $group = 'biller information';
  foreach my $re (@{$regexes{$group}}) {
    $check_re->($group, $biller_information, @$re);
  }

  $group = 'biller data';
  foreach my $re (grep $_->[0] =~ /^(?:address_type|company)$/, @{$regexes{$group}}) {
    $check_re->($group, $biller_data, @$re);
  }
  if ($biller_data->{address_type} eq 'K') {
    foreach my $re (grep $_->[0] =~ /^address_row[12]$/, @{$regexes{$group}}) {
      $check_re->($group, $biller_data, @$re);
    }
  } elsif ($biller_data->{address_type} eq 'S') {
    foreach my $re (grep $_->[0] =~ /^(?:street(?:_no)?|postalcode|city)$/, @{$regexes{$group}}) {
      $check_re->($group, $biller_data, @$re);
    }
  }
  foreach my $re (grep $_->[0] =~ /^countrycode$/, @{$regexes{$group}}) {
    $check_re->($group, $biller_data, @$re);
  }

  $group = 'payment information';
  foreach my $re (@{$regexes{$group}}) {
    $check_re->($group, $payment_information, @$re);
  }

  $group = 'invoice recipient data';
  foreach my $re (grep $_->[0] =~ /^(?:address_type|name)$/, @{$regexes{$group}}) {
    $check_re->($group, $invoice_recipient_data, @$re);
  }
  if ($invoice_recipient_data->{address_type} eq 'K') {
    foreach my $re (grep $_->[0] =~ /^address_row[12]$/, @{$regexes{$group}}) {
      $check_re->($group, $invoice_recipient_data, @$re);
    }
  } elsif ($invoice_recipient_data->{address_type} eq 'S') {
    foreach my $re (grep $_->[0] =~ /^(?:street(?:_no)?|postalcode|city)$/, @{$regexes{$group}}) {
      $check_re->($group, $invoice_recipient_data, @$re);
    }
  }
  foreach my $re (grep $_->[0] =~ /^countrycode$/, @{$regexes{$group}}) {
    $check_re->($group, $invoice_recipient_data, @$re);
  }

  $group = 'reference number data';
  foreach my $re (@{$regexes{$group}}) {
    $check_re->($group, $ref_nr_data, @$re);
  }
  $check_re->($group, $ref_nr_data, 'ref_number', $regexes{additional}->{ref_nr}{$ref_nr_data->{type}});

  $group = 'biller information';
  if ($ref_nr_data->{type} eq 'QRR') {
    $check_re->($group, $biller_information, 'iban', $regexes{additional}->{qr_iban});
  }

  $group = 'additional information';
  foreach my $re (@{$regexes{$group}}) {
    $check_re->($group, $additional_information, @$re);
  }
}

# Generate the QR-Code image by calling internal methods.
sub generate {
  my $self = shift;
  my $out_file = $_[0] // $Config{out_file};

  $self->{qrcode} = $self->_qrcode();
  $self->{cross}  = $self->_cross();
  $self->{img}    = $self->_plot();

  $self->_paste();
  $self->_write($out_file);
}

# Return a new Imager::QRCode object.
sub _qrcode {
  my $self = shift;

  return Imager::QRCode->new(
    size   =>  4,
    margin =>  0,
    level  => 'M',
  );
}

# Read the cross file and scale the resulting image.
sub _cross {
  my $self = shift;

  my $cross = Imager->new();
  $cross->read(file => File::Spec->catfile(@Config{qw(img_dir cross_file)})) or die $cross->errstr, "\n";

  return $cross->scale(xpixels => 35, ypixels => 35, qtype => 'mixing');
}

# Order and modify the structured data, form the text and plot it.
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

# Paste cross image onto the middle of the QR-Code image.
sub _paste {
  my $self = shift;

  $self->{img}->paste(
    src  => $self->{cross},
    left => ($self->{img}->getwidth  / 2) - ($self->{cross}->getwidth  / 2),
    top  => ($self->{img}->getheight / 2) - ($self->{cross}->getheight / 2),
  );
}

# Write the QR-Code image to a file.
sub _write {
  my $self = shift;
  my ($out_file) = @_;

  $self->{img}->write(file => $out_file) or die $self->{img}->errstr, "\n";
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Helper::QrBill - Helper methods for generating Swiss billing QR-Code

=head1 SYNOPSIS

     use SL::Helper::QrBill;

     eval {
       my $qr_image = SL::Helper::QrBill->new(
         \%biller_information,
         \%biller_data,
         \%payment_information,
         \%invoice_recipient_data,
         \%ref_nr_data,
         \%additional_information,
       );
       $qr_image->generate($out_file);
     } or do {
       local $_ = $@; chomp; my $error = $_;
       $::form->error($::locale->text('QR-Image generation failed: ' . $error));
     };

=head1 DESCRIPTION

This module generates the Swiss billing QR-Code with data provided to the constructor.

=head1 METHODS

=head2 C<new>

Creates a new object. Expects six references to hashes as arguments.

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

Fields (mandatory): address_type, company and countrycode.
Fields (combined): address_row1 and address_row2.
Fields (structured): street, street_no, postalcode and city.

=over 4

=item C<address_type>

Fixed length; 1-digit, alphanumerical.

=item C<company>

Maximum of 70 characters, name (surname allowable) or company.

=item C<address_row1>

Maximum of 70 characters, street/no.

=item C<address_row2>

Maximum of 70 characters, postal code/city.

=item C<street>

Maximum of 70 characters, street.

=item C<street_no>

Maximum of 16 characters, street no.

=item C<postalcode>

Maximum of 16 characters, postal code.

=item C<city>

Maximum of 35 characters, city.

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

Fields (mandatory): address_type, name and countrycode.
Fields (combined): address_row1 and address_row2.
Fields (structured): street, street_no, postalcode and city.

=over 4

=item C<address_type>

Fixed length; 1-digit, alphanumerical.

=item C<name>

Maximum of 70 characters, name (surname allowable) or company.

=item C<address_row1>

Maximum of 70 characters, street/no.

=item C<address_row2>

Maximum of 70 characters, postal code/city.

=item C<street>

Maximum of 70 characters, street.

=item C<street_no>

Maximum of 16 characters, street no.

=item C<postalcode>

Maximum of 16 characters, postal code.

=item C<city>

Maximum of 35 characters, city.

=item C<countrycode>

2-digit country code according to ISO 3166-1.

=back

=item C<%ref_nr_data>

Fields: type and ref_number.

=over 4

=item C<type>

Maximum of 4 characters, alphanumerical. QRR/NON.

=item C<ref_number>

QR-Reference: 27 characters, numerical; without Reference: empty.

=back

=item C<%additional_information>

Fields: unstructured_message.

=over 4

=item C<unstructured_message>

Maximum of 140 characters, unstructured message.

=back

=back

=head2 C<generate>

Generates the QR-Code image. Accepts filename of image as argument.
Defaults to C<out.png>.

=head1 TESTS

Tests may be invoked by executing C<t/test.pl t/helper/qrbill.t>
within the root directory of the repository.

=head1 AUTHOR

Steven Schubiger E<lt>stsc@refcnt.orgE<gt>

=cut
