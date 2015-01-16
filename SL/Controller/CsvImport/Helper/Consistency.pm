package SL::Controller::CsvImport::Helper::Consistency;

use strict;

use SL::DB::Default;
use SL::DB::Currency;
use SL::DB::TaxZone;

use SL::Helper::Csv::Error;

use parent qw(Exporter);
our @EXPORT = qw(check_currency check_taxzone);

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

    # register currency_id for method copying later
    $self->clone_methods->{currency_id} = 1;
  }

  # Set default currency if none was given and take_default is true.
  $object->currency_id(_default_currency_id($self)) if !$object->currency_id and $params{take_default};

  $entry->{raw_data}->{currency_id} = $object->currency_id;

  return 1;
}

sub check_taxzone {
  my ($self, $entry, %params) = @_;

  my $object = $entry->{object};

  # Check whether the CSV contains the parameters taxzone_id or taxzone, and
  # check them for validity. 
  # If one of them was given, but is invalid, return an error

  # If neither was given:
  # a) if param take_default was set, use the taxzone_id from the profile
  #    (customer/vendor import)
  # b) if param take_default was not set, do nothing, return without error, and
  #    taxzone_id may be set later by other means (order import uses cv settings)

 
  # if $object->taxzone_id is defined (from CSV line), check if it is valid
  if ($object->taxzone_id && ! _taxzones_by($self)->{id}->{ $object->taxzone_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid tax zone');
    return 0;
  }

  # if there was no taxzone_id in CSV, but a taxzone entry, check if it is a
  # valid taxzone and set the id
  if (!$object->taxzone_id && $entry->{raw_data}->{taxzone}) {
    my $taxzone = _taxzones_by($self)->{description}->{ $entry->{raw_data}->{taxzone} };
    if (!$taxzone) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid tax zone');
      return 0;
    }

    $object->taxzone_id($taxzone->id);
  }

  # The take_default option should only be used for the customer/vendor case,
  # as the default for imported orders is the taxzone according to the customer
  # or vendor
  # if neither taxzone_id nor taxzone were defined, use the default taxzone as
  # defined from the import settings (a default/fallback taxzone that is to be
  # used will always be selected)

  if (!$object->taxzone_id && $params{take_default}) {
    # my $default_id = $self->settings->{'default_taxzone'};
    my $default_id = $self->controller->profile->get('default_taxzone');
    $object->taxzone_id($default_id);
    # check if default taxzone_id is valid just to be sure
    if (! _taxzones_by($self)->{id}->{ $object->taxzone_id }) {
      push @{ $entry->{errors} }, $::locale->text('Error with default taxzone');
      return 0;
    };
  };

  # for the order import at this stage $object->taxzone_id may still not be
  # defined, in this case the customer/vendor taxzone will be used. 

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

sub _taxzones_by {
  my ($self) = @_;

  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ _all_taxzones($self) } } ) } qw(id description) };
}

sub _all_taxzones {
  my ($self) = @_;

  return SL::DB::Manager::TaxZone->get_all_sorted(query => [ obsolete => 0 ]);
}

1;
