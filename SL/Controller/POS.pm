package SL::Controller::POS;

use strict;
use parent qw(SL::Controller::Base);

use SL::Controller::Order;

use SL::Model::Record;
use SL::DB::ValidityToken;
use SL::DB::Order::TypeData qw(:types);
use SL::DB::DeliveryOrder::TypeData qw(:types);
use SL::DB::TaxZone;
use SL::DB::Currency;

use SL::DBUtils qw(do_query);
use SL::Locale::String qw(t8);

use Rose::Object::MakeMethods::Generic
(
 'scalar --get_set_init' => [ qw(
   order_controller
   ) ]
);

# add a new point of sale order
# it's a sales order with a diffrent form
sub action_add {
  my ($self) = @_;
  $::form->{type} = SALES_ORDER_TYPE();

  if ($::form->{id}) {
    $self->load_receipt(delete $::form->{id});
  }

  $self->order(SL::Model::Record->update_after_new($self->order));

  $self->order_controller->pre_render();
  $self->pre_render();

  if (!$::form->{form_validity_token}) {
    $::form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_ORDER_SAVE())->token;
  }

  $self->render(
    'pos/form',
    title => t8('Point Of Sale'),
    %{$self->{template_args}}
  );
}

sub action_edit_order_item_row_dialog {
  my ($self) = @_;

  my $item;
  my $temp_item_id = $::form->{item_id};
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

  my $taxzone_id = SL::DB::Manager::TaxZone->get_all_sorted(
    query => [ obsolete => 0 ]
  )->[0]->id;
  my $currency_id = SL::DB::Default->get->currency_id;

  my $new_customer = SL::DB::Customer->new(
    name => $name,
    taxzone_id  => $taxzone_id,
    currency_id => $currency_id,
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
    $order->save();
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

  my $delivery_order = SL::Model::Record->new_from_workflow(
    $order,
    SALES_DELIVERY_ORDER_TYPE(),
    {
      no_linked_records => 1, # order is not saved
    }
  );

  # $main::lxdebug->dump(0, "TST: ", $delivery_order);
  # $main::lxdebug->dump(0, "TST: ", $delivery_order->items());

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

  return $self->order($new_order);
}


#
# intits
#

sub init_order_controller {
  my ($self) = @_;
  SL::Controller::Order->new();
}

1;
