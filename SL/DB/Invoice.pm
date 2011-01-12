# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Invoice;

use strict;

use List::Util qw(first);

use SL::DB::MetaSetup::Invoice;
use SL::DB::Manager::Invoice;

__PACKAGE__->meta->add_relationship(
  invoiceitems => {
    type         => 'one to many',
    class        => 'SL::DB::InvoiceItem',
    column_map   => { id => 'trans_id' },
    manager_args => {
      with_objects => [ 'part' ]
    }
  },
);

__PACKAGE__->meta->initialize;

# methods

sub items { goto &invoiceitems; }

# it is assumed, that ordnumbers are unique here.
sub first_order_by_ordnumber {
  my $self = shift;

  my $orders = SL::DB::Manager::Order->get_all(
    query => [
      ordnumber => $self->ordnumber,

    ],
  );

  return first { $_->is_type('sales_order') } @{ $orders };
}

sub abschlag_percentage {
  my $self         = shift;
  my $order        = $self->first_order_by_ordnumber or return;
  my $order_amount = $order->netamount               or return;
  return $self->abschlag
    ? $self->netamount / $order_amount
    : undef;
}

sub taxamount {
  my $self = shift;
  die 'not a setter method' if @_;

  return $self->amount - $self->netamount;
}

__PACKAGE__->meta->make_attr_helpers(taxamount => 'numeric(15,5)');

1;
