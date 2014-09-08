# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::PartsGroup;

use strict;

use SL::DB::MetaSetup::PartsGroup;

__PACKAGE__->meta->add_relationship(
  custom_variable_configs => {
    type                  => 'many to many',
    map_class             => 'SL::DB::CustomVariableConfigPartsgroup',
  },
);

__PACKAGE__->meta->initialize;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

sub displayable_name {
  my $self = shift;

  return join ' ', grep $_, $self->id, $self->partsgroup;
}

1;
