# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Inventory;

use strict;
use Carp;
use DateTime;

use SL::DBUtils qw(selectrow_query);
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

sub new_from {
  my ($class, $obj) = @_;

  if ('SL::DB::DeliveryOrderItemsStock' eq ref $obj) {
    return $class->new_from_delivery_order_stock($obj);
  }

  croak "unknown obj type (@{[ ref $obj ]}) for SL::DB::Inventory::new_from";
}

sub new_from_delivery_order_stock {
  my ($class, $stock) = @_;

  my $project = $stock->delivery_order_item->effective_project;

  return $class->new(
    delivery_order_items_stock_id => $stock->id,
    parts_id                      => $stock->delivery_order_item->parts_id,
    qty                           => $stock->unit_obj->convert_to($stock->qty => $stock->delivery_order_item->part->unit_obj),
    warehouse_id                  => $stock->warehouse_id,
    bin_id                        => $stock->bin_id,
    chargenumber                  => $stock->chargenumber,
    bestbefore                    => $stock->bestbefore,
    project_id                    => $project ? $project->id : undef,
    # trans_type - not set here, set in controller
  );
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

  return 1 if $self->employee_id;

  $self->employee(SL::DB::Manager::Employee->current);

  return 1;
}
1;
