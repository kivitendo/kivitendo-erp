package SL::Helper::QrBillParser;

use strict;
use warnings;

use Rose::Object::MakeMethods::Generic(
  scalar                  => [ qw(is_valid error raw_data) ],
  'scalar --get_set_init' => [ qw(spec) ],
);

our $VERSION = '0.01';

use constant {
  REGEX_QRTYPE               => qr{^SPC$},
  REGEX_VERSION              => qr{^0200$},
  REGEX_CODING               => qr{^1$},
  REGEX_IBAN                 => qr{^(?:CH|LI)[0-9a-zA-Z]{19}$},
  REGEX_ADDRESS_TYPE         => qr{^[KS]$},
  REGEX_NAME                 => qr{^.{1,70}$},
  REGEX_ADDRESS_LINE         => qr{^.{0,70}$},
  REGEX_POSTAL_CODE          => qr{^.{0,16}$},
  REGEX_TOWN                 => qr{^.{0,35}$},
  REGEX_COUNTRY              => qr{^[A-Za-z]{2}$},
  REGEX_AMOUNT               => qr{^(?:(?:0|[1-9][0-9]{0,8})\.[0-9]{2})?$},
  REGEX_CURRENCY             => qr{^(?:CHF|EUR)$},
  REGEX_REFERENCE_TYPE       => qr{^(?:QRR|SCOR|NON)$},
  REGEX_REFERENCE            => qr{^.{0,27}$},
  REGEX_UNSTRUCTURED_MESSAGE => qr{^.{0,140}$},
  REGEX_TRAILER              => qr{^EPD$},
  REGEX_BILL_INFORMATION     => qr{^.{0,140}$},
  REGEX_ALTERNATIVE_SCHEME_PARAMETER      => qr{^.{0,100}$},
  REGEX_STREET_NAME_FROM_ADDRESS_LINE     => qr{^(.*)\s+\d.*$},
  REGEX_BUILDING_NUMBER_FROM_ADDRESS_LINE => qr{^.*\s+(\d+.*)$},
  REGEX_POSTAL_CODE_FROM_ADDRESS_LINE     => qr{^(\d+).*$},
  REGEX_TOWN_FROM_ADDRESS_LINE            => qr{^\d+\s(.*)$},
};

sub new {
  my $class = shift;

  my $self = bless {}, $class;

  $self->init(@_);

  return $self;
}

sub init {
  my $self = shift;
  my ($qrtext) = @_;

  my @lines = split /(?:\n|\r\n)/, $qrtext;

  $self->is_valid(1);
  $self->error('');
  $self->raw_data($qrtext);

  for my $section ( @{$self->spec} ) {
    for my $field ( @{$section->{fields}} ) {
      my $value = $lines[$field->{line_number}];

      if (!test_value($value, $field->{test}, $field->{status})) {
        $self->error("Test failed: Section: '$section->{section}' Field: '$field->{name}' Value: '$value'");
        $self->is_valid(0);
        last;
      }

      $self->{$section->{section}} = {} if (!$self->{$section->{section}});
      $self->{$section->{section}}->{$field->{name}} = $value;
    }
    last if $self->error;
  }
}

sub get_creditor_field {
  my $self = shift;
  my ($structured_field, $extract_field, $extract_regex) = @_;

  if ($self->{creditor}->{address_type} eq 'S') {
    return $self->{creditor}->{$structured_field};
  }
  # extract
  $self->{creditor}->{$extract_field} =~ $extract_regex;

  return $1 // '';
}

sub get_creditor_street_name {
  # extract street name from street_or_address_line_1
  # the regex matches everything until the first digit
  return shift->get_creditor_field(
    'street_or_address_line_1',
    'street_or_address_line_1',
    REGEX_STREET_NAME_FROM_ADDRESS_LINE
  );
}

sub get_creditor_building_number {
  # extract building number from street_or_address_line_1
  # the regex matches the first digit and everything after
  return shift->get_creditor_field(
    'building_number_or_address_line_2',
    'street_or_address_line_1',
    REGEX_BUILDING_NUMBER_FROM_ADDRESS_LINE
  );
}

sub get_creditor_post_code {
  # extract post code from building_number_or_address_line_2
  # the regex matches the first digits
  return shift->get_creditor_field(
    'postal_code',
    'building_number_or_address_line_2',
    REGEX_POSTAL_CODE_FROM_ADDRESS_LINE
  );
}

sub get_creditor_town_name {
  # extract town name from building_number_or_address_line_2
  # the regex matches everything after the first digits
  return shift->get_creditor_field(
    'town',
    'building_number_or_address_line_2',
    REGEX_TOWN_FROM_ADDRESS_LINE
  );
}

