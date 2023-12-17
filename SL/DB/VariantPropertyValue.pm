# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::VariantPropertyValue;

use strict;

use SL::DB::MetaSetup::VariantPropertyValue;
use SL::DB::Manager::VariantPropertyValue;

__PACKAGE__->meta->add_relationships(
  parent_variants => {
    map_class => 'SL::DB::VariantPropertyValuePart',
    map_from  => 'variant_property_value',
    map_to    => 'part',
    type      => 'many to many',
  },
);

__PACKAGE__->meta->initialize;

sub value_translated {goto &value} # TODO

sub displayable_name {
  my ($self) = @_;
  return $self->value . "(" . $self->abbreviation . ")";
}

1;
