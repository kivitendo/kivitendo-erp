package SL::Controller::POS;

use strict;
use parent qw(SL::Controller::Base);

use SL::Controller::Order;
use SL::Controller::DeliveryOrder;

use SL::Model::Record;
use SL::DB::ValidityToken;
use SL::DB::Order::TypeData qw(:types);
use SL::DB::DeliveryOrder::TypeData qw(:types);
use SL::DB::Invoice::TypeData qw(:types);
use SL::DB::TaxZone;
use SL::DB::Currency;
use SL::DB::PointOfSale;
use SL::DB::TSEDevice;

use SL::DBUtils qw(do_query);
use SL::Locale::String qw(t8);
use SL::Helper::Flash qw(flash_later);
use SL::Helper::DateTime;

use SL::POS;
use SL::POS::Receipt;
use SL::POS::TSEAPI;

use Rose::Object::MakeMethods::Generic
(
 'scalar --get_set_init' => [ qw(
   order_controller
   ) ]
);

sub action_select_pos {
  my ($self) = @_;

  my $points_of_sale = SL::DB::Manager::PointOfSale->get_all();

  $self->render(
    'pos/select_pos_form',
    title => t8('Point Of Sale'),
    POINTS_OF_SALE => $points_of_sale,
  );
}

# add a new point of sale order
# it's a sales order with a diffrent form
sub action_add {
  my ($self) = @_;

  my $point_of_sale;
  if (!$::form->{point_of_sale_id}) {
    return $self->action_select_pos();
  } else {
    $point_of_sale = SL::DB::Manager::PointOfSale->find_by(
      id => $::form->{point_of_sale_id}
    ) or die t8("Could not find POS with id '#1'", $::form->{point_of_sale_id});
  }

  $::form->{type} = SALES_ORDER_TYPE();

  if ($::form->{id}) {
    $self->load_receipt(delete $::form->{id});
  }

  $self->order(SL::Model::Record->update_after_new($self->order));
  $self->order->transaction_description(
    t8("POS: #1", $point_of_sale->name)
  ) unless $self->order->transaction_description;

  $self->order_controller->pre_render();
  $self->pre_render();

  if (!$::form->{form_validity_token}) {
    $::form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_ORDER_SAVE())->token;
  }

  $self->render(
    'pos/form',
    title => $point_of_sale->name
  );
}

sub action_edit_order_item_row_dialog {
  my ($self) = @_;

  my $item;
  my $temp_item_id = $::form->{item_id};
  die "need 'item_id'" unless $temp_item_id;
  foreach my $idx (0 .. (scalar @{$::form->{orderitem_ids}} - 1)) {
    if ($::form->{orderitem_ids}->[$idx] eq $temp_item_id) {
      $item = $self->order->items->[$idx];
      last;
    }
  }
  die "cound not find item with item with id $temp_item_id" unless $item;

  $self->render(
    'pos/_edit_order_item_row_dialog', { layout => 0 },
    popup_dialog                 => 1,
    popup_js_delete_row_function => "kivi.POS.delete_order_item_row_point_of_sale('$temp_item_id')",
    popup_js_close_function      => '$("#edit_order_item_row_dialog").dialog("close")',
    popup_js_assign_function     => "kivi.POS.assign_edit_order_item_row_point_of_sale('$temp_item_id')",
    ITEM                         => $item
  );
}

sub action_set_cash_customer {
  my ($self) = @_;

  my $cash_customer_id = $::instance_conf->get_pos_cash_customer_id or
    die "No cash customer set in client config.";
  my $cash_customer = SL::DB::Manager::Customer->find_by( id => $cash_customer_id );

  $self->change_customer($cash_customer);
}

sub action_create_new_customer {
  my ($self) = @_;
  die "id can't be given" if defined $::form->{new_customer}->{id};
  my $name = delete $::form->{new_customer}->{name}
    or die "name is needed.";

  # fetches the first taxzone id, but not necessarily the correct one!
  my $taxzone_id = SL::DB::Manager::TaxZone->get_all_sorted(
    query => [ obsolete => 0 ]
  )->[0]->id;
  my $currency_id = SL::DB::Default->get->currency_id;

  my $new_customer = SL::DB::Customer->new(
    name => $name,
    taxzone_id  => $taxzone_id,
    currency_id => $currency_id,
    salesman_id => SL::DB::Manager::Employee->current->id,
    %{$::form->{new_customer}}
  );
  $new_customer->save();

  $self->change_customer($new_customer);
}

sub change_customer {
  my ($self, $customer) = @_;

  die "Need customer object." unless ref $customer eq 'SL::DB::Customer';

  return $self->js
    ->val(        '#order_customer_id',      $customer->id)
    ->val(        '#order_customer_id_name', $customer->displayable_name)
    ->removeClass('#order_customer_id_name', 'customer-vendor-picker-undefined')
    ->addClass(   '#order_customer_id_name', 'customer-vendor-picker-picked')
    ->run('kivi.Order.reload_cv_dependent_selections')
    ->render();
}

sub action_open_new_customer_dialog {
  my ($self) = @_;

  $self->render(
    'pos/_new_customer_dialog', { layout => 0 },
    popup_dialog            => 1,
    popup_js_close_function => '$("#new_customer_dialog").dialog("close")',
  );
}

sub action_add_discount_item_dialog {
  my ($self) = @_;

  my $type = $::form->{discount}->{type};
  my $type_name;
  if ($type eq 'percent') {
    $type_name = t8('Percent');
  } elsif ($type eq 'absolute') {
    $type_name = t8('Absolute');
  } else {
    die "unknown value for discount.type '$type'";
  }

  $self->render(
    'pos/_add_discount_item_dialog', { layout => 0 },
    popup_dialog            => 1,
    popup_js_close_function => '$("#add_discount_item_dialog").dialog("close")',
    TYPE_NAME               => $type_name,
  );
}