sub init_spec {
  [
    {
      section => 'header',
      fields  => [
        {
          name        => 'qrtype',
          line_number => 0,
          test        => REGEX_QRTYPE,
          status      => 'M'
        },
        {
          name        => 'version',
          line_number => 1,
          test        => REGEX_VERSION,
          status      => 'M'
        },
        {
          name        => 'coding',
          line_number => 2,
          test        => REGEX_CODING,
          status      => 'M'
        }
      ]
    },
    {
      section => 'creditor_information',
      fields  => [
        {
          name        => 'iban',
          line_number => 3,
          test        => REGEX_IBAN,
          status      => 'M'
        }
      ]
    },
    {
      section => 'creditor',
      fields  => [
        {
          name        => 'address_type',
          line_number => 4,
          test        => REGEX_ADDRESS_TYPE,
          status      => 'M',
        },
        {
          name        => 'name',
          line_number => 5,
          test        => REGEX_NAME,
          status      => 'M',
        },
        {
          name        => 'street_or_address_line_1',
          line_number => 6,
          test        => REGEX_ADDRESS_LINE,
          status      => 'O'
        },
        {
          name        => 'building_number_or_address_line_2',
          line_number => 7,
          test        => REGEX_ADDRESS_LINE,
          status      => 'O'
        },
        {
          name        => 'postal_code',
          line_number => 8,
          test        => REGEX_POSTAL_CODE,
          status      => 'D'
        },
        {
          name        => 'town',
          line_number => 9,
          test        => REGEX_TOWN,
          status      => 'D'
        },
        {
          name        => 'country',
          line_number => 10,
          test        => REGEX_COUNTRY,
          status      => 'M'
        }
      ]
    },
    {
      section => 'ultimate_creditor',
      fields  => [
        {
          name        => 'address_type',
          line_number => 11,
          test        => REGEX_ADDRESS_TYPE,
          status      => 'X'
        },
        {
          name        => 'name',
          line_number => 12,
          test        => REGEX_NAME,
          status      => 'X'
        },
        {
          name        => 'street_or_address_line_1',
          line_number => 13,
          test        => REGEX_ADDRESS_LINE,
          status      => 'X'
        },
        {
          name        => 'building_number_or_address_line_2',
          line_number => 14,
          test        => REGEX_ADDRESS_LINE,
          status      => 'X'
        },
        {
          name        => 'postal_code',
          line_number => 15,
          test        => REGEX_POSTAL_CODE,
          status      => 'X'
        },
        {
          name        => 'town',
          line_number => 16,
          test        => REGEX_TOWN,
          status      => 'X'
        },
        {
          name        => 'country',
          line_number => 17,
          test        => REGEX_COUNTRY,
          status      => 'X'
        }
      ]
    },
    {
      section => 'payment_amount_information',
      fields  => [
        {
          name        => 'amount',
          line_number => 18,
          test        => REGEX_AMOUNT,
          status      => 'O'
        },
        {
          name        => 'currency',
          line_number => 19,
          test        => REGEX_CURRENCY,
          status      => 'M'
        }
      ]
    },
    {
      section => 'ultimate_debtor',
      fields  => [
        {
          name        => 'address_type',
          line_number => 20,
          test        => REGEX_ADDRESS_TYPE,
          status      => 'D'
        },
        {
          name        => 'name',
          line_number => 21,
          test        => REGEX_NAME,
          status      => 'D'
        },
        {
          name        => 'street_or_address_line_1',
          line_number => 22,
          test        => REGEX_ADDRESS_LINE,
          status      => 'O'
        },
        {
          name        => 'building_number_or_address_line_2',
          line_number => 23,
          test        => REGEX_ADDRESS_LINE,
          status      => 'O'
        },
        {
          name        => 'postal_code',
          line_number => 24,
          test        => REGEX_POSTAL_CODE,
          status      => 'D'
        },
        {
          name        => 'town',
          line_number => 25,
          test        => REGEX_TOWN,
          status      => 'D'
        },
        {
          name        => 'country',
          line_number => 26,
          test        => REGEX_COUNTRY,
          status      => 'D'
        }
      ]
    },
    {
      section => 'payment_reference',
      fields  => [
        {
          name        => 'reference_type',
          line_number => 27,
          test        => REGEX_REFERENCE_TYPE,
          status      => 'M'
        },
        {
          name        => 'reference',
          line_number => 28,
          test        => REGEX_REFERENCE,
          status      => 'D'
        }
      ]
    },
    {
      section => 'additional_information',
      fields  => [
        {
          name        => 'unstructured_message',
          line_number => 29,
          test        => REGEX_UNSTRUCTURED_MESSAGE,
          status      => 'O'
        },
        {
          name        => 'trailer',
          line_number => 30,
          test        => REGEX_TRAILER,
          status      => 'M'
        },
        {
          name        => 'bill_information',
          line_number => 31,
          test        => REGEX_BILL_INFORMATION,
          status      => 'A'
        }
      ]
    },
    {
      section => 'alternative_scheme',
      fields  => [
        {
          name        => 'alternative_scheme_parameter1',
          line_number => 32,
          test        => REGEX_ALTERNATIVE_SCHEME_PARAMETER,
          status      => 'A'
        },
        {
          name        => 'alternative_scheme_parameter2',
          line_number => 33,
          test        => REGEX_ALTERNATIVE_SCHEME_PARAMETER,
          status      => 'A'
        }
      ]
    }
  ];
}

