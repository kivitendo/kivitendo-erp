# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Country;

use strict;

use Carp;

use SL::DB::MetaSetup::Country;
use SL::DB::Manager::Country;
use SL::DB::Helper::ActsAsList (column_name => 'sortorder');


__PACKAGE__->meta->initialize;
__PACKAGE__->before_delete('can_be_deleted');

sub can_be_deleted {
  return 0;
}

sub description_localized {
  my $self = shift;
  my $language_code = shift;

  croak "Method is not a setter" if @_;

  my $column = $self->description_column_localized($language_code);

  return $self->$column();
}

sub description_column_localized {
  my ($class, $language_code) = @_;

  $language_code //= '';

  return 'description_' .
    ($language_code =~ m/^de$/i ? 'de' :
     $language_code =~ m/^en$/i ? 'en' : 'de');
}

sub is_eu_country {
  my $self = shift;

  my @eu_country_iso2 = qw(BE BG DE DK EE FI FR GR IE IT HR LV LT LU MT NL AT PL PT RO SE SK SI ES CZ HU CY);
  return 1 if grep $_ eq $self->iso2, @eu_country_iso2;
  return 0
}

sub get_taxzone {
  my $self = shift;
  require SL::DB::TaxZone;

  return SL::DB::Manager::TaxZone->find_by( description => 'Inland' ) if $self->iso2 eq 'DE';
  return SL::DB::Manager::TaxZone->find_by( description => { like => "EU ohne USt-ID Nummer " . $self->iso2 } ) if $self->is_eu_country;
  return SL::DB::Manager::TaxZone->find_by( description => 'Nicht EU' );
}

1;
