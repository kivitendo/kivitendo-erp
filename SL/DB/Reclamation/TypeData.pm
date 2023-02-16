package SL::DB::Reclamation::TypeData;

use strict;
use Carp;
use Exporter qw(import);
use SL::Locale::String qw(t8);

use constant {
  SALES_RECLAMATION_TYPE    => 'sales_reclamation',
  PURCHASE_RECLAMATION_TYPE => 'purchase_reclamation',
};

my @export_types = qw(SALES_RECLAMATION_TYPE PURCHASE_RECLAMATION_TYPE);
my @export_subs = qw(valid_types validate_type is_valid_type get get3);

our @EXPORT_OK = (@export_types, @export_subs);
our %EXPORT_TAGS = (types => \@export_types, subs => \@export_subs);

my %type_data = (
  SALES_RECLAMATION_TYPE() => {
    text => {
      list       => t8("Sales Reclamations"),
      add        => t8("Add Sales Reclamation"),
      edit       => t8("Edit Sales Reclamation"),
    },
    show_menu => {
      save_and_sales_reclamation       => 0,
      save_and_purchase_reclamation    => 1,
      save_and_rma_delivery_order      => 1,
      save_and_supplier_delivery_order => 0,
      save_and_credit_note             => 1,
      delete                           => sub { $::instance_conf->get_sales_reclamation_show_delete },
    },
    properties => {
      customervendor => "customer",
      is_customer    => 1,
      nr_key         => "record_number",
    },
    defaults => {
      reqdate => sub { return; },
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    rights => {
      edit => "sales_reclamation_edit",
    },
    features => {
      price_tax => 1,
      stock     => 0,
    },
  },
  PURCHASE_RECLAMATION_TYPE() => {
    text => {
      list       => t8("Purchase Reclamations"),
      add        => t8("Add Purchase Reclamation"),
      edit       => t8("Edit Purchase Reclamation"),
    },
    show_menu => {
      save_and_sales_reclamation       => 1,
      save_and_purchase_reclamation    => 0,
      save_and_rma_delivery_order      => 0,
      save_and_supplier_delivery_order => 1,
      save_and_credit_note             => 0,
      delete                           => sub { $::instance_conf->get_purchase_reclamation_show_delete },
    },
    properties => {
      customervendor => "vendor",
      is_customer    => 0,
      nr_key         => "record_number",
    },
    defaults => {
      reqdate => sub { return; },
    },
    part_classification_query => [ "used_for_purchase" => 1 ],
    rights => {
      edit => "purchase_reclamation_edit",
    },
    features => {
      price_tax => 1,
      stock     => 0,
    },
  },
);

my @valid_types = (
  SALES_RECLAMATION_TYPE,
  PURCHASE_RECLAMATION_TYPE,
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
