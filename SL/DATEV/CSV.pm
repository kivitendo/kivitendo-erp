package SL::DATEV::CSV;

use strict;
use Carp;
use DateTime;
use Encode qw(encode);
use Scalar::Util qw(looks_like_number);

use SL::DB::Datev;
use SL::DB::Chart;
use SL::Helper::DateTime;
use SL::Locale::String qw(t8);
use SL::Util qw(trim);
use SL::VATIDNr;

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(datev_lines from to locked warnings) ],
);

my @kivitendo_to_datev = (
                            {
                              kivi_datev_name => 'umsatz',
                              csv_header_name => t8('Transaction Value'),
                              max_length      => 13,
                              type            => 'Value',
                              required        => 1,
                              input_check     => sub { my ($input) = @_; return (looks_like_number($input) && length($input) <= 13 && $input > 0) },
                              formatter       => \&_format_amount,
                              valid_check     => sub { my ($check) = @_; return ($check =~ m/^\d{1,10}(\,\d{1,2})?$/) },
                            },
                            {
                              kivi_datev_name => 'soll_haben_kennzeichen',
                              csv_header_name => t8('Debit/Credit Label'),
                              max_length      => 1,
                              type            => 'Text',
                              required        => 1,
                              default         => 'S',
                              input_check     => sub { my ($check) = @_; return ($check =~ m/^(S|H)$/) },
                              formatter       => sub { my ($input) = @_; return $input eq 'H' ? 'H' : 'S' },
                              valid_check     => sub { my ($check) = @_; return ($check =~ m/^(S|H)$/) },
                            },
                            {
                              kivi_datev_name => 'waehrung',
                              csv_header_name => t8('Transaction Value Currency Code'),
                              max_length      => 3,
                              type            => 'Text',
                              default         => '',
                              input_check     => sub { my ($check) = @_; return ($check eq '' || $check =~ m/^[A-Z]{3}$/) },
                              valid_check     => sub { my ($check) = @_; return ($check =~ m/^[A-Z]{3}$/) },
                            },
                            {
                              kivi_datev_name => 'wechselkurs',
                              csv_header_name => t8('Exchange Rate'),
                              max_length      => 11,
                              type            => 'Number',
                              default         => '',
                              valid_check     => sub { my ($check) = @_; return ($check =~ m/^[0-9]*\.?[0-9]*$/) },
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
                              max_length      => 9,
                              type            => 'Account',
                              required        => 1,
                              input_check     => sub { my ($check) = @_; return ($check =~ m/^[0-9]{4,9}$/) },
                            },
                            {
                              kivi_datev_name => 'gegenkonto',
                              csv_header_name => t8('Contra Account'),
                              max_length      => 9,
                              type            => 'Account',
                              required        => 1,
                              input_check     => sub { my ($check) = @_; return ($check =~ m/^[0-9]{4,9}$/) },
                            },
                            {
                              kivi_datev_name => 'buchungsschluessel',
                              csv_header_name => t8('Posting Key'),
                              max_length      => 2,
                              type            => 'Text',
                              default         => '',
                              input_check     => sub { my ($check) = @_; return ($check =~ m/^[0-9]{0,2}$/) },
                            },
                            {
                              kivi_datev_name => 'datum',
                              csv_header_name => t8('Invoice Date'),
                              max_length      => 4,
                              type            => 'Date',
                              required        => 1,
                              input_check     => sub { my ($check) = @_; return (ref (DateTime->from_kivitendo($check)) eq 'DateTime') },
                              formatter       => sub { my ($input) = @_; return DateTime->from_kivitendo($input)->strftime('%d%m') },
                              valid_check     => sub { my ($check) = @_; return ($check =~ m/^[0-9]{4}$/) },
                            },
                            {
                              kivi_datev_name => 'belegfeld1',
                              csv_header_name => t8('Invoice Field 1'),
                              max_length      => 12,
                              type            => 'Text',
                              default         => '',
                              input_check     => sub { return 1 unless $::instance_conf->get_datev_export_format eq 'cp1252';
                                                       my ($text) = @_; check_encoding($text); },
                              valid_check     => sub { return 1 if     $::instance_conf->get_datev_export_format eq 'cp1252';
                                                       my ($text) = @_; check_encoding($text); },
                              formatter       => sub { my ($input) = @_; return substr($input, 0, 12) },
                            },
                            {
                              kivi_datev_name => 'belegfeld2',
                              csv_header_name => t8('Invoice Field 2'),
                              max_length      => 12,
                              type            => 'Text',
                              default         => '',
                              input_check     => sub { my ($check) = @_; return 1 unless $check; return (ref (DateTime->from_kivitendo($check)) eq 'DateTime') },
                              formatter       => sub { my ($input) = @_; return '' unless $input; return trim(DateTime->from_kivitendo($input)->strftime('%e%m%y')) },
                              valid_check     => sub { my ($check) = @_; return 1 unless $check; return ($check =~ m/^[0-9]{5,6}$/) },
                            },
                            {
                              kivi_datev_name => 'not yet implemented',
                              csv_header_name => t8('Discount'),
                              type            => 'Value',
                            },
                            {
                              kivi_datev_name => 'buchungstext',
                              csv_header_name => t8('Posting Text'),
                              max_length      => 60,
                              type            => 'Text',
                              default         => '',
                              input_check     => sub { return 1 unless $::instance_conf->get_datev_export_format eq 'cp1252';
                                                       my ($text) = @_; check_encoding($text); },
                              valid_check     => sub { return 1 if     $::instance_conf->get_datev_export_format eq 'cp1252';
                                                       my ($text) = @_; check_encoding($text); },
                              formatter       => sub { my ($input) = @_; return substr($input, 0, 60) },
                            },  # pos 14
                            {
                              kivi_datev_name => 'customernumber',
                              csv_header_name => 'Kundennummer',
                              max_length      => 50,
                              type            => 'Text',
                              default         => '',
                              input_check     => sub { return 1 unless $::instance_conf->get_datev_export_format eq 'cp1252';
                                                       my ($text) = @_; check_encoding($text); },
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
                              kivi_datev_name => 'document_guid',
                              csv_header_name => t8('Link to invoice'),
                              max_length      => 210, # DMS Application shortcut and GUID
                                                      # Example: "BEDI"
                                                      # "8DB85C02-4CC3-FF3E-06D7-7F87EEECCF3A".
                              type            => 'Text',
                              default         => '',
                              input_check     => sub { my ($check) = @_; return 1 unless $check;
                                                       my @guids = split(/,/,$check);
                                                       foreach my $guid (@guids) {
                                                         return unless ($guid =~ m/^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$/);
                                                       }
                                                       return 1; },
                              formatter       => sub { my ($input) = @_; return '' unless $input;
                                                       my @guids = split (/,/,$input);
                                                       my $first = shift @guids;
                                                       my $bedi = 'BEDI "' . $first . '"';
                                                       foreach my $guid (@guids) {
                                                         $bedi .= ',"' . $guid . '"';
                                                       }
                                                       return $bedi; },

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
                              default         => '',
                              input_check     => sub { my ($text) = @_; return 1 unless $text; check_encoding($text);  },
                              formatter       => sub { my ($input) = @_; return substr($input, 0, 8) },
                            }, # pos 37
                            {
                              kivi_datev_name => 'kost2',
                              csv_header_name => t8('Cost Center'),
                              max_length      => 8,
                              type            => 'Text',
                              default         => '',
                              input_check     => sub { my ($text) = @_; return 1 unless $text; check_encoding($text);  },
                              formatter       => sub { my ($input) = @_; return substr($input, 0, 8) },
                            }, # pos 38
                            {
                              kivi_datev_name => 'not yet implemented',
                              csv_header_name => t8('KOST Quantity'),
                              max_length      => 9,
                              type            => 'Number',
                              valid_check     => sub { my ($check) = @_; return ($check =~ m/^[0-9]{0,9}$/) },
                            }, # pos 39
                            {
                              kivi_datev_name => 'ustid',
                              csv_header_name => t8('EU Member State and VAT ID Number'),
                              max_length      => 15,
                              type            => 'Text',
                              default         => '',
                              input_check     => sub {
                                                       my ($ustid) = @_;
                                                       return 1 if ('' eq $ustid);
                                                       return SL::VATIDNr->validate($ustid);
                                                     },
                              formatter       => sub { my ($input) = @_; $input =~ s/\s//g; return $input },
                              valid_check     => sub {
                                                       my ($ustid) = @_;
                                                       return 1 if ('' eq $ustid);
                                                       return SL::VATIDNr->validate($ustid);
                                                     },
                            }, # pos 40
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
                            },  # pos 50
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
                            },  # pos 60
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
                            },  # pos 70
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
                            },  # pos 80
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
                            },  # pos 90
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
                            },  # pos 100
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
                            },  # pos 110
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
                              kivi_datev_name => 'locked',
                              csv_header_name => t8('Lock'),
                              max_length      => 1,
                              type            => 'Number',
                              default         => 1,
                              valid_check     => sub { my ($check) = @_; return ($check =~ m/^(0|1)$/) },
                            },  # pos 114
                            {
                              kivi_datev_name => 'leistungsdatum',
                              csv_header_name => t8('Payment Date'),
                              max_length      => 8,
                              type            => 'Date',
                              default         => '',
                              input_check     => sub { my ($check) = @_; return  1 if ('' eq $check); return (ref (DateTime->from_kivitendo($check)) eq 'DateTime') },
                              formatter       => sub { my ($input) = @_; return '' if ('' eq $input); return DateTime->from_kivitendo($input)->strftime('%d%m%Y') },
                              valid_check     => sub { my ($check) = @_; return  1 if ('' eq $check); return ($check =~ m/^[0-9]{8}$/) },
                            },  # pos 115
                            {
                              kivi_datev_name => 'not yet implemented',
                            },
                            # DATEV Prüfprogramm says: Only 116 fields are allowed
                            #{
                            #  kivi_datev_name => 'not yet implemented',
                            #},
                            #{
                            #  kivi_datev_name => 'not yet implemented',
                            #},
                            #{
                            #  kivi_datev_name => 'not yet implemented',
                            #},
                            #{
                            #  kivi_datev_name => 'not yet implemented',
                            #},  # pos 120
  );

