# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::PartsGroup;

use strict;

use SL::DB::MetaSetup::PartsGroup;
use SL::DB::Manager::PartsGroup;
use SL::DB::Helper::ActsAsList;

__PACKAGE__->meta->add_relationship(
  custom_variable_configs => {
    type                  => 'many to many',
    map_class             => 'SL::DB::CustomVariableConfigPartsgroup',
  },
  parts          => {
    type         => 'one to many',
    class        => 'SL::DB::Part',
    column_map   => { id => 'partsgroup_id' },
  },
);

__PACKAGE__->meta->initialize;

sub displayable_name {
  my $self = shift;

  return join ' ', grep $_, $self->id, $self->partsgroup;
}

sub validate {
  my ($self) = @_;
  require SL::DB::Customer;

  my @errors;

  push @errors, $::locale->text('The description is missing.') if $self->id and !$self->partsgroup;

  return @errors;
}

sub orphaned {
  my ($self) = @_;
  die 'not an accessor' if @_ > 1;

  return 1 unless $self->id;

  my @relations = qw(
    SL::DB::Part
    SL::DB::CustomVariableConfigPartsgroup
  );

  for my $class (@relations) {
    eval "require $class";
    return 0 if $class->_get_manager_class->get_all_count(query => [ partsgroup_id => $self->id ]);
  }

  return 1;
}

1;
