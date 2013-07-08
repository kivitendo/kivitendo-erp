# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::CustomVariable;

use strict;
use SL::DB::MetaSetup::CustomVariable;

__PACKAGE__->meta->initialize;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

sub value {
  my $self = $_[0];
  my $type = $self->config->type;

  goto &bool_value      if $type eq 'boolean';
  goto &timestamp_value if $type eq 'timestamp';
  goto &number_value    if $type eq 'number';
  if ( $type eq 'customer' ) {
    if ( defined($_[1]) && $_[1] ) {
      goto &number_value;
    }
    else {
      require SL::DB::Customer;

      my $id = int($self->number_value);
      return $id ? SL::DB::Customer->new(id => $id)->load() : 0;
    }
  }
  goto &text_value; # text and select
}

sub is_valid {
  my ($self) = @_;

  require SL::DB::CustomVariableValidity;

  my $query = [config_id => $self->config_id, trans_id => $self->trans_id];
  return SL::DB::Manager::CustomVariableValidity->get_all_count(query => $query) == 0;
}

1;