sub new {
  my $class = shift;
  my %data  = @_;

  croak(t8('We need a valid from date'))      unless (ref $data{from} eq 'DateTime');
  croak(t8('We need a valid to date'))        unless (ref $data{to}   eq 'DateTime');
  croak(t8('We need a array of datev_lines')) unless (ref $data{datev_lines} eq 'ARRAY');

  my $obj = bless {}, $class;
  $obj->$_($data{$_}) for keys %data;
  $obj;
}

sub check_encoding {
  my ($test) = @_;
  return undef unless $test;
  if (eval {
    encode('Windows-1252', $test, Encode::FB_CROAK|Encode::LEAVE_SRC);
    1
  }) {
    return 1;
  }
}

sub header {
  my ($self) = @_;

  my @header;

  # we can safely set these defaults
  # TODO get length_of_accounts from DATEV.pm
  my $today              = DateTime->now_local;
  my $created_on         = $today->ymd('') . $today->hms('') . '000';
  my $length_of_accounts = length(SL::DB::Manager::Chart->get_first(where => [charttype => 'A'])->accno) // 4;
  my $default_curr       = SL::DB::Default->get_default_currency;

  # datev metadata and the string length limits
  my %meta_datev;
  my %meta_datev_to_valid_length = (
    beraternr   =>  7,
    beratername => 25,
    mandantennr =>  5,
  );

  my $datev = SL::DB::Manager::Datev->get_first();

  while (my ($k, $v) = each %meta_datev_to_valid_length) {
    next unless $datev->{$k};
    $meta_datev{$k} = substr $datev->{$k}, 0, $v;
  }
  my $coa = $::instance_conf->get_coa eq 'Germany-DATEV-SKR03EU' ? '03'
          : $::instance_conf->get_coa eq 'Germany-DATEV-SKR04EU' ? '04'
          : '';

  my @header_row_1 = (
    "EXTF", "510", 21, "Buchungsstapel", 7, $created_on, "", "ki",
    "kivitendo-datev", "", $meta_datev{beraternr}, $meta_datev{mandantennr},
    $self->first_day_of_fiscal_year->ymd(''), $length_of_accounts,
    $self->from->ymd(''), $self->to->ymd(''), "", "", 1, "", $self->locked,
    $default_curr, "", "", "","", $coa, "", "", "", ""
  );
  push @header, [ @header_row_1 ];

  # second header row, just the column names
  push @header, [ map { $_->{csv_header_name} } @kivitendo_to_datev ];

  return \@header;
}

