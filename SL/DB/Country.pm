# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Country;

use strict;

use Carp;

use SL::DB::MetaSetup::Country;
use SL::DB::Manager::Country;
use SL::DB::Helper::ActsAsList (column_name => 'sortorder');
use SL::DB::CountryLanguage;
use SL::DB::Language;

__PACKAGE__->meta->add_relationship(
  languages => {
    type         => 'one to many',
    class        => 'SL::DB::CountryLanguage',
    column_map   => { id      => 'country_id' },
    #manager_args => { sort_by => 'lower(additional_billing_addresses.name)' },
  },
);
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

sub all_languages {
  my ($self) = @_;
  my $all_languages = SL::DB::Manager::Language->get_all_sorted;

  return [ map {
    SL::DB::Manager::CountryLanguage->get_first(where => [ country_id => $self->id, language_id => $_->id ])
    //
    SL::DB::CountryLanguage->new(country_id => $self->id, language_id => $_->id)
  } @$all_languages
  ];
}

1;
