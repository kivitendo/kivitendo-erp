package SL::Controller::PriceSource;

use strict;

use parent qw(SL::Controller::Base);

use List::MoreUtils qw(any uniq apply);
use SL::ClientJS;
use SL::Locale::String qw(t8);
use SL::PriceSource;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(record_item) ],
 'scalar --get_set_init' => [ qw(js record) ],
);

__PACKAGE__->run_before('check_auth');

#
# actions
#

sub action_price_popup {
  my ($self) = @_;

  my $record_item = _make_record_item($::form->{row});

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

  $self->js->render($self);
}


#
# internal stuff
#

sub check_auth {
  $::auth->assert('edit_prices');
}

sub init_js {
  SL::ClientJS->new
}

sub init_record {
  _make_record();
}

sub _make_record_item {
  my ($row) = @_;

  my $class = {
    sales_order             => 'OrderItem',
    purchase_oder           => 'OrderItem',
    sales_quotation         => 'OrderItem',
    request_quotation       => 'OrderItem',
    invoice                 => 'InvoiceItem',
    purchase_invoice        => 'InvoiceItem',
    purchase_delivery_order => 'DeliveryOrderItem',
    sales_delivery_order    => 'DeliveryOrderItem',
  }->{$::form->{type}};

  return unless $class;

  $class = 'SL::DB::' . $class;

  eval "require $class";

  my $obj = $::form->{"orderitems_id_$row"}
          ? $class->meta->convention_manager->auto_manager_class_name->find_by(id => $::form->{"orderitems_id_$row"})
          : $class->new;

  for my $method (apply { s/_$row$// } grep { /_$row$/ } keys %$::form) {
    next unless $obj->meta->column($method);
    if ($obj->meta->column($method)->isa('Rose::DB::Object::Metadata::Column::Date')) {
      $obj->${\"$method\_as_date"}($::form->{"$method\_$row"});
    } elsif ((ref $obj->meta->column($method)) =~ /^Rose::DB::Object::Metadata::Column::(?:Numeric|Float|DoublePrecsion)$/) {
      $obj->${\"$method\_as_number"}($::form->{"$method\_$row"});
    } else {
      $obj->$method($::form->{"$method\_$row"});
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
    purchase_oder           => 'Order',
    sales_quotation         => 'Order',
    request_quotation       => 'Order',
    purchase_delivery_order => 'DeliveryOrder',
    sales_delivery_order    => 'DeliveryOrder',
  }->{$::form->{type}};

  if ($::form->{type} eq 'invoice') {
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

  return $obj;
}

1;