sub lines {
  my ($self) = @_;

  my (@array_of_datev, @warnings);

  foreach my $row (@{ $self->datev_lines }) {
    my @current_datev_row;

    # 1. check all datev_lines and see if we have a defined value
    # 2. if we don't have a defined value set a default if exists
    # 3. otherwise die
    foreach my $column (@kivitendo_to_datev) {
      if ($column->{kivi_datev_name} eq 'not yet implemented') {
        push @current_datev_row, '';
        next;
      }
      my $data = $row->{$column->{kivi_datev_name}};
      if (!defined $data) {
        if (defined $column->{default}) {
          $data = $column->{default};
        } else {
          die 'No sensible value or a sensible default found for the entry: ' . $column->{kivi_datev_name};
        }
      }
      # checkpoint a: no undefined data. All strict checks now!
      if (exists $column->{input_check} && !$column->{input_check}->($data)) {
        die t8("Wrong field value '#1' for field '#2' for the transaction with amount '#3'",
                $data, $column->{kivi_datev_name}, $row->{umsatz});
      }
      # checkpoint b: we can safely format the input
      if ($column->{formatter}) {
        $data = $column->{formatter}->($data);
      }
      # checkpoint c: all soft checks now, will pop up as a user warning
      if (exists $column->{valid_check} && !$column->{valid_check}->($data)) {
        push @warnings, t8("Wrong field value '#1' for field '#2' for the transaction" .
                           " with amount '#3'", $data, $column->{kivi_datev_name}, $row->{umsatz});
      }
      push @current_datev_row, $data;
    }
    push @array_of_datev, \@current_datev_row;
  }
  $self->warnings(\@warnings);
  return \@array_of_datev;
}

