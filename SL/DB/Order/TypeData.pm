package SL::DB::Order::TypeData;

use strict;
use Carp;
use Exporter qw(import);
use SL::Locale::String qw(t8);

use constant {
  SALES_ORDER_TYPE                 => 'sales_order',
  PURCHASE_ORDER_TYPE              => 'purchase_order',
  SALES_QUOTATION_TYPE             => 'sales_quotation',
  REQUEST_QUOTATION_TYPE           => 'request_quotation',
  PURCHASE_QUOTATION_INTAKE_TYPE   => 'purchase_quotation_intake',
  SALES_ORDER_INTAKE_TYPE          => 'sales_order_intake',
  PURCHASE_ORDER_CONFIRMATION_TYPE => 'purchase_order_confirmation',
};

my @export_types = qw(SALES_ORDER_TYPE PURCHASE_ORDER_TYPE REQUEST_QUOTATION_TYPE SALES_QUOTATION_TYPE
                      PURCHASE_QUOTATION_INTAKE_TYPE SALES_ORDER_INTAKE_TYPE PURCHASE_ORDER_CONFIRMATION_TYPE);
my @export_subs = qw(valid_types validate_type is_valid_type get get3);

our @EXPORT_OK = (@export_types, @export_subs);
our %EXPORT_TAGS = (types => \@export_types, subs => \@export_subs);

