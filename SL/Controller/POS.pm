package SL::Controller::POS;

use strict;
use parent qw(SL::Controller::Base);

use SL::Helper::Flash qw(flash flash_later);
use SL::HTML::Util;
use SL::Presenter::Tag qw(select_tag hidden_tag div_tag);
use SL::Locale::String qw(t8);

use SL::DB::Order;
use SL::DB::OrderItem;
use SL::DB::Order::TypeData qw(:types);
use SL::DB::Helper::TypeDataProxy;
use SL::DB::Helper::Record qw(get_object_name_from_type get_class_from_type);
use SL::Model::Record;

use SL::Helper::CreatePDF qw(:all);
use SL::Helper::PrintOptions;
use SL::Helper::ShippedQty;
use SL::Helper::UserPreferences::DisplayPreferences;
use SL::Helper::UserPreferences::PositionsScrollbar;
use SL::Helper::UserPreferences::UpdatePositions;

use SL::Controller::Helper::GetModels;

use List::Util qw(first sum0);
use List::UtilsBy qw(sort_by uniq_by);
use List::MoreUtils qw(uniq any none pairwise first_index);
use English qw(-no_match_vars);
use File::Spec;
use Cwd;
use Sort::Naturally;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(item_ids_to_delete ) ],
 'scalar --get_set_init' => [ qw(poso valid_types type type_data) ],
);

# show form pos
sub action_show_form {
  my ($self) = @_;
  $self->pre_render();
  $self->render(
    'pos/form',
    title => t8('POSO'),
    %{$self->{template_args}}
  );
}

# add an item row for a new item entered in the input row
sub action_add_item {
  my ($self) = @_;

  delete $::form->{add_item}->{create_part_type};

  my $form_attr = $::form->{add_item};

  unless ($form_attr->{parts_id}) {
    $self->js->flash('error', t8("No part was selected."));
    return $self->js->render();
  }


  my $item = new_item($self->order, $form_attr);

  $self->order->add_items($item);

  $self->recalc();

  $self->get_item_cvpartnumber($item);

  my $item_id = join('_', 'new', Time::HiRes::gettimeofday(), int rand 1000000000000);
  my $row_as_html = $self->p->render('pos/tabs/_row',
                                     ITEM => $item,
                                     ID   => $item_id,
                                     SELF => $self,
  );

  if ($::form->{insert_before_item_id}) {
    $self->js
      ->before ('.row_entry:has(#item_' . $::form->{insert_before_item_id} . ')', $row_as_html);
  } else {
    $self->js
      ->append('#row_table_id', $row_as_html);
  }

  $self->js
    ->val('.add_item_input', '')
    ->run('kivi.Order.init_row_handlers')
    ->run('kivi.Order.renumber_positions')
    ->focus('#add_item_parts_id_name');

  $self->js->run('kivi.Order.row_table_scroll_down') if !$::form->{insert_before_item_id};

  $self->js_redisplay_amounts_and_taxes;
  $self->js->render();
}

# Create a new order object
#
# And assign changes from the form to this object.
# Create/Update items from form (via make_item) and add them.
sub make_order {
  my ($self) = @_;

  # add_items adds items to an order with no items for saving, but they
  # cannot be retrieved via items until the order is saved. Adding empty
  # items to new order here solves this problem.
  my $order = SL::DB::Order->new(
                     record_type => 'sales_order',
                     orderitems  => [],
                     currency_id => $::instance_conf->get_currency_id(),
                   );

  if (!$::form->{id} && $::form->{customer_id}) {
    $order->customer_id($::form->{customer_id});
    $order = SL::Model::Record->update_after_customer_vendor_change($order);
  }

  my $form_orderitems = delete $::form->{order}->{orderitems};

  $order->assign_attributes(%{$::form->{order}});

  #$self->setup_custom_shipto_from_form($order, $::form);

  # remove deleted items
  $self->item_ids_to_delete([]);
  foreach my $idx (reverse 0..$#{$order->orderitems}) {
    my $item = $order->orderitems->[$idx];
    if (none { $item->id == $_->{id} } @{$form_orderitems}) {
      splice @{$order->orderitems}, $idx, 1;
      push @{$self->item_ids_to_delete}, $item->id;
    }
  }

  my @items;
  my $pos = 1;
  foreach my $form_attr (@{$form_orderitems}) {
    my $item = make_item($order, $form_attr);
    $item->position($pos);
    push @items, $item;
    $pos++;
  }
  $order->add_items(grep {!$_->id} @items);

  return $order;
}

