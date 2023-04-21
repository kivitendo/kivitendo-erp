package SL::DB::DeliveryOrder::TypeData;

use strict;
use Carp;
use Exporter qw(import);
use SL::Locale::String qw(t8);

use constant {
  SALES_DELIVERY_ORDER_TYPE    => 'sales_delivery_order',
  PURCHASE_DELIVERY_ORDER_TYPE => 'purchase_delivery_order',
  SUPPLIER_DELIVERY_ORDER_TYPE => 'supplier_delivery_order',
  RMA_DELIVERY_ORDER_TYPE      => 'rma_delivery_order',
};

my @export_types = qw(SALES_DELIVERY_ORDER_TYPE PURCHASE_DELIVERY_ORDER_TYPE SUPPLIER_DELIVERY_ORDER_TYPE RMA_DELIVERY_ORDER_TYPE);
my @export_subs = qw(valid_types validate_type is_valid_type get get3);

our @EXPORT_OK = (@export_types, @export_subs);
our %EXPORT_TAGS = (types => \@export_types, subs => \@export_subs);

my %type_data = (
  SALES_DELIVERY_ORDER_TYPE() => {
    text => {
      delete => t8('Delivery Order has been deleted'),
      saved  => t8('Delivery Order has been saved'),
      add    => t8("Add Sales Delivery Order"),
      edit   => t8("Edit Sales Delivery Order"),
      attachment => t8("sales_delivery_order_list"),
    },
    show_menu => {
      save_and_ap_transaction => 0,
      save_and_invoice        => 0,
      delete                  => sub { $::instance_conf->get_sales_delivery_order_show_delete },
      new_controller          => 0,
    },
    properties => {
      customervendor => "customer",
      is_customer    => 1,
      nr_key         => "donumber",
      transfer       => 'out',
      transnumber    => 'sdonumber',
    },
    defaults => {
      reqdate => sub {
        DateTime->today_local->next_workday(extra_days => 1);
      },
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    rights => {
      edit => "sales_delivery_order_edit",
      view => "sales_delivery_order_edit | sales_delivery_order_view",
    },
    features => {
      price_tax   => 0,
      stock       => 1,
      subversions => 0,
    },
  },
  PURCHASE_DELIVERY_ORDER_TYPE() => {
    text => {
      delete => t8('Delivery Order has been deleted'),
      saved  => t8('Delivery Order has been saved'),
      add    => t8("Add Purchase Delivery Order"),
      edit   => t8("Edit Purchase Delivery Order"),
      attachment => t8("purchase_delivery_order_list"),
    },
    show_menu => {
      save_and_ap_transaction => 0,
      save_and_invoice        => 0,
      delete                  => sub { $::instance_conf->get_sales_delivery_order_show_delete },
      new_controller          => 0,
    },
    properties => {
      customervendor => "vendor",
      is_customer    => 0,
      nr_key         => "donumber",
      transfer       => 'in',
      transnumber    => 'pdonumber',
    },
    defaults => {
      reqdate => sub {
        DateTime->today_local->next_workday(extra_days => 1);
      },
    },
    part_classification_query => [ "used_for_purchase" => 1 ],
    rights => {
      edit => "purchase_delivery_order_edit",
      view => "purchase_delivery_order_edit | purchase_delivery_order_view",
    },
    features => {
      price_tax   => 0,
      stock       => 1,
      subversions => 0,
    },
  },
  SUPPLIER_DELIVERY_ORDER_TYPE() => {
    text => {
      delete => t8('Supplier Delivery Order has been deleted'),
      saved  => t8('Supplier Delivery Order has been saved'),
      add    => t8("Add Supplier Delivery Order"),
      edit   => t8("Edit Supplier Delivery Order"),
      attachment => t8("supplier_delivery_order_list"),
    },
    show_menu => {
      save_and_ap_transaction => 0,
      save_and_invoice        => 0,
      delete                  => sub { $::instance_conf->get_sales_delivery_order_show_delete },
      new_controller          => 1,
    },
    properties => {
      customervendor => "vendor",
      is_customer    => 0,
      nr_key         => "donumber",
      transfer       => 'out',
      transnumber    => 'sudonumber',
    },
    defaults => {
      reqdate => sub {
        DateTime->today_local->next_workday(extra_days => 1);
      },
    },
    part_classification_query => [ "used_for_purchase" => 1 ],
    rights => {
      edit => "purchase_delivery_order_edit",
      view => "purchase_delivery_order_edit | purchase_delivery_order_view",
    },
    features => {
      price_tax   => 0,
      stock       => 1,
      subversions => 0,
    },
  },
  RMA_DELIVERY_ORDER_TYPE() => {
    text => {
      delete => t8('Delivery Order has been deleted'),
      saved  => t8('Delivery Order has been saved'),
      add    => t8("Add RMA Delivery Order"),
      edit   => t8("Edit RMA Delivery Order"),
      attachment => t8("rma_delivery_order_list"),
    },
    show_menu => {
      save_and_ap_transaction => 0,
      save_and_invoice        => 0,
      delete                  => sub { $::instance_conf->get_sales_delivery_order_show_delete },
      new_controller          => 1,
    },
    properties => {
      customervendor => "customer",
      is_customer    => 1,
      nr_key         => "donumber",
      transfer       => 'in',
      transnumber    => 'rdonumber',
    },
    defaults => {
      reqdate => sub {
        DateTime->today_local->next_workday(extra_days => 1);
      },
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    rights => {
      edit => "sales_delivery_order_edit",
      view => "sales_delivery_order_edit | sales_delivery_order_view",
    },
    features => {
      price_tax   => 0,
      stock       => 1,
      subversions => 0,
    },
  },
);

my @valid_types = (
  SALES_DELIVERY_ORDER_TYPE,
  PURCHASE_DELIVERY_ORDER_TYPE,
  SUPPLIER_DELIVERY_ORDER_TYPE,
  RMA_DELIVERY_ORDER_TYPE,
);

my %valid_types = map { $_ => $_ } @valid_types;

sub valid_types {
  \@valid_types;
}

sub is_valid_type {
  !!exists $type_data{$_[0]};
}

sub validate_type {
  my ($type) = @_;

  return $valid_types{$type} // croak "invalid type '$type'";
}

sub get {
  my ($type, $key) = @_;

  croak "invalid type '$type'" unless exists $type_data{$type};

  my $ret = $type_data{$type}->{$key} // die "unknown property '$key'";

  ref $ret eq 'CODE'
    ? $ret->()
    : $ret;
}

sub get3 {
  my ($type, $topic, $key) = @_;

  croak "invalid type '$type'" unless exists $type_data{$type};

  my $ret = $type_data{$type}{$topic}{$key} // croak "unknown property '$key' in topic '$topic' for type '$type'";

  ref $ret eq 'CODE'
    ? $ret->()
    : $ret;
}

1;
