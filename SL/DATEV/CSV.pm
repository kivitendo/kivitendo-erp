package SL::DATEV::CSV;

use strict;

use SL::Locale::String qw(t8);
use SL::DB::Datev;

use Carp;
use DateTime;


my @kivitendo_to_datev = (
                            {
                              kivi_datev_name => 'umsatz',
                              csv_header_name => t8('Transaction Value'),
                              max_length      => 13,
                              type            => 'Value',
                              valid_check     => sub { return (shift =~ m/^\d{1,10}(\,\d{1,2})?$/) },
                            },
                            {
                              kivi_datev_name => 'soll_haben_kennzeichen',
                              csv_header_name => t8('Debit/Credit Label'),
                              max_length      => 1,
                              type            => 'Text',
                              valid_check     => sub { return (shift =~ m/^(S|H)$/) },
                            },
                            {
                              kivi_datev_name => 'waehrung',
                              csv_header_name => t8('Transaction Value Currency Code'),
                              max_length      => 3,
                              type            => 'Text',
                              valid_check     => sub { return (shift =~ m/^[A-Z]{3}$/) },
                            },
                            {
                              kivi_datev_name => 'wechselkurs',
                              csv_header_name => t8('Exchange Rate'),
                              max_length      => 11,
                              type            => 'Number',
                              valid_check     => sub { return (shift =~ m/^[0-9]*\.?[0-9]*$/) },
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                              csv_header_name => t8('Base Transaction Value'),
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                              csv_header_name => t8('Base Transaction Value Currency Code'),
                            },
                            {
                              kivi_datev_name => 'konto',
                              csv_header_name => t8('Account'),
                              max_length      => 9, # May contain a maximum of 8 or 9 digits -> perldoc
                              type            => 'Account',
                              valid_check     => sub { return (shift =~ m/^[0-9]{4,9}$/) },
                            },
                            {
                              kivi_datev_name => 'gegenkonto',
                              csv_header_name => t8('Contra Account'),
                              max_length      => 9, # May contain a maximum of 8 or 9 digits -> perldoc
                              type            => 'Account',
                              valid_check     => sub { return (shift =~ m/^[0-9]{4,9}$/) },
                            },
                            {
                              kivi_datev_name => 'buchungsschluessel',
                              csv_header_name => t8('Posting Key'),
                              max_length      => 2,
                              type            => 'Text',
                              valid_check     => sub { return (shift =~ m/^[0-9]{0,2}$/) },
                            },
                            {
                              kivi_datev_name => 'datum',
                              csv_header_name => t8('Invoice Date'),
                              max_length      => 4,
                              type            => 'Date',
                              valid_check     => sub { return (shift =~ m/^[0-9]{4}$/) },
                            },
                            {
                              kivi_datev_name => 'belegfeld1',
                              csv_header_name => t8('Invoice Field 1'),
                              max_length      => 12,
                              type            => 'Text',
                              valid_check     => sub { my $text = shift; check_encoding($text); },
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                              csv_header_name => t8('Invoice Field 2'),
                             max_length      => 12,
                              type            => 'Text',
                              valid_check     => sub { return (shift =~ m/[ -~]{1,12}/) },
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                              csv_header_name => t8('Discount'),
                              type            => 'Value',
                            },
                            {
                              kivi_datev_name => 'buchungsbes',
                              csv_header_name => t8('Posting Text'),
                              max_length      => 60,
                              type            => 'Text',
                              valid_check     => sub { my $text = shift; return 1 unless $text; check_encoding($text);  },
                            },  # pos 14
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                              csv_header_name => t8('Link to invoice'),
                              max_length      => 210, # DMS Application shortcut and GUID
                                                      # Example: "BEDI"
                                                      # "8DB85C02-4CC3-FF3E-06D7-7F87EEECCF3A".
                            }, # pos 20
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            {
                              kivi_datev_name => 'kost1',
                              csv_header_name => t8('Cost Center'),
                              max_length      => 8,
                              type            => 'Text',
                              valid_check     => sub { my $text = shift; return 1 unless $text; check_encoding($text);  },
                            }, # pos 37
                            {
                              kivi_datev_name => 'kost2',
                              csv_header_name => t8('Cost Center'),
                              max_length      => 8,
                              type            => 'Text',
                              valid_check     => sub { my $text = shift; return 1 unless $text; check_encoding($text);  },
                            }, # pos 38
                            {
                              kivi_datev_name => 'not yet implemented',
                              csv_header_name => t8('KOST Quantity'),
                              max_length      => 9,
                              type            => 'Number',
                              valid_check     => sub { return (shift =~ m/^[0-9]{0,9}$/) },
                            }, # pos 39
                            {
                              kivi_datev_name => 'ustid',
                              csv_header_name => t8('EU Member State and VAT ID Number'),
                              max_length      => 15,
                              type            => 'Text',
                              valid_check     => sub {
                                                       my $ustid = shift;
                                                       return 1 unless defined($ustid);
                                                       return ($ustid =~ m/^CH|^[A-Z]{2}\w{5,13}$/);
                                                     },
                            }, # pos 40
  );