my %type_data = (
  SALES_ORDER_TYPE() => {
    text => {
      delete => t8('The order confirmation has been deleted'),
      saved  => t8('The order confirmation has been saved'),
      add    => t8("Add Sales Order"),
      edit   => t8("Edit Sales Order"),
      list   => t8("Sales Orders"),
      type   => t8("Sales Order"),
      attachment => t8("sales_order_list"),
    },
    show_menu => {
      save_and_quotation                   => 1,
      save_and_rfq                         => 1,
      save_and_purchase_quotation_intake   => 0,
      save_and_sales_order_intake          => 0,
      save_and_sales_order                 => 0,
      save_and_purchase_order              => 1,
      save_and_purchase_order_confirmation => 0,
      save_and_sales_delivery_order        => 1,
      save_and_purchase_delivery_order     => 0,
      save_and_supplier_delivery_order     => 0,
      save_and_reclamation                 => sub { $::instance_conf->get_show_sales_reclamation },
      save_and_invoice_for_advance_payment => sub { $::instance_conf->get_show_invoice_for_advance_payment },
      save_and_final_invoice               => sub { $::instance_conf->get_show_invoice_for_advance_payment },
      save_and_ap_transaction              => 0,
      save_and_invoice                     => 1,
      save_and_print                       => 1,
      save_and_email                       => 1,
      delete => sub { $::instance_conf->get_sales_order_show_delete },
    },
    properties => {
      customervendor => "customer",
      is_customer    => 1,
      nr_key         => "ordnumber",
      worflow_needed => 0,
    },
    defaults => {
      reqdate => sub {
        if ($::instance_conf->get_deliverydate_on) {
          return DateTime->today_local->next_workday(
            extra_days => $::instance_conf->get_delivery_date_interval());
        } else {
          return ;
        }
      },
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    no_order_locked_parts     => 0,
    rights => {
      edit => "sales_order_edit",
      view => "sales_order_edit | sales_order_view",
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => sub { $::instance_conf->get_lock_oe_subversions },
    },
  },
  PURCHASE_ORDER_TYPE() => {
    text => {
      delete => t8('The order has been deleted'),
      saved  => t8('The order has been saved'),
      add    => t8("Add Purchase Order"),
      edit   => t8("Edit Purchase Order"),
      list   => t8("Purchase Orders"),
      type   => t8("Purchase Order"),
      attachment => t8("purchase_order_list"),
    },
    show_menu => {
      save_and_quotation                   => 0,
      save_and_rfq                         => 1,
      save_and_purchase_quotation_intake   => 0,
      save_and_sales_order_intake          => 0,
      save_and_sales_order                 => 1,
      save_and_purchase_order              => 0,
      save_and_purchase_order_confirmation => sub { $::instance_conf->get_show_purchase_order_confirmation },
      save_and_sales_delivery_order        => 0,
      save_and_purchase_delivery_order     => 1,
      save_and_supplier_delivery_order     => 1,
      save_and_reclamation                 => sub { $::instance_conf->get_show_purchase_reclamation },
      save_and_invoice_for_advance_payment => 0,
      save_and_final_invoice               => 0,
      save_and_ap_transaction              => 1,
      save_and_invoice                     => 1,
      save_and_print                       => 1,
      save_and_email                       => 1,
      delete => sub { $::instance_conf->get_purchase_order_show_delete },
    },
    properties => {
      customervendor => "vendor",
      is_customer    => 0,
      nr_key         => "ordnumber",
      worflow_needed => 0,
    },
    defaults => {
      reqdate => sub { return; },
    },
    part_classification_query => [ "used_for_purchase" => 1 ],
    no_order_locked_parts     => 1,
    rights => {
      edit => "purchase_order_edit",
      view => "purchase_order_edit | purchase_order_view",
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => sub { $::instance_conf->get_lock_oe_subversions },
    },
  },
  SALES_QUOTATION_TYPE() => {
    text => {
      delete => t8('The quotation has been deleted'),
      saved  => t8('The quotation has been saved'),
      add    => t8("Add Quotation"),
      edit   => t8("Edit Quotation"),
      list   => t8("Quotations"),
      type   => t8("Quotation"),
      attachment => t8("quotation_list"),
    },
    show_menu => {
      save_and_quotation                   => 0,
      save_and_rfq                         => 1,
      save_and_purchase_quotation_intake   => 0,
      save_and_sales_order_intake          => sub { $::instance_conf->get_show_sales_order_intake },
      save_and_sales_order                 => 1,
      save_and_purchase_order              => 0,
      save_and_purchase_order_confirmation => 0,
      save_and_sales_delivery_order        => 0,
      save_and_purchase_delivery_order     => 0,
      save_and_supplier_delivery_order     => 0,
      save_and_reclamation                 => 0,
      save_and_invoice_for_advance_payment => 0,
      save_and_final_invoice               => 0,
      save_and_ap_transaction              => 0,
      save_and_invoice                     => 1,
      save_and_print                       => 1,
      save_and_email                       => 1,
      delete => 1,
    },
    properties => {
      customervendor => "customer",
      is_customer    => 1,
      nr_key         => "quonumber",
      worflow_needed => 0,
    },
    defaults => {
      reqdate => sub {
        if ($::instance_conf->get_reqdate_on) {
          return DateTime->today_local->next_workday(
            extra_days => $::instance_conf->get_reqdate_interval());
        } else {
          return ;
        }
      },
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    no_order_locked_parts     => 0,
    rights => {
      edit => "sales_quotation_edit",
      view => "sales_quotation_edit | sales_quotation_view",
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => sub { $::instance_conf->get_lock_oe_subversions },
    },
  },
  REQUEST_QUOTATION_TYPE() => {
    text => {
      delete => t8('The rfq has been deleted'),
      saved  => t8('The rfq has been saved'),
      add    => t8("Add Request for Quotation"),
      edit   => t8("Edit Request for Quotation"),
      list   => t8("Request for Quotations"),
      type   => t8("Request for Quotation"),
      attachment => t8("rfq_list"),
    },
    show_menu => {
      save_and_quotation                   => 1,
      save_and_rfq                         => 0,
      save_and_purchase_quotation_intake   => sub { $::instance_conf->get_show_purchase_quotation_intake },
      save_and_sales_order_intake          => 0,
      save_and_sales_order                 => 1,
      save_and_purchase_order              => 1,
      save_and_purchase_order_confirmation => 0,
      save_and_sales_delivery_order        => 0,
      save_and_purchase_delivery_order     => 0,
      save_and_supplier_delivery_order     => 0,
      save_and_reclamation                 => 0,
      save_and_invoice_for_advance_payment => 0,
      save_and_final_invoice               => 0,
      save_and_ap_transaction              => 0,
      save_and_invoice                     => 1,
      save_and_print                       => 1,
      save_and_email                       => 1,
      delete => 1,
    },
    properties => {
      customervendor => "vendor",
      is_customer    => 0,
      nr_key         => "quonumber",
      worflow_needed => 0,
    },
    defaults => {
      reqdate => sub { return; },
    },
    part_classification_query => [ "used_for_purchase" => 1 ],
    no_order_locked_parts     => 1,
    rights => {
      edit => "request_quotation_edit",
      view => "request_quotation_edit | request_quotation_view",
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => sub { $::instance_conf->get_lock_oe_subversions },
    },
  },
  PURCHASE_QUOTATION_INTAKE_TYPE() => {
    text => {
      delete     => t8('The quotation intake has been deleted'),
      saved      => t8('The quotation intake has been saved'),
      add        => t8('Add Purchase Quotation Intake'),
      edit       => t8('Edit Purchase Quotation Intake'),
      list       => t8('Purchase Quotation Intakes'),
      type       => t8('Purchase Quotation Intake'),
      attachment => t8('purchase_quotation_intake_list'),
    },
    show_menu => {
      save_and_quotation                   => 1,
      save_and_rfq                         => 0,
      save_and_purchase_quotation_intake   => 0,
      save_and_sales_order_intake          => 0,
      save_and_sales_order                 => 1,
      save_and_purchase_order              => 1,
      save_and_purchase_order_confirmation => 0,
      save_and_sales_delivery_order        => 0,
      save_and_purchase_delivery_order     => 0,
      save_and_supplier_delivery_order     => 0,
      save_and_reclamation                 => 0,
      save_and_invoice_for_advance_payment => 0,
      save_and_final_invoice               => 0,
      save_and_ap_transaction              => 0,
      save_and_invoice                     => 0,
      save_and_print                       => 1,
      save_and_email                       => 1,
      delete => 1,
    },
    properties => {
      customervendor => "vendor",
      is_customer    => 0,
      nr_key         => "quonumber",
      worflow_needed => 0,
    },
    defaults => {
      reqdate => sub { return; },
    },
    part_classification_query => [ "used_for_purchase" => 1 ],
    no_order_locked_parts     => 0,
    rights => {
      edit => "request_quotation_edit",
      view => "request_quotation_edit | request_quotation_view",
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => sub { $::instance_conf->get_lock_oe_subversions },
    },
  },
  SALES_ORDER_INTAKE_TYPE() => {
    text => {
      delete => t8('The order intake has been deleted'),
      saved  => t8('The order intake has been saved'),
      add    => t8("Add Sales Order Intake"),
      edit   => t8("Edit Sales Order Intake"),
      list   => t8("Sales Order Intakes"),
      type   => t8("Sales Order Intake"),
      attachment => t8("sales_order_intake_list"),
    },
    show_menu => {
      save_and_quotation                   => 1,
      save_and_rfq                         => 1,
      save_and_purchase_quotation_intake   => 0,
      save_and_sales_order_intake          => 0,
      save_and_sales_order                 => 1,
      save_and_purchase_order              => 1,
      save_and_purchase_order_confirmation => 0,
      save_and_sales_delivery_order        => 0,
      save_and_purchase_delivery_order     => 0,
      save_and_supplier_delivery_order     => 0,
      save_and_reclamation                 => 0,
      save_and_invoice_for_advance_payment => 0,
      save_and_final_invoice               => 0,
      save_and_ap_transaction              => 0,
      save_and_invoice                     => 0,
      save_and_print                       => 1,
      save_and_email                       => 1,
      delete => sub { $::instance_conf->get_sales_order_show_delete },
    },
    properties => {
      customervendor => "customer",
      is_customer    => 1,
      nr_key         => "ordnumber",
      worflow_needed => 0,
    },
    defaults => {
      reqdate => sub {
        if ($::instance_conf->get_deliverydate_on) {
          return DateTime->today_local->next_workday(
            extra_days => $::instance_conf->get_delivery_date_interval());
        } else {
          return ;
        }
      },
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    no_order_locked_parts     => 0,
    rights => {
      edit => "sales_order_edit",
      view => "sales_order_edit | sales_order_view",
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => sub { $::instance_conf->get_lock_oe_subversions },
    },
  },
  PURCHASE_ORDER_CONFIRMATION_TYPE() => {
    text => {
      delete => t8('The order confirmation has been deleted'),
      saved  => t8('The order confirmation has been saved'),
      add    => t8("Add Purchase Order Confirmation"),
      edit   => t8("Edit Purchase Order Confirmation"),
      list   => t8("Purchase Order Confirmations"),
      type   => t8("Purchase Order Confirmation"),
      attachment => t8("purchase_order_confirmation_list"),
    },
    show_menu => {
      save_and_quotation                   => 1,
      save_and_rfq                         => 0,
      save_and_purchase_quotation_intake   => 0,
      save_and_sales_order_intake          => 0,
      save_and_sales_order                 => 1,
      save_and_purchase_order              => 1,
      save_and_purchase_order_confirmation => 0,
      save_and_sales_delivery_order        => 0,
      save_and_purchase_delivery_order     => 1,
      save_and_supplier_delivery_order     => 1,
      save_and_reclamation                 => sub { $::instance_conf->get_show_purchase_reclamation },
      save_and_invoice_for_advance_payment => 0,
      save_and_final_invoice               => 0,
      save_and_ap_transaction              => 1,
      save_and_invoice                     => 1,
      save_and_print                       => 0,
      save_and_email                       => 0,
      delete => sub { $::instance_conf->get_purchase_order_show_delete },
    },
    properties => {
      customervendor => "vendor",
      is_customer    => 0,
      nr_key         => "ordnumber",
      worflow_needed => 0,
    },
    defaults => {
      reqdate => sub { return; },
    },
    part_classification_query => [ "used_for_purchase" => 1 ],
    no_order_locked_parts     => 0,
    rights => {
      edit => "purchase_order_edit",
      view => "purchase_order_edit | sales_order_view",
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => sub { $::instance_conf->get_lock_oe_subversions },
    },
  },
);

my @valid_types = (
  SALES_QUOTATION_TYPE,
  REQUEST_QUOTATION_TYPE,
  SALES_ORDER_INTAKE_TYPE,
  PURCHASE_QUOTATION_INTAKE_TYPE,
  SALES_ORDER_TYPE,
  PURCHASE_ORDER_TYPE,
  PURCHASE_ORDER_CONFIRMATION_TYPE,
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

__END__

todo:

features:
- price_tax_calculation
- subversioning for sales_orders
- final invoices for sales_orders
- payment_terms
- periodic invoices for some types
- auto close quotations for some types
-
