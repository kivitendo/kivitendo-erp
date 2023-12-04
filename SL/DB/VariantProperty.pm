# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::VariantProperty;

use strict;

use SL::DB::MetaSetup::VariantProperty;
use SL::DB::Manager::VariantProperty;

__PACKAGE__->meta->add_relationships(
  parent_variants => {
    map_class => 'SL::DB::VariantPropertyPart',
    map_from  => 'variant_property',
    map_to    => 'part',
    type      => 'many to many',
  },
);

__PACKAGE__->meta->initialize;

1;
