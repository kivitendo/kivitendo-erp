package SL::Controller::ShopOrder;

use strict;

use parent qw(SL::Controller::Base);

use SL::BackgroundJob::ShopOrderMassTransfer;
use SL::System::TaskServer;
use SL::DB::ShopOrder;
use SL::DB::ShopOrderItem;
use SL::DB::Shop;
use SL::DB::History;
use SL::DBUtils;
use SL::Shop;
use SL::Helper::Flash;
use SL::Locale::String;
use SL::Controller::Helper::ParseFilter;
use Rose::Object::MakeMethods::Generic
(
  'scalar --get_set_init' => [ qw(shop_order shops transferred js) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('setup');

use Data::Dumper;

sub action_get_orders {
  my ( $self ) = @_;
  my $orders_fetched;
  my $new_orders;

  my $type = $::form->{type};
  if ( $type eq "get_next" ) {
    my $active_shops = SL::DB::Manager::Shop->get_all(query => [ obsolete => 0 ]);
    foreach my $shop_config ( @{ $active_shops } ) {
      my $shop = SL::Shop->new( config => $shop_config );

      $new_orders = $shop->connector->get_new_orders;
      push @{ $orders_fetched }, $new_orders ;
    }

  } elsif ( $type eq "get_one" ) {
    my $shop_id = $::form->{shop_id};
    my $shop_ordernumber = $::form->{shop_ordernumber};

    if ( $shop_id && $shop_ordernumber ){
      my $shop_config = SL::DB::Manager::Shop->get_first(query => [ id => $shop_id, obsolete => 0 ]);
      my $shop = SL::Shop->new( config => $shop_config );
      unless ( SL::DB::Manager::ShopOrder->get_all_count( query => [ shop_ordernumber => $shop_ordernumber, shop_id => $shop_id, obsolete => 'f' ] )) {
        my $connect = $shop->check_connectivity;
        $new_orders = $shop->connector->get_one_order($shop_ordernumber);
        push @{ $orders_fetched }, $new_orders ;
      } else {
        flash_later('error', t8('Shoporder "#2" From Shop "#1" is already fetched', $shop->config->description, $shop_ordernumber));
      }
    } else {
        flash_later('error', t8('Shop or ordernumber not selected.'));
    }
  }

  foreach my $shop_fetched(@{ $orders_fetched }) {
    if($shop_fetched->{error}){
      flash_later('error', t8('From shop "#1" :  #2 ', $shop_fetched->{shop_description}, $shop_fetched->{message},));
    }else{
      flash_later('info', t8('From shop #1 :  #2 shoporders have been fetched.', $shop_fetched->{shop_description}, $shop_fetched->{number_of_orders},));
    }
  }

  $self->redirect_to(controller => "ShopOrder", action => 'list', filter => { 'transferred:eq_ignore_empty' => 0, obsolete => 0 });
}

sub action_list {
  my ( $self ) = @_;

  my %filter = ($::form->{filter} ? parse_filter($::form->{filter}) : query => [ transferred => 0, obsolete => 0 ]);
  my $transferred = $::form->{filter}->{transferred_eq_ignore_empty} ne '' ? $::form->{filter}->{transferred_eq_ignore_empty} : '';
  my $sort_by = $::form->{sort_by} ? $::form->{sort_by} : 'order_date';
  $sort_by .=$::form->{sort_dir} ? ' DESC' : ' ASC';
  my $shop_orders = SL::DB::Manager::ShopOrder->get_all( %filter, sort_by => $sort_by,
                                                      with_objects => ['shop_order_items', 'kivi_customer', 'shop'],
                                                    );

  foreach my $shop_order(@{ $shop_orders }){
    $shop_order->{open_invoices} = $shop_order->check_for_open_invoices;
  }
  $self->_setup_list_action_bar;
  $self->render('shop_order/list',
                title       => t8('ShopOrders'),
                SHOPORDERS  => $shop_orders,
                TOOK        => $transferred,
              );
}

sub action_show {
  my ( $self ) = @_;
  my $id = $::form->{id} || {};
  my $shop_order = SL::DB::ShopOrder->new( id => $id )->load( with => ['kivi_customer'] );
  die "can't find shoporder with id $id" unless $shop_order;

  my $proposals = $shop_order->check_for_existing_customers;

  $self->render('shop_order/show',
                title       => t8('Shoporder'),
                IMPORT      => $shop_order,
                PROPOSALS   => $proposals,
              );

}

sub action_customer_assign_to_shoporder {
  my ($self) = @_;

  $self->shop_order->assign_attributes( kivi_customer => $::form->{customer} );
  $self->shop_order->save;
  $self->redirect_to(controller => "ShopOrder", action => 'show', id => $self->shop_order->id);
}

sub action_delete_order {
  my ( $self ) = @_;

  $self->shop_order->obsolete(1);
  $self->shop_order->save;
  $self->redirect_to(controller => "ShopOrder", action => 'list', filter => { 'transferred:eq_ignore_empty' => 0 });
}

sub action_undelete_order {
  my ( $self ) = @_;

  $self->shop_order->obsolete(0);
  $self->shop_order->save;
  $self->redirect_to(controller => "ShopOrder", action => 'list', filter => { 'transferred:eq_ignore_empty' => 0, obsolete => 0 });
}

sub action_transfer {
  my ( $self ) = @_;

  $::form->{customer} ||= $::form->{partial_transfer_customer_id};

  my $customer = SL::DB::Manager::Customer->find_by(id => $::form->{customer});
  die "Can't find customer" unless ref $customer eq 'SL::DB::Customer';

  my $employee = SL::DB::Manager::Employee->current;
  die "Can't find employee" unless $employee;

  die "Can't load shop_order form form->import_id" unless $self->shop_order;
  my $order = $self->shop_order->convert_to_sales_order(customer => $customer, employee => $employee,
                                                        pos_ids  => $::form->{pos_ids}               );

  if ($order->{error}){
    flash_later('error',@{$order->{errors}});
    $self->redirect_to(controller => "ShopOrder", action => 'show', id => $self->shop_order->id);
  }else{
    $order->db->with_transaction( sub {
      $order->calculate_prices_and_taxes;
      $order->save;
      SL::DB::OrderVersion->new(oe_id => $order->id, version => 1)->save;

      my $snumbers = "ordernumber_" . $order->ordnumber;
      SL::DB::History->new(
                        trans_id    => $order->id,
                        snumbers    => $snumbers,
                        employee_id => SL::DB::Manager::Employee->current->id,
                        addition    => 'SAVED',
                        what_done   => 'Shopimport -> Order',
                      )->save();
      foreach my $item(@{ $order->orderitems }){
        $item->parse_custom_variable_values->save;
        $item->{custom_variables} = \@{ $item->cvars_by_config };
        $item->save;
      }

      $self->shop_order->transferred(1);
      $self->shop_order->transfer_date(DateTime->now_local);
      $self->shop_order->save;
      $self->shop_order->link_to_record($order);
    }) || die $order->db->error;
    $self->redirect_to(controller => 'Order', action => 'edit', type => 'sales_order', vc => 'customer', id => $order->id);
  }
}

sub action_mass_transfer {
  my ($self) = @_;
  my @shop_orders =  @{ $::form->{id} || [] };

  my $job                   = SL::DB::BackgroundJob->new(
    type                    => 'once',
    active                  => 1,
    package_name            => 'ShopOrderMassTransfer',
  )->set_data(
     shop_order_record_ids       => [ @shop_orders ],
     num_order_created           => 0,
     num_order_failed            => 0,
     num_delivery_order_created  => 0,
     status                      => SL::BackgroundJob::ShopOrderMassTransfer->WAITING_FOR_EXECUTION(),
     conversion_errors         => [],
   )->update_next_run_at;

   SL::System::TaskServer->new->wake_up;

   my $html = $self->render('shop_order/_transfer_status', { output => 0 }, job => $job);

   $self->js
      ->html('#status_mass_transfer', $html)
      ->run('kivi.ShopOrder.massTransferStarted')
      ->render;
}

sub action_transfer_status {
  my ($self)  = @_;
  my $job     = SL::DB::BackgroundJob->new(id => $::form->{job_id})->load;
  my $html    = $self->render('shop_order/_transfer_status', { output => 0 }, job => $job);

  $self->js->html('#status_mass_transfer', $html);
  $self->js->run('kivi.ShopOrder.massTransferFinished') if $job->data_as_hash->{status} == SL::BackgroundJob::ShopOrderMassTransfer->DONE();
  $self->js->render;

}

sub action_apply_customer {
  my ( $self, %params ) = @_;
  my $shop = SL::DB::Manager::Shop->find_by( id => $self->shop_order->shop_id );
  my $what = $::form->{create_customer}; # new from billing, customer or delivery address
  my %address = ( 'name'                  => $::form->{$what.'_name'},
                  'department_1'          => $::form->{$what.'_company'},
                  'department_2'          => $::form->{$what.'_department'},
                  'street'                => $::form->{$what.'_street'},
                  'zipcode'               => $::form->{$what.'_zipcode'},
                  'city'                  => $::form->{$what.'_city'},
                  'email'                 => $::form->{$what.'_email'},
                  'country'               => $::form->{$what.'_country'},
                  'phone'                 => $::form->{$what.'_phone'},
                  'email'                 => $::form->{$what.'_email'},
                  'greeting'              => $::form->{$what.'_greeting'},
                  'taxincluded_checked'   => $shop->pricetype eq "brutto" ? 1 : 0,
                  'taxincluded'           => $shop->pricetype eq "brutto" ? 1 : 0,
                  'pricegroup_id'         => (split '\/',$shop->price_source)[0] eq "pricegroup" ?  (split '\/',$shop->price_source)[1] : undef,
                  'taxzone_id'            => $shop->taxzone_id,
                  'currency'              => $::instance_conf->get_currency_id,
                  #'payment_id'            => 7345,# TODO hardcoded
                );
  my $customer;
  if($::form->{cv_id}){
    $customer = SL::DB::Customer->new(id => $::form->{cv_id})->load;
    $customer->assign_attributes(%address);
    $customer->save;
  }else{
    $customer = SL::DB::Customer->new(%address);
    $customer->save;
  }
  my $snumbers = "customernumber_" . $customer->customernumber;
  SL::DB::History->new(
                    trans_id    => $customer->id,
                    snumbers    => $snumbers,
                    employee_id => SL::DB::Manager::Employee->current->id,
                    addition    => 'SAVED',
                    what_done   => 'Shopimport',
                  )->save();

  $self->redirect_to(action => 'show', id => $::form->{import_id});
}

sub setup {
  my ($self) = @_;
  $::auth->assert('shop_part_edit');
  $::request->layout->use_javascript("${_}.js")  for qw(kivi.ShopOrder);
}

sub check_auth {
  $::auth->assert('shop_part_edit');
}
#
# Helper
#

sub init_shop_order {
  my ( $self ) = @_;
  return SL::DB::ShopOrder->new(id => $::form->{import_id})->load if $::form->{import_id};
}

sub init_transferred {
  [ { title => t8("all"),             value => '' },
    { title => t8("transferred"),     value => 1  },
    { title => t8("not transferred"), value => 0  }, ]
}

sub init_shops {
  SL::DB::Shop->shops_dd;
}

sub _setup_list_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
        action => [
          t8('Search'),
          submit    => [ '#shoporders', { action => "ShopOrder/list" } ],
        ],
        combobox => [
          link => [
            t8('Shoporders'),
            call    => [ 'kivi.ShopOrder.get_orders_next' ],
            tooltip => t8('New shop orders'),
          ],
          action => [
            t8('Get one order'),
            call    => [ 'kivi.ShopOrder.get_one_order_setup', id => "get_one" ],
            tooltip => t8('Get one order by shopordernumber'),
          ],
        ],
        'separator',
        action => [
          t8('Execute'),
          call => [ 'kivi.ShopOrder.setup', id => "mass_transfer" ],
          tooltip => t8('Transfer all marked'),
        ],
    );
  }
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::ShopOrder - Shoporder CRUD Controller

