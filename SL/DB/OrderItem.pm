package SL::DB::OrderItem;

use strict;

use List::Util qw(sum);

use SL::DB::MetaSetup::OrderItem;
use SL::DB::Manager::OrderItem;
use SL::DB::DeliveryOrderItemsStock;
use SL::DB::Helper::ActsAsList;
use SL::DB::Helper::LinkedRecords;
use SL::DB::Helper::RecordItem;
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

__PACKAGE__->configure_acts_as_list(group_by => [qw(trans_id)]);

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

sub record { goto &order }

1;

