# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Inventory;

use strict;

use SL::DB::MetaSetup::Inventory;
use SL::DB::Manager::Inventory;

__PACKAGE__->meta->initialize;

__PACKAGE__->before_save(\&_before_save_create_trans_id);
__PACKAGE__->before_save(\&_before_save_set_shippingdate);
__PACKAGE__->before_save(\&_before_save_set_employee);

# part accessor is badly named
sub part {
  goto &parts;
}

sub _before_save_create_trans_id {
  my ($self, %params) = @_;

  return 1 if $self->trans_id;

  my ($trans_id) = selectrow_query($::form, SL::DB->client->dbh, qq|SELECT nextval('id')|);

  $self->trans_id($trans_id);

  return 1;
}

sub _before_save_set_shippingdate {
  my ($self, %params) = @_;

  return 1 if $self->shippingdate;

  $self->shippingdate(DateTime->now);

  return 1;
}

sub _before_save_set_employee {
  my ($self, %params) = @_;

  return 1 if $self->emplyee_id;

  $self->employee(SL::DB::Manager::Employee->current);

  return 1;
}
1;