=head1 DESCRIPTION

Fetches the shoporders and transfers them to orders.

Relations for shoporders

=over 2

=item shop_order_items

=item shops

=item shop_parts

=back

=head1 URL ACTIONS

=over 4

=item C<action_get_orders>

Fetches the shoporders with the shopconnector class

=item C<action_list>

List the shoporders by different filters.
From the List you can transfer shoporders into orders in batch where it is possible or one by one.

=item C<action_show>

Shows one order. From here you can apply/change/select customer data and transfer the shoporder to an order.

=item C<action_delete>

Marks the shoporder as obsolete. It's for shoporders you don't want to transfer.

=item C<action_undelete>

Marks the shoporder obsolete = false

=item C<action_transfer>

Transfers one shoporder to an order.
If the optional  $::form->{pos_ids} exists, they will be added
as a param for the convert_to_sales_order method

=item C<action_apply_customer>

Applys a new customer from the shoporder.

=back

=head1 TASKSERVER ACTIONS

=over 4

=item C<action_mass_transfer>

Transfers more shoporders by backgroundjob called from the taskserver to orders.

=item C<action_transfer_status>

Shows the backgroundjobdata for the popup status window

=back

=head1 SETUP

=over 4

=item C<setup>

=back

=head1 INITS

=over 4

=item C<init_shoporder>

=item C<init_transfered>

Transferstatuses for the filter dropdown

=item C<init_shops>

Filter dropdown Shops

=back

=head1 TODO

Implements different payments, pricesources and pricegroups. Till now not needed.

=head1 BUGS

None yet. :)

=head1 AUTHOR

W. Hahn E<lt>wh@futureworldsearch.netE<gt>

=cut
