package SL::Controller::PriceSource;

use strict;

use parent qw(SL::Controller::Base);

use List::MoreUtils qw(any uniq apply);
use SL::Locale::String qw(t8);
use SL::PriceSource;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(record_item) ],
 'scalar --get_set_init' => [ qw(record) ],
);

__PACKAGE__->run_before('check_auth');

#
# actions
#

sub action_price_popup {
  my ($self) = @_;

  my $record_item = _make_record_item($::form->{row});
  my $old_unit;
  if (($old_unit = $record_item->{__additional_form_attributes}{unit_old}) && $old_unit ne $record_item->unit) {
    # reset unit changes. the way these interact on update breaks stuff
    $record_item->unit_obj(SL::DB::Manager::Unit->find_by(name => $old_unit));
    $self->js->val("select[name='unit_$::form->{row}']", $old_unit);
  }

  $self->render_price_dialog($record_item);
}

sub render_price_dialog {
  my ($self, $record_item) = @_;

  my $price_source = SL::PriceSource->new(record_item => $record_item, record => $self->record);

  $self->js
    ->run(
      'kivi.io.price_chooser_dialog',
      t8('Available Prices'),
      $self->render('oe/price_sources_dialog', { output => 0 }, price_source => $price_source)
    )
    ->reinit_widgets;

#   if (@errors) {
#     $self->js->text('#dialog_flash_error_content', join ' ', @errors);
#     $self->js->show('#dialog_flash_error');
#   }

  $self->js->render;
}


#
# internal stuff
#

sub check_auth {
  if ($::form->{vc} eq 'customer') {
    $::auth->assert('sales_edit_prices');
  } elsif ($::form->{vc} eq 'vendor') {
    $::auth->assert('purchase_edit_prices');
  } else {
    $::auth->assert('no_such_right');
  }
}

sub init_record {
  _make_record();
}

sub _make_record_item {
  my ($row) = @_;

  my $class = {
    sales_order             => 'OrderItem',
    purchase_order          => 'OrderItem',
    sales_quotation         => 'OrderItem',
    request_quotation       => 'OrderItem',
    invoice                 => 'InvoiceItem',
    purchase_invoice        => 'InvoiceItem',
    credit_note             => 'InvoiceItem',
    purchase_delivery_order => 'DeliveryOrderItem',
    sales_delivery_order    => 'DeliveryOrderItem',
  }->{$::form->{type}};

  return unless $class;

  $class = 'SL::DB::' . $class;

  my %translated_methods = (
    'SL::DB::OrderItem' => {
      id                      => 'parts_id',
      orderitems_id           => 'id',
    },
    'SL::DB::DeliveryOrderItem' => {
      id                      => 'parts_id',
      delivery_order_items_id => 'id',
    },
    'SL::DB::InvoiceItem' => {
      id                      => 'parts_id',
      invoice_id => 'id',
    },
  );

  eval "require $class";

  my $obj = $::form->{"orderitems_id_$row"}
          ? $class->meta->convention_manager->auto_manager_class_name->find_by(id => $::form->{"orderitems_id_$row"})
          : $class->new;

  for my $key (grep { /_$row$/ } keys %$::form) {
    my $method = $key;
    $method =~ s/_$row$//;
    $method = $translated_methods{$class}{$method} // $method;
    my $value = $::form->{$key};
    if ($obj->meta->column($method)) {
      if ($obj->meta->column($method)->isa('Rose::DB::Object::Metadata::Column::Date')) {
        $obj->${\"$method\_as_date"}($value);
      } elsif ((ref $obj->meta->column($method)) =~ /^Rose::DB::Object::Metadata::Column::(?:Numeric|Float|DoublePrecsion)$/) {
        $obj->${\"$method\_as_number"}($value);
      } elsif ((ref $obj->meta->column($method)) =~ /^Rose::DB::Object::Metadata::Column::Boolean$/) {
        $obj->$method(!!$value);
      } else {
        $obj->$method($value);
      }
    } else {
      $obj->{__additional_form_attributes}{$method} = $value;
    }
  }

  if ($::form->{"id_$row"}) {
    $obj->part(SL::DB::Part->load_cached($::form->{"id_$row"}));
  }

  return $obj;
}

sub _make_record {
  my ($with_items) = @_;

  my $class = {
    sales_order             => 'Order',
    purchase_order          => 'Order',
    sales_quotation         => 'Order',
    request_quotation       => 'Order',
    purchase_invoice        => 'PurchaseInvoice',
    purchase_delivery_order => 'DeliveryOrder',
    sales_delivery_order    => 'DeliveryOrder',
  }->{$::form->{type}};

  if ($::form->{type} =~ /invoice|credit_note/) {
    $class = $::form->{vc} eq 'customer' ? 'Invoice'
           : $::form->{vc} eq 'vendor'   ? 'PurchaseInvoice'
           : do { die 'unknown invoice type' };
  }

  return unless $class;

  $class = 'SL::DB::' . $class;

  eval "require $class";

  my $obj = $::form->{id}
          ? $class->meta->convention_manager->auto_manager_class_name->find_by(id => $::form->{id})
          : $class->new;

  for my $method (keys %$::form) {
    next unless $obj->can($method);
    next unless $obj->meta->column($method);

    if ($obj->meta->column($method)->isa('Rose::DB::Object::Metadata::Column::Date')) {
      $obj->${\"$method\_as_date"}($::form->{$method});
    } elsif ((ref $obj->meta->column($method)) =~ /^Rose::DB::Object::Metadata::Column::(?:Numeric|Float|DoublePrecsion)$/) {
      $obj->${\"$method\_as\_number"}($::form->{$method});
    } elsif ((ref $obj->meta->column($method)) =~ /^Rose::DB::Object::Metadata::Column::Boolean$/) {
      $obj->$method(!!$::form->{$method});
    } else {
      $obj->$method($::form->{$method});
    }
  }

  if ($with_items) {
    my @items;
    for my $i (1 .. $::form->{rowcount}) {
      next unless $::form->{"id_$i"};
      push @items, _make_record_item($i)
    }

    $obj->items(@items) if @items;
  }
  $obj->is_sales(!!$obj->customer_id) if $class eq 'SL::DB::DeliveryOrder';

  return $obj;
}

1;
