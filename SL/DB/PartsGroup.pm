# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::PartsGroup;

use strict;

use SL::DB::MetaSetup::PartsGroup;
use SL::DB::Manager::PartsGroup;

__PACKAGE__->meta->add_relationship(
  custom_variable_configs => {
    type                  => 'many to many',
    map_class             => 'SL::DB::CustomVariableConfigPartsgroup',
  },
);

__PACKAGE__->meta->initialize;

sub displayable_name {
  my $self = shift;

  return join ' ', grep $_, $self->id, $self->partsgroup;
}

1;