# create a new item
#
# This is used to add one item
sub new_item {
  my ($record, $attr) = @_;

  my $item = SL::DB::OrderItem->new;

  # Remove attributes where the user left or set the inputs empty.
  # So these attributes will be undefined and we can distinguish them
  # from zero later on.
  for (qw(qty_as_number sellprice_as_number discount_as_percent)) {
    delete $attr->{$_} if $attr->{$_} eq '';
  }

  $item->assign_attributes(%$attr);
  $item->qty(1.0)                   if !$item->qty;
  $item->unit($item->part->unit)    if !$item->unit;

  my ($price_src, $discount_src) = get_best_price_and_discount_source($record, $item, 0);

  my %new_attr;
  $new_attr{description}            = $item->part->description     if ! $item->description;
  $new_attr{qty}                    = 1.0                          if ! $item->qty;
  $new_attr{price_factor_id}        = $item->part->price_factor_id if ! $item->price_factor_id;
  $new_attr{sellprice}              = $price_src->price;
  $new_attr{discount}               = $discount_src->discount;
  $new_attr{active_price_source}    = $price_src;
  $new_attr{active_discount_source} = $discount_src;
  $new_attr{longdescription}        = $item->part->notes           if ! defined $attr->{longdescription};
  $new_attr{project_id}             = $record->globalproject_id;
  $new_attr{lastcost}               = $record->is_sales ? $item->part->lastcost : 0;

  # add_custom_variables adds cvars to an orderitem with no cvars for saving, but
  # they cannot be retrieved via custom_variables until the order/orderitem is
  # saved. Adding empty custom_variables to new orderitem here solves this problem.
  $new_attr{custom_variables} = [];

  my $texts = get_part_texts($item->part, $record->language_id, description => $new_attr{description}, longdescription => $new_attr{longdescription});

  $item->assign_attributes(%new_attr, %{ $texts });

  return $item;
}

sub _setup_edit_action_bar {
  my ($self, %params) = @_;
  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('ACTION'),
        call      => [ 'kivi.POS.action', {
          action             => 'ACTION',
        }],
      ],
    );
  }
}

sub pre_render {
  my ($self) = @_;

  $self->{all_taxzones}               = SL::DB::Manager::TaxZone->get_all_sorted();
  $self->{all_languages}              = SL::DB::Manager::Language->get_all_sorted();
  $self->{all_salesmen}               = SL::DB::Manager::Employee->get_all_sorted();
  $self->{current_employee_id}        = SL::DB::Manager::Employee->current->id;
  $self->{all_delivery_terms}         = SL::DB::Manager::DeliveryTerm->get_all_sorted();
  $self->{all_payment_terms}          = SL::DB::Manager::PaymentTerm->get_all_sorted();
  $::request->{layout}->use_javascript("${_}.js") for
    qw(kivi.SalesPurchase kivi.POS kivi.File
       calculate_qty kivi.Validator follow_up
       show_history
      );
  $self->_setup_edit_action_bar;
}

#inits
sub init_poso {
  $_[0]->make_order;
}

sub init_valid_types {
  $_[0]->type_data->valid_types;
}

sub init_type {
  my ($self) = @_;

  my $type = $self->poso->record_type;
  if (none { $type eq $_ } @{$self->valid_types}) {
    die "Not a valid type for order";
  }

  $self->type($type);
}

sub init_type_data {
  my ($self) = @_;
  SL::DB::Helper::TypeDataProxy->new('SL::DB::Order', $self->poso->record_type);
}

1;
