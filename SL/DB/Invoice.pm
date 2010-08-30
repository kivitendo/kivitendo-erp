# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Invoice;

use strict;

use List::Util qw(first);

use SL::DB::MetaSetup::Invoice;
use SL::DB::Manager::Invoice;

__PACKAGE__->attr_number($_, places => -2) for qw(amount netamount paid  marge_total marge_percent taxamount);
__PACKAGE__->attr_date($_) for qw(transdate gldate datepaid duedate deliverydate orddate quodate);
__PACKAGE__->attr_percent($_) for qw(abschlag_percentage);

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

1;
