# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::VariantProperty;

use strict;

use SL::DB::MetaSetup::VariantProperty;
use SL::DB::Manager::VariantProperty;
use SL::DB::Helper::ActsAsList;
use SL::DB::Helper::TranslatedAttributes;
use SL::DB::Helper::AttrSorted;

__PACKAGE__->meta->add_relationships(
  parent_variants => {
    map_class => 'SL::DB::VariantPropertyPart',
    map_from  => 'variant_property',
    map_to    => 'part',
    type      => 'many to many',
  },
  property_values => {
    class => 'SL::DB::VariantPropertyValue',
    column_map => { id => 'variant_property_id' },
    type => 'one to many',
  }
);

__PACKAGE__->attr_sorted({ unsorted => 'property_values', position => 'sortkey'});

__PACKAGE__->meta->initialize;

sub validate {
  my ($self) = @_;

  my @errors;
  # critical checks
  push @errors, $::locale->text('The name is missing.') unless $self->{name};
  push @errors, $::locale->text('The unique name is missing.')        unless $self->{unique_name};
  push @errors, $::locale->text('The abbreviation is missing')    unless $self->{abbreviation};
  return @errors;
}

sub name_translated {goto &name} # TODO

sub displayable_name {
  my ($self) = @_;
  return $self->name . "(" . $self->abbreviation . ")";
}

1;