### helper

sub test_value {
  my ($value, $test, $status) = @_;

  # mandatory fields must have a content
  return 0 if $status eq 'M' && length $value <= 0;

  # optional fields can be empty
  return 1 if $status eq 'O' && length $value == 0;

  # dependent fields can be empty
  return 1 if $status eq 'D' && length $value == 0;

  # "do not fill" fields cannot have a content
  if ($status eq 'X') {
    return 1 if ($value eq '');
    return 0;
  }

  # additional fields can be undefined
  if ($status eq 'A') {
    return 1 if !defined($value);
    return 0 if $value !~ $test;
    return 1;
  }

  return 0 if !defined($value);
  return 0 if $value !~ $test;
  return 1;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Helper::QrBillParser - Helper for parsing QR bill data

=head1 SYNOPSIS

  use SL::Helper::QrBillParser;

  my $qr_obj = SL::Helper::QrBillParser->new($item->{qrbill_data});

  my $valid = $qr_obj->is_valid;
  my $error_message = $qr_obj->error;
  my $qrtext = $qr_obj->raw_data;

  # data for remittance information
  my $reference = $qr_obj->{payment_reference}->{reference};
  my $unstructured_message = $qr_obj->{additional_information}->{unstructured_message}

  # set currency and amount
  my $currency = $qr_obj->{payment_amount_information}->{currency};
  my $amount = $qr_obj->{payment_amount_information}->{amount}

  # set creditor name and address from qr data
  my $creditor_name = $qr_obj->{creditor}->{name};
  my $creditor_street_name = $qr_obj->get_creditor_street_name;
  my $creditor_building_number = $qr_obj->get_creditor_building_number;
  my $creditor_postal_code = $qr_obj->get_creditor_post_code;
  my $creditor_town_name = $qr_obj->get_creditor_town_name;
  my $creditor_country = $qr_obj->{creditor}->{country}

  # set creditor iban
  my $creditor_iban = $qr_obj->{creditor_information}->{iban};

=head1 DESCRIPTION

This is simple helper to parse swiss qr bill data from a string into an object.

Some methods are provided to easily retrieve the creditor address data.

=head1 FUNCTIONS

=over 4

=item C<new>

  my $qr_obj = SL::Helper::QrBillParser->new($item->{qrbill_data});

Creates a new object from the qr bill data string.

=item C<is_valid>

  my $valid = $qr_obj->is_valid;

Returns true if the qr bill data is valid.

=item C<error>

  my $error_message = $qr_obj->error;

Returns the error message if the qr bill data is invalid.

=item C<raw_data>

  my $qrtext = $qr_obj->raw_data;

Returns the raw qr bill data string.

=item C<get_creditor_street_name>

  my $creditor_street_name = $qr_obj->get_creditor_street_name;

Returns the creditor street name.

=item C<get_creditor_building_number>

  my $creditor_building_number = $qr_obj->get_creditor_building_number;

Returns the creditor building number.

=item C<get_creditor_post_code>

  my $creditor_postal_code = $qr_obj->get_creditor_post_code;

Returns the creditor postal code.

=item C<get_creditor_town_name>

  my $creditor_town_name = $qr_obj->get_creditor_town_name;

Returns the creditor town name.

=back

=head1 TESTS

Tests for functions see t/helper/qrbill_parser.t.

Run: C<t/test.pl t/helper/qrbill_parser.t>

=head1 LIMITATIONS

Basic validation is performed based on the status code and regular expressions.
However complete checks of dependent fields would require more elaborate logic.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Cem Aydin E<lt>cem.aydin@revamp-it.chE<gt>
Steven Schubiger E<lt>stsc@refcnt.orgE<gt>

=cut
