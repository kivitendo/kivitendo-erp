package SL::Controller::DeliveryOrder::TypeData;

use strict;
use Exporter qw(import);
use Scalar::Util qw(weaken);
use SL::Locale::String qw(t8);

use constant {
  SALES_DELIVERY_ORDER_TYPE    => 'sales_delivery_order',
  PURCHASE_DELIVERY_ORDER_TYPE => 'purchase_delivery_order',
  SUPPLIER_DELIVERY_ORDER_TYPE => 'supplier_delivery_order',
  RMA_DELIVERY_ORDER_TYPE      => 'rma_delivery_order',
};

our @EXPORT_OK = qw(SALES_DELIVERY_ORDER_TYPE PURCHASE_DELIVERY_ORDER_TYPE SUPPLIER_DELIVERY_ORDER_TYPE RMA_DELIVERY_ORDER_TYPE);

use Rose::Object::MakeMethods::Generic scalar => [ qw(c) ];

my %type_data = (
  SALES_DELIVERY_ORDER_TYPE() => {
    text => {
      delete => t8('Delivery Order has been deleted'),
      saved  => t8('Delivery Order has been saved'),
      add    => t8("Add Sales Delivery Order"),
      edit   => t8("Edit Sales Delivery Order"),
    },
    show_menu => {
      save_and_quotation      => 0,
      save_and_rfq            => 0,
      save_and_sales_order    => 0,
      save_and_purchase_order => 0,
      save_and_delivery_order => 0,
      save_and_ap_transaction => 0,
      save_and_invoice        => 0,
      delete                  => sub { $::instance_conf->get_sales_delivery_order_show_delete },
    },
    properties => {
      customervendor => "customer",
      is_customer    => 1,
      nr_key         => "donumber",
      transfer       => 'out',
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    right => "sales_delivery_order_edit",
  },
  PURCHASE_DELIVERY_ORDER_TYPE() => {
    text => {
      delete => t8('Delivery Order has been deleted'),
      saved  => t8('Delivery Order has been saved'),
      add    => t8("Add Purchase Delivery Order"),
      edit   => t8("Edit Purchase Delivery Order"),
    },
    show_menu => {
      save_and_quotation      => 0,
      save_and_rfq            => 0,
      save_and_sales_order    => 0,
      save_and_purchase_order => 0,
      save_and_delivery_order => 0,
      save_and_ap_transaction => 0,
      save_and_invoice        => 0,
      delete                  => sub { $::instance_conf->get_sales_delivery_order_show_delete },
    },
    properties => {
      customervendor => "vendor",
      is_customer    => 0,
      nr_key         => "donumber",
      transfer       => 'in',
    },
    part_classification_query => [ "used_for_purchase" => 1 ],
    right => "purchase_delivery_order_edit",
  },
  SUPPLIER_DELIVERY_ORDER_TYPE() => {
    text => {
      delete => t8('Delivery Order has been deleted'),
      saved  => t8('Delivery Order has been saved'),
      add    => t8("Add Supplier Delivery Order"),
      edit   => t8("Edit Supplier Delivery Order"),
    },
    show_menu => {
      save_and_quotation      => 0,
      save_and_rfq            => 0,
      save_and_sales_order    => 0,
      save_and_purchase_order => 0,
      save_and_delivery_order => 0,
      save_and_ap_transaction => 0,
      save_and_invoice        => 0,
      delete                  => sub { $::instance_conf->get_sales_delivery_order_show_delete },
    },
    properties => {
      customervendor => "vendor",
      is_customer    => 0,
      nr_key         => "donumber",
      transfer       => 'out',
    },
    part_classification_query => [ "used_for_purchase" => 1 ],
    right => "purchase_delivery_order_edit",
  },
  RMA_DELIVERY_ORDER_TYPE() => {
    text => {
      delete => t8('Delivery Order has been deleted'),
      saved  => t8('Delivery Order has been saved'),
      add    => t8("Add RMA Delivery Order"),
      edit   => t8("Edit RMA Delivery Order"),
    },
    show_menu => {
      save_and_quotation      => 0,
      save_and_rfq            => 0,
      save_and_sales_order    => 0,
      save_and_purchase_order => 0,
      save_and_delivery_order => 0,
      save_and_ap_transaction => 0,
      save_and_invoice        => 0,
      delete                  => sub { $::instance_conf->get_sales_delivery_order_show_delete },
    },
    properties => {
      customervendor => "customer",
      is_customer    => 0,
      nr_key         => "donumber",
      transfer       => 'in',
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    right => "sales_delivery_order_edit",
  },
);

sub new {
  my ($class, $controller) = @_;
  my $o = bless {}, $class;
  $o->c($controller);
  weaken($o->{c});

  return $o;
}

sub valid_types {
  [
    SALES_DELIVERY_ORDER_TYPE,
    PURCHASE_DELIVERY_ORDER_TYPE,
    SUPPLIER_DELIVERY_ORDER_TYPE,
    RMA_DELIVERY_ORDER_TYPE,
  ];
}

sub type {
  $_[0]->c->type;
}

sub _get {
  my ($self, $key) = @_;

  my $ret = $type_data{$self->type}->{$key} // die "unknown property '$key'";

  ref $ret eq 'CODE'
    ? $ret->()
    : $ret;
}

sub _get3 {
  my ($self, $topic, $key) = @_;

  my $ret = $type_data{$self->type}->{$topic}->{$key} // die "unknown property '$key' in topic '$topic'";

  ref $ret eq 'CODE'
    ? $ret->()
    : $ret;
}

sub text {
  my ($self, $string) = @_;
  _get3($self, "text", $string);
}

sub show_menu {
  my ($self, $string) = @_;
  _get3($self, "show_menu", $string);
}

sub workflow {
  my ($self, $string) = @_;
  _get3($self, "workflow", $string);
}

sub properties {
  my ($self, $string) = @_;
  _get3($self, "properties", $string);
}

sub is_valid_type {
  !!exists $type_data{$_[1]};
}

sub type_data {
  $type_data{ $_[0]->type } // die "unknown type";
}

sub access {
  _get($_[0], "right");
}

sub is_quotation {
  _get3($_[0], "properties", "is_quotation");
}

sub customervendor {
  _get3($_[0], "properties", "customervendor");
}

sub nr_key {
  _get3($_[0], "properties", "nr_key");
}

sub part_classification_query {
  my ($self, $string) = @_;
  _get($self, "part_classification_query");
}

sub set_reqdate_by_type {
  my ($self) = @_;

  if (!$self->c->order->reqdate) {
    $self->c->order->reqdate(DateTime->today_local->next_workday(extra_days => 1));
  }
}

sub get_reqdate_by_type {
  my ($self, $reqdate, $saved_reqdate) = @_;

  if ($reqdate == $saved_reqdate) {
    return DateTime->today_local->next_workday(extra_days => 1);
  } else {
    return $reqdate;
  }
}