# helper

sub _format_amount {
  $::form->format_amount({ numberformat => '1000,00' }, @_);
}

sub first_day_of_fiscal_year {
  $_[0]->to->clone->truncate(to => 'year');
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::DATEV::CSV - kivitendo DATEV CSV Specification

=head1 SYNOPSIS

  use SL::DATEV qw(:CONSTANTS);
  use SL::DATEV::CSV;

  my $startdate = DateTime->new(year => 2014, month => 9, day => 1);
  my $enddate   = DateTime->new(year => 2014, month => 9, day => 31);
  my $datev = SL::DATEV->new(
    exporttype => DATEV_ET_BUCHUNGEN,
    format     => DATEV_FORMAT_CSV,
    from       => $startdate,
    to         => $enddate,
  );
  $datev->generate_datev_data;

  my $datev_csv = SL::DATEV::CSV->new(datev_lines  => $datev->generate_datev_lines,
                                      from         => $datev->from,
                                      to           => $datev->to,
                                      locked       => $datev->locked,
                                     );
  $datev_csv->header;   # returns the required 2 rows of header ($aref = [ ["row1" ..], [ "row2" .. ] ]) as array of array
  $datev_csv->lines;    # returns an array_ref of rows of array_refs soll uns die ein Arrayref von Zeilen zurückgeben, die jeweils Arrayrefs sind
  $datev_csv->warnings; # returns warnings


  # The above object methods can be directly chained to a CSV export function, like this:
  my $csv_file = IO::File->new($somewhere_in_filesystem)') or die "Can't open: $!";
  $csv->print($csv_file, $_) for @{ $datev_csv->header };
  $csv->print($csv_file, $_) for @{ $datev_csv->lines  };
  $csv_file->close;
  $self->{warnings} = $datev_csv->warnings;




=head1 DESCRIPTION

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

=item new PARAMS

Constructor for CSV-DATEV export.
Checks mandantory params as described in section synopsis.

=item check_encoding

Helper function, returns true if a string is not empty and cp1252 encoded
For example some arabic utf-8 like  ݐ  will return false

=item header

Mostly all other header information are constants or metadata loaded
from SL::DB::Datev.pm.

Returns the first two entries for the header (see above: File Structure)
as an array.

=item kivitendo_to_datev

Returns the data structure C<@datev_data> as an array

=item _format_amount

Lightweight wrapper for form->format_amount.
Expects a number in kivitendo database format and returns the same number
in DATEV format.

=item first_day_of_fiscal_year

Takes a look at $self->to to  determine the first day of the fiscal year.

=item lines

Generates the CSV-Format data for the CSV DATEV export and returns
an 2-dimensional array as an array_ref.
May additionally return a second array_ref with warnings.

Requires the same date fields as the constructor for a valid DATEV header.

Furthermore we assume that the first day of the fiscal year is
the first of January and we cannot guarantee that our data in kivitendo
is locked, that means a booking cannot be modified after a defined (vat tax)
period.
Some validity checks (max_length and regex) will be done if the
data structure contains them and the field is defined.

To add or alter the structure of the data take a look at the C<@kivitendo_to_datev> structure.

=back

=head1 TODO CAVEAT

One can circumevent the check of the warnings.quite easily,
becaus warnings are generated after the call to lines:

  # WRONG usage
  die if @{ $datev_csv->warnings };
  somethin_with($datev_csv->lines);

  # safe usage
  my $lines = $datev_csv->lines;
  die if @{ $datev_csv->warnings };
  somethin_with($lines);
