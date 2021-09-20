package SL::Controller::DeliveryOrder::TypeData;

use strict;
use Exporter qw(import);
use Scalar::Util qw(weaken);
use SL::Locale::String qw(t8);

use constant {
  SALES_ORDER_TYPE             => 'sales_order',
  PURCHASE_ORDER_TYPE          => 'purchase_order',
  SALES_QUOTATION_TYPE         => 'sales_quotation',
  REQUEST_QUOTATION_TYPE       => 'request_quotation',
  PURCHASE_DELIVERY_ORDER_TYPE => 'purchase_delivery_order',
  SALES_DELIVERY_ORDER_TYPE    => 'sales_delivery_order',
};

our @EXPORT_OK = qw(SALES_ORDER_TYPE PURCHASE_ORDER_TYPE SALES_QUOTATION_TYPE REQUEST_QUOTATION_TYPE);

use Rose::Object::MakeMethods::Generic scalar => [ qw(c) ];

my %type_data = (
  SALES_ORDER_TYPE() => {
    text => {
      delete => t8('The order has been deleted'),
      saved  => t8('The order has been saved'),
      add    => t8("Add Sales Order"),
      edit   => t8("Edit Sales Order"),
    },
    show_menu => {
      save_and_quotation      => 1,
      save_and_rfq            => 0,
      save_and_sales_order    => 0,
      save_and_purchase_order => 1,
      save_and_delivery_order => 1,
      save_and_ap_transaction => 0,
      delete                  => sub { $::instance_conf->get_sales_order_show_delete },
    },
    workflow => {
      to_order_type        => "purchase_order",
      to_quotation_type    => "sales_quotation",
      to_order_copy_shipto => 1,
    },
    properties => {
      customervendor => "customer",
      is_quotation   => 0,
      is_customer    => 1,
      nr_key         => "ordnumber",
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    right => "sales_order_edit",
  },
  PURCHASE_ORDER_TYPE() => {
    text =>{
      delete => t8('The order has been deleted'),
      saved  => t8('The order has been saved'),
      add    => t8("Add Purchase Order"),
      edit   => t8("Edit Purchase Order"),
    },
    show_menu => {
      save_and_quotation      => 0,
      save_and_rfq            => 1,
      save_and_sales_order    => 1,
      save_and_purchase_order => 0,
      save_and_delivery_order => 1,
      save_and_ap_transaction => 1,
      delete                  => sub { $::instance_conf->get_purchase_order_show_delete },
    },
    workflow => {
      to_order_type        => "sales_order",
      to_quotation_type    => "request_quotation",
      to_order_copy_shipto => 0,
    },
    properties => {
      customervendor => "vendor",
      is_quotation   => 0,
      is_customer    => 0,
      nr_key         => "ordnumber",
    },
    part_classification_query => [ "used_for_purchase" => 1 ],
    right => "purchase_order_edit",
  },
  SALES_QUOTATION_TYPE() => {
    text => {
      delete => t8('The quotation has been deleted'),
      saved  => t8('The quotation has been saved'),
      add    => t8("Add Quotation"),
      edit   => t8("Edit Quotation"),
    },
    show_menu => {
      save_and_quotation      => 0,
      save_and_rfq            => 0,
      save_and_sales_order    => 1,
      save_and_purchase_order => 0,
      save_and_delivery_order => 0,
      save_and_ap_transaction => 0,
      delete                  => 1,
    },
    workflow => {
      to_order_type        => "sales_order",
      to_quotation_type    => "request_quotation",
      to_order_copy_shipto => 0,
    },
    properties => {
      customervendor => "customer",
      is_quotation   => 1,
      is_customer    => 1,
      nr_key         => "quonumber",
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    right => "sales_quotation_edit",
  },
  REQUEST_QUOTATION_TYPE() => {
    text => {
      delete => t8('The rfq has been deleted'),
      saved  => t8('The rfq has been saved'),
      add    => t8("Add Request for Quotation"),
      edit   => t8("Edit Request for Quotation"),
    },
    show_menu => {
      save_and_quotation      => 0,
      save_and_rfq            => 0,
      save_and_sales_order    => 0,
      save_and_purchase_order => 1,
      save_and_delivery_order => 0,
      save_and_ap_transaction => 0,
      delete                  => 1,
    },
    workflow => {
      to_order_type        => "purchase_order",
      to_quotation_type    => "request_quotation",
      to_order_copy_shipto => 0,
    },
    properties => {
      customervendor => "vendor",
      is_quotation   => 1,
      is_customer    => 0,
      nr_key         => "quonumber",
    },
    part_classification_query => [ "used_for_purchase" => 1 ],
    right => "request_quotation_edit",
  },
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
      delete                  => sub { $::instance_conf->get_sales_delivery_order_show_delete },
    },
    properties => {
      customervendor => "customer",
      is_customer    => 1,
      nr_key         => "donumber",
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
      delete                  => sub { $::instance_conf->get_sales_delivery_order_show_delete },
    },
    properties => {
      customervendor => "vendor",
      is_customer    => 0,
      nr_key         => "donumber",
    },
    part_classification_query => [ "used_for_purchase" => 1 ],
    right => "purchase_delivery_order_edit",
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
    SALES_ORDER_TYPE,
    PURCHASE_ORDER_TYPE,
    SALES_QUOTATION_TYPE,
    REQUEST_QUOTATION_TYPE,
    SALES_DELIVERY_ORDER_TYPE,
    PURCHASE_DELIVERY_ORDER_TYPE,
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

  my $extra_days = $self->type eq SALES_QUOTATION_TYPE ? $::instance_conf->get_reqdate_interval       :
                   $self->type eq SALES_ORDER_TYPE     ? $::instance_conf->get_delivery_date_interval : 1;

  if (   ($self->type eq SALES_ORDER_TYPE     &&  $::instance_conf->get_deliverydate_on)
      || ($self->type eq SALES_QUOTATION_TYPE &&  $::instance_conf->get_reqdate_on)
      && (!$self->order->reqdate)) {
    $self->c->order->reqdate(DateTime->today_local->next_workday(extra_days => $extra_days));
  }
}

sub get_reqdate_by_type {
  my ($self, $reqdate, $saved_reqdate) = @_;

  if ($reqdate == $saved_reqdate) {
    my $extra_days = $self->type eq SALES_QUOTATION_TYPE ? $::instance_conf->get_reqdate_interval       :
                     $self->type eq SALES_ORDER_TYPE     ? $::instance_conf->get_delivery_date_interval : 1;

    if (   ($self->type eq SALES_ORDER_TYPE     &&  !$::instance_conf->get_deliverydate_on)
        || ($self->type eq SALES_QUOTATION_TYPE &&  !$::instance_conf->get_reqdate_on)) {
      return '';
    } else {
      return DateTime->today_local->next_workday(extra_days => $extra_days);
    }
  } else {
    return $reqdate;
  }
}
