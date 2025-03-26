package SL::DB::PurchaseInvoice::TypeData;

use strict;
use Carp;
use Exporter qw(import);
use SL::Locale::String qw(t8);

use constant {
  AP_TRANSACTION_TYPE              => 'ap_transaction',
  AP_TRANSACTION_STORNO_TYPE       => 'ap_transaction_storno',
  PURCHASE_INVOICE_TYPE            => 'purchase_invoice',
  PURCHASE_INVOICE_STORNO_TYPE     => 'purchase_invoice_storno',
  PURCHASE_CREDIT_NOTE_TYPE        => 'purchase_credit_note',
  PURCHASE_CREDIT_NOTE_STORNO_TYPE => 'purchase_credit_note_storno',
};

my @export_types = qw(
  AP_TRANSACTION_TYPE AP_TRANSACTION_STORNO_TYPE
  PURCHASE_INVOICE_TYPE PURCHASE_INVOICE_STORNO_TYPE
  PURCHASE_CREDIT_NOTE_TYPE PURCHASE_CREDIT_NOTE_STORNO_TYPE
);
my @export_subs = qw(valid_types validate_type is_valid_type get get3);

our @EXPORT_OK = (@export_types, @export_subs);
our %EXPORT_TAGS = (types => \@export_types, subs => \@export_subs);

# TODO types:
#  - 'ap_transaction',
#  - 'ap_transaction_storno',
#  - 'purchase_invoice_storno',
#  - 'purchase_credit_note_storno',
my %type_data = (
  PURCHASE_INVOICE_TYPE() => {
    text => {
      delete     => t8('The purchase invoice has been deleted'),
      list       => t8("Purchase Invoices"),
      add        => t8("Add Purchase Invoice"),
      edit       => t8("Edit Purchase Invoice"),
      type       => t8("Purchase Invoice"),
      abbreviation => t8('Invoice (one letter abbreviation)'),
    },
    show_menu => {
      purchase_reclamation => 1,
      use_as_new           => 1,
      # delete => sub { die "not implemented" },
    },
    properties => {
      customervendor => "vendor",
      is_customer    => 0,
      nr_key         => "invnumber",
      worflow_needed => 0,
      is_credit_note => 0,
      has_marge      => 0,
    },
    defaults => {
      # TODO
    },
    part_classification_query => [ "used_for_purchase" => 1 ],
    rights => {
      # TODO
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => 0,
    },
  },
  PURCHASE_CREDIT_NOTE_TYPE() => {
    text => {
      delete     => t8('The purchase credit note has been deleted'),
      list       => t8("Purchase Credit Notes"),
      add        => t8("Add Purchase Credit Note"),
      edit       => t8("Edit Purchase Credit Note"),
      type       => t8("Purchase Credit Note"),
      abbreviation => t8('Credit note (one letter abbreviation)'),
    },
    show_menu => {
      purchase_reclamation => 0,
      use_as_new           => 1,
      # delete => sub { die "not implemented" },
    },
    properties => {
      customervendor => "vendor",
      is_customer    => 0,
      nr_key         => "invnumber",
      worflow_needed => 0,
      is_credit_note => 1,
      has_marge      => 0,
    },
    defaults => {
      # TODO
    },
    part_classification_query => [ "used_for_purchase" => 1 ],
    rights => {
      # TODO
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => 0,
    },
  },
);

my @valid_types = (
  AP_TRANSACTION_TYPE,
  AP_TRANSACTION_STORNO_TYPE,
  PURCHASE_INVOICE_TYPE,
  PURCHASE_INVOICE_STORNO_TYPE,
  PURCHASE_CREDIT_NOTE_TYPE,
  PURCHASE_CREDIT_NOTE_STORNO_TYPE,
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