sub action_parking_receipt {
  my ($self) = @_;
  my $order = $self->order;

  SL::DB->client->with_transaction( sub {
    SL::Model::Record->save($order,
      with_validity_token => {
        scope => SL::DB::ValidityToken::SCOPE_ORDER_SAVE(),
        token => delete $::form->{form_validity_token}
      },
    );

    my $query = <<SQL;
SQL
    do_query(
      $::form,
      SL::DB->client->dbh,
      q| UPDATE oe SET record_type = ? WHERE id = ? |,
      SALES_RECEIPT_ORDER_TYPE(), $order->id
    );
    $self->order(undef);
    1;
  });

  $self->redirect_to(
    action => 'add',
    point_of_sale_id => $::form->{point_of_sale_id},
  );
}

sub action_open_receipt_load_dialog {
  my ($self) = @_;

  my $orders = SL::DB::Manager::Order->get_all(
    where => [
      record_type => SALES_RECEIPT_ORDER_TYPE(),
    ],
    sort_by => 'itime',
  );

  $self->render(
    'pos/_receipt_load_dialog', { layout => 0 },
    popup_dialog                 => 1,
    popup_js_close_function      => '$("#receipt_load_dialog").dialog("close")',
    ORDERS                       => $orders,
  );
}

sub action_to_delivery_order {
  my ($self) = @_;
  my $order = $self->order;

  my $delivery_order = POS->order_to_delivery_order($order); # may die, runs in transaction

  flash_later("info", t8("Delivery Order created."));

  # TODO: print

  $self->redirect_to(
    action => 'add',
    point_of_sale_id => $::form->{point_of_sale_id},
  );
}

sub action_to_invoice {
  my ($self) = @_;
  my $order = $self->order;

  my $invoice = SL::POS::order_to_invoice($order); # may die, runs in transaction

  flash_later("info", t8("Invoice created."));

  # TODO: print

  $self->redirect_to(
    action => 'add',
    point_of_sale_id => $::form->{point_of_sale_id},
  );
}

sub action_do_payment {
  my ($self) = @_;

  my $point_of_sale = SL::DB::Manager::PointOfSale->find_by(
    id => $::form->{point_of_sale_id}
  ) or die t8("Could not find POS with id '#1'", $::form->{point_of_sale_id});

  my $transaction_number = $::form->{transaction_number} // (10000 + int(rand(10000))); # TODO: transaction_number should come from start_transaction

  my $tse_device =
    SL::DB::Manager::TSEDevice->find_by(device_id => $::form->{tse_device_id})
    // SL::DB::Manager::TSEDevice->get_first()   # hack while we don't have a start_transaction
    // die t8("Could not find TSE Device with device_id '#1'", $::form->{tse_device_id});

  my $order = $self->order;
  $order->calculate_prices_and_taxes();

  my $amount = $self->order->amount;

  my $terminal_amount = 0;
  if ($::form->{payment}->{terminal}) {
    $terminal_amount = $::form->{payment}->{terminal};
    if ($terminal_amount > $amount) {
      die t8("Can't withdraw from card.");
    }
  }

  my $cash_payment = 0;
  my $cash_change = 0;
  my $cash_amount = 0;
  if ($::form->{payment}->{cash}) {
    $cash_payment = $::form->{payment}->{cash};
    if ($cash_payment + $terminal_amount > $amount) {
      $cash_change = $cash_payment + $terminal_amount - $amount;
      $cash_amount = $cash_payment - $cash_change;
    } else {
      $cash_amount = $cash_payment;
    }
  }

  if ($cash_amount + $terminal_amount < $amount) {
    die t8("The amount entered is to small.");
  }

  my $validity_token = $::form->{form_validity_token}; # validity token of the order

  my $invoice = SL::POS::pay_order_with_amounts($point_of_sale, $tse_device, $transaction_number, $order, $validity_token, $cash_amount, $terminal_amount);

  # TODO: Print receipt
  # my $receipt_data = SL::POSReceipt::load_receipt_by_ar_id($invoice->id);

  return $self->js
    ->run(
      'kivi.POS.open_paid_dialog',
      $cash_change && $::form->format_amount(undef, $cash_change, 2)
    )
    ->render();
}

#
# helpers
#

sub pre_render {
  my ($self) = @_;

  $::request->{layout}->use_javascript("${_}.js") for qw(
    kivi.POS
  );

  # remove actionbar from order_controller
  for my $bar ($::request->layout->get('actionbar')) {
    $bar->actions([]);
  }
}

sub order {
  my $self = shift @_;
  $self->order_controller->order(@_);
}

sub load_receipt {
  my ($self, $order_id) = @_;

  my $order_to_delete = SL::DB::Manager::Order->find_by(
    id          => $order_id,
    record_type => SALES_RECEIPT_ORDER_TYPE,
  );

  return unless $order_to_delete;

  $order_to_delete->record_type(SALES_ORDER_TYPE());

  my $new_order = SL::Model::Record->new_from_workflow(
    $order_to_delete,
    SALES_ORDER_TYPE(),
    no_linked_records => 1
  );
  $order_to_delete->delete;

  $self->order($new_order);
  $self->order_controller->reinit_after_new_order();
  return $new_order;
}


#
# intits
#

sub init_order_controller {
  my ($self) = @_;
  SL::Controller::Order->new();
}

1;
