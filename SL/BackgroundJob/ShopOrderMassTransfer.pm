package SL::BackgroundJob::ShopOrderMassTransfer;

use strict;
use warnings;

use parent qw(SL::BackgroundJob::Base);

use SL::DBUtils;
use SL::DB::ShopOrder;
use SL::DB::ShopOrderItem;
use SL::DB::Order;
use SL::DB::History;
use SL::DB::DeliveryOrder;
use SL::DB::Inventory;
use Sort::Naturally ();
use SL::Locale::String qw(t8);

use constant WAITING_FOR_EXECUTION        => 0;
use constant CONVERTING_TO_ORDER          => 1;
use constant DONE                         => 2;

# Data format:
# my $data                  = {
#     shop_order_record_ids       => [ 603, 604, 605],
#     num_order_created           => 0,
#     orders_ids                  => [1,2,3]
#     conversion_errors         => [ { id => 603 , item => 2, message => "Out of stock"}, ],
# };
#

sub create_order {
  my ( $self ) = @_;
  my $job_obj = $self->{job_obj};
  my $db      = $job_obj->db;
  $job_obj->set_data(CONVERTING_TO_ORDER())->save;

  my $data = $job_obj->data_as_hash;
  foreach my $shop_order_id (@{ $data->{shop_order_record_ids} }) {
    my $shop_order = SL::DB::ShopOrder->new(id => $shop_order_id)->load;
    unless($shop_order){
      push @{ $data->{conversion_errors} }, { id => $shop_order->id, number => $shop_order->shop_ordernumber, message => t8('Shoporder not found') };
      $job_obj->update_attributes(data_as_hash => $data);
    }
    my $customer = SL::DB::Manager::Customer->find_by(id => $shop_order->{kivi_customer_id});
    unless($customer){
      push @{ $data->{conversion_errors} }, { id => $shop_order->id, number => $shop_order->shop_ordernumber, message => t8('Customer not found') };
      $job_obj->update_attributes(data_as_hash => $data);
    }
    my $employee = SL::DB::Manager::Employee->current;
    my $items = SL::DB::Manager::ShopOrderItem->get_all( where => [shop_order_id => $shop_order_id], );

    if ($customer->{order_lock} == 0) {
      $shop_order->{shop_order_items} = $items;

      $db->with_transaction( sub {
        my $order = $shop_order->convert_to_sales_order(customer => $customer, employee => $employee);

        if ($order->{error}){
          push @{ $data->{conversion_errors} }, { id => $shop_order->id, number => $shop_order->shop_ordernumber, message => \@{$order->{errors}} };
          $job_obj->update_attributes(data_as_hash => $data);
        }else{
          $order->save;
          $order->calculate_prices_and_taxes;
          my $snumbers = "ordernumber_" . $order->ordnumber;
          SL::DB::History->new(
                            trans_id    => $order->id,
                            snumbers    => $snumbers,
                            employee_id => SL::DB::Manager::Employee->current->id,
                            addition    => 'SAVED',
                            what_done   => 'Shopimport->Order(MassTransfer)',
                          )->save();
          $shop_order->transferred(1);
          $shop_order->transfer_date(DateTime->now_local);
          $shop_order->save;
          $shop_order->link_to_record($order);
          $data->{num_order_created} ++;
          push @{ $data->{orders_ids} }, $order->id;
          push @{ $data->{shop_orders_ids} }, $shop_order->id;

          $job_obj->update_attributes(data_as_hash => $data);
        }
        1;
      })or do {
        push @{ $data->{conversion_errors} }, { id => $shop_order->id, number => $shop_order->shop_ordernumber, message => $@ };
        $job_obj->update_attributes(data_as_hash => $data);
      }
    }else{
      push @{ $data->{conversion_errors} }, { id => $shop_order->id, number => $shop_order->shop_ordernumber, message => t8('Customerorderlock') };
      $job_obj->update_attributes(data_as_hash => $data);
    }
  }
}

sub run {
  my ($self, $job_obj) = @_;

  $self->{job_obj}         = $job_obj;
  $self->create_order;

  $job_obj->set_data(status => DONE())->save;

  return 1;
}
1;
