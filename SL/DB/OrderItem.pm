package SL::DB::OrderItem;

use strict;

use List::Util qw(sum);

use SL::DB::MetaSetup::OrderItem;
use SL::DB::Manager::OrderItem;
use SL::DB::Helper::CustomVariables (
  sub_module  => 'orderitems',
  cvars_alias => 1,
  overloads   => {
    parts_id => {
      class => 'SL::DB::Part',
      module => 'IC',
    }
  },
);

__PACKAGE__->meta->initialize;

sub is_price_update_available {
  my $self = shift;
  return $self->origprice > $self->part->sellprice;
}

sub shipped_qty {
  my ($self) = @_;

  my $d_orders = $self->order->linked_records(direction => 'to', to => 'SL::DB::DeliveryOrder');
  my @doi      = grep { $_->parts_id == $self->parts_id } map { $_->orderitems } @$d_orders;

  require SL::AM;
  return sum(map { AM->convert_unit($_->unit => $self->unit) * $_->qty } @doi);
}

sub delivered_qty {
  my ($self) = @_;

  my $d_orders = $self->order->linked_records(direction => 'to', to => 'SL::DB::DeliveryOrder');

  my @d_orders_delivered = grep { $_->delivered } @$d_orders;

  my @doi_delivered      = grep { $_->parts_id == $self->parts_id } map { $_->orderitems } @d_orders_delivered;

  require SL::AM;
  return sum(map { AM->convert_unit($_->unit => $self->unit) * $_->qty } @doi_delivered);
}

sub value_of_goods {
  my ($self) = @_;

  my $price_factor = $self->price_factor || 1;

  return ($self->qty * $self->sellprice * (1 - $self->discount ) / $price_factor);
}

sub taxincluded {
  my ($self) = @_;

  return SL::DB::Manager::Order->find_by(id => $self->trans_id)->taxincluded ?  $::locale->text('WARN: Tax included value!') : '';
}
1;
