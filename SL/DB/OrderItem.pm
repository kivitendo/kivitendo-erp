package SL::DB::OrderItem;

use strict;

use SL::DB::MetaSetup::OrderItem;

__PACKAGE__->meta->add_relationship(
  part => {
    type         => 'one to one',
    class        => 'SL::DB::Part',
    column_map   => { parts_id => 'id' },
  },
  price_factor_obj => {
    type           => 'one to one',
    class          => 'SL::DB::PriceFactor',
    column_map     => { price_factor_id => 'id' },
  },
  unit_obj       => {
    type         => 'one to one',
    class        => 'SL::DB::Unit',
    column_map   => { unit => 'name' },
  },
);

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

__PACKAGE__->meta->initialize;

sub is_price_update_available {
  my $self = shift;
  return $self->origprice > $self->part->sellprice;
}

1;