sub check_encoding {
  use Encode qw( decode );
  # counter test: arabic doesnt work: ݐ
  my $test = shift;
  return undef unless $test;
  if (eval {
    decode('Windows-1252', $test, Encode::FB_CROAK|Encode::LEAVE_SRC);
    1
  }) {
    return 1;
  }
}

sub kivitendo_to_datev {
  my $self = shift;

  my $entries = scalar (@kivitendo_to_datev);
  push @kivitendo_to_datev, { kivi_datev_name => 'not yet implemented' } for 1 .. (116 - $entries);
  return @kivitendo_to_datev;
}

sub generate_csv_header {
  my ($self, %params)   = @_;

  # we need from and to in YYYYDDMM
  croak "Wrong format for from" unless $params{from} =~ m/^[0-9]{8}$/;
  croak "Wrong format for to"   unless $params{to} =~ m/^[0-9]{8}$/;

  # who knows if we want locking and when our fiscal year starts
  croak "Wrong state of locking"      unless $params{locked} =~ m/(0|1)/;
  croak "No startdate of fiscal year" unless $params{first_day_of_fiscal_year} =~ m/^[0-9]{8}$/;


  # we can safely set these defaults
  my $today              = DateTime->now(time_zone => "local");
  my $created_on         = $today->ymd('') . $today->hms('') . '000';
  my $length_of_accounts = length(SL::DB::Manager::Chart->get_first(where => [charttype => 'A'])->accno) // 4;
  my $default_curr       = SL::DB::Default->get_default_currency;

  # datev metadata and the string lenght limits
  my %meta_datev;
  my %meta_datev_to_valid_length = (
    beraternr   =>  7,
    beratername => 25,
    mandantennr =>  5,
  );

  my $datev = SL::DB::Manager::Datev->get_first();

  while (my ($k, $v) = each %meta_datev_to_valid_length) {
    $meta_datev{$k} = substr $datev->{$k}, 0, $v;
  }

  my @header = (
    "EXTF", "300", 21, "Buchungsstapel", 7, $created_on, "", "ki",
    "kivitendo-datev", "", $meta_datev{beraternr}, $meta_datev{mandantennr},
    $params{first_day_of_fiscal_year}, $length_of_accounts,
    $params{from}, $params{to}, "", "", 1, "", $params{locked},
    $default_curr, "", "", "",""
  );

  return @header;
}
1;

__END__

=encoding utf-8

=head1 NAME

SL::DATEV::CSV - kivitendo DATEV CSV Specification

=head1 SYNOPSIS

The parsing of the DATEV CSV is index based, therefore the correct
column must be present at the corresponding index, i.e.:
 Index 2
 Field Name   : Debit/Credit Label
 Valid Values : 'S' or 'H'
 Length:      : 1

The columns in C<@kivi_datev> are in the correct order and the
specific attributes are defined as a key value hash list for each entry.

The key names are the english translation according to the DATEV specs
(Leitfaden DATEV englisch).

The two attributes C<max_length> and C<type> are also set as specified
by the DATEV specs.

To link the structure to kivitendo data, each entry has the attribute C<kivi_datev_name>
which is by convention the key name as generated by DATEV->generate_datev_data.
A value of C<'not yet implemented'> indicates that this field has no
corresponding kivitendo data and will be given an empty value by DATEV->csv_buchungsexport.


=head1 SPECIFICATION

This is an excerpt of the DATEV Format 2015 Specification for CSV-Header
and CSV-Data lines.

=head2 FILENAME

The filename is subject to the following restrictions:
1. The filename must begin with the prefix DTVF_ or EXTF_.
2. The filename must end with .csv.

When exporting from or importing into DATEV applications, the filename is
marked with the prefix "DTVF_" (DATEV Format).
The prefix "DTVF_" is reserved for DATEV applications.
If you are using a third-party application to create a file in the DATEV format
that you want to import using batch processing, use the prefix "EXTF_"
(External Format).

=head2 File Structure

The file structure of the text file exported/imported is defined as follows

Line 1: Header (serves to assist in the interpretation of the following data)

Line 2: Headline (headline of the user data)

Line 3 – n: Records (user data)

For an valid example file take a look at doc/DATEV-2015/EXTF_Buchungsstapel.csv


=head2 Detailed Description

Line 1 must contain 11 fields.

Line 2 must contain 26 fields.

Line 3 - n:  must contain 116 fields, a smaller subset is mandatory.

=head1 FUNCTIONS

=over 4

=item check_encoding

Helper function, returns true if a string is not empty and cp1252 encoded

=item generate_csv_header(from => 'YYYYDDMM', to => 'YYYYDDMM', locked => 0,
                          first_day_of_fiscal_year => 'YYYYDDMM')

Mostly all other header information are constants or metadata loaded
from SL::DB::Datev.pm.

Returns the first two entries for the header (see above: File Structure)
as an array.

All params are mandatory:
C<params{from}>,  C<params{to}>
and C<params{first_day_of_fiscal_year}> have to be in YYYYDDMM date string
format.
Furthermore C<params{locked}> needs to be a boolean in number format (0|1).


=item kivitendo_to_datev

Returns the data structure C<@datev_data> as an array

=back
