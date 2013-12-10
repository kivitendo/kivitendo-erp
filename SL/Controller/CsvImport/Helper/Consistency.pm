package SL::Controller::CsvImport::Helper::Consistency;

use strict;

use SL::DB::Default;
use SL::DB::Currency;

use SL::Helper::Csv::Error;

use parent qw(Exporter);
our @EXPORT = qw(check_currency);

#
# public functions
#

sub check_currency {
  my ($self, $entry, %params) = @_;

  my $object = $entry->{object};

  # Check whether or not currency ID is valid.
  if ($object->currency_id && ! _currencies_by($self)->{id}->{ $object->currency_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid currency');
    return 0;
  }

  # Map name to ID if given.
  if (!$object->currency_id && $entry->{raw_data}->{currency}) {
    my $currency = _currencies_by($self)->{name}->{  $entry->{raw_data}->{currency} };
    if (!$currency) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid currency');
      return 0;
    }

    $object->currency_id($currency->id);
  }

  # Set default currency if none was given and take_default is true.
  $object->currency_id(_default_currency_id($self)) if !$object->currency_id and $params{take_default};

  $entry->{raw_data}->{currency_id} = $object->currency_id;

  return 1;
}

#
# private functions
#

sub _currencies_by {
  my ($self) = @_;

  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ _all_currencies($self) } } ) } qw(id name) };
}

sub _all_currencies {
  my ($self) = @_;

  return SL::DB::Manager::Currency->get_all;
}

sub _default_currency_id {
  my ($self) = @_;

  return SL::DB::Default->get->currency_id;
}

1;
