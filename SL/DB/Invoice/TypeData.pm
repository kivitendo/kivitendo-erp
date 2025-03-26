package SL::DB::Invoice::TypeData;

use strict;
use Carp;
use Exporter qw(import);
use SL::Locale::String qw(t8);

use constant {
  INVOICE_TYPE                            =>  'invoice',
  INVOICE_FOR_ADVANCE_PAYMENT_TYPE        =>  'invoice_for_advance_payment',
  INVOICE_FOR_ADVANCE_PAYMENT_STORNO_TYPE =>  'invoice_for_advance_payment_storno',
  FINAL_INVOICE_TYPE                      =>  'final_invoice',
  INVOICE_STORNO_TYPE                     =>  'invoice_storno',
  CREDIT_NOTE_TYPE                        =>  'credit_note',
  CREDIT_NOTE_STORNO_TYPE                 =>  'credit_note_storno',
};

my @export_types = qw(
  INVOICE_TYPE INVOICE_FOR_ADVANCE_PAYMENT_TYPE
  INVOICE_FOR_ADVANCE_PAYMENT_STORNO_TYPE FINAL_INVOICE_TYPE INVOICE_STORNO_TYPE
  CREDIT_NOTE_TYPE CREDIT_NOTE_STORNO_TYPE
);
my @export_subs = qw(valid_types validate_type is_valid_type get get3);

our @EXPORT_OK = (@export_types, @export_subs);
our %EXPORT_TAGS = (types => \@export_types, subs => \@export_subs);

my %type_data = (
  INVOICE_TYPE() => {
    text => {
      delete     => t8('The invoice has been deleted'),
      list       => t8("Invoices"),
      add        => t8("Add Invoice"),
      edit       => t8("Edit Invoice"),
      type       => t8("Invoice"),
    },
    show_menu => {
      invoice_for_advance_payment => 0,
      final_invoice               => 0,
      credit_note                 => 1,
      sales_order                 => 1,
      sales_reclamation           => 1,
      use_as_new => 1,
      # delete     => sub { die "not implemented" },
    },
    properties => {
      customervendor => "customer",
      is_customer    => 1,
      nr_key         => "invnumber",
      worflow_needed => 0,
      is_credit_note => 0,
      has_marge      => 1,
    },
    defaults => {
      # TODO
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    rights => {
      # TODO
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => 0,
    },
  },
  INVOICE_FOR_ADVANCE_PAYMENT_TYPE() => {
    text => {
      delete     => t8('The invoice for advance payment has been deleted'),
      list       => t8("Invoices for Advance Payment"),
      add        => t8("Add Invoice for Advance Payment"),
      edit       => t8("Edit Invoice for Advance Payment"),
      type       => t8("Invoice for Advance Payment"),
    },
    show_menu => {
      invoice_for_advance_payment => 1,
      final_invoice               => 1,
      credit_note                 => 1,
      sales_order                 => 1,
      sales_reclamation           => 0,
      use_as_new => 1,
      # delete     => sub { die "not implemented" },
    },
    properties => {
      customervendor => "customer",
      is_customer    => 1,
      nr_key         => "invnumber",
      worflow_needed => 0,
      is_credit_note => 0,
      has_marge      => 1,
    },
    defaults => {
      # TODO
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    rights => {
      # TODO
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => 0,
    },
  },
  INVOICE_FOR_ADVANCE_PAYMENT_STORNO_TYPE() => {
    text => {
      delete     => t8('The strono invoice for advance payment has been deleted'),
      list       => t8("Storno Invoices for Advance Payment"),
      add        => t8("Add Storno Invoice for Advance Payment"),
      edit       => t8("Edit Storno Invoice for Advance Payment"),
      type       => t8("Storno Invoice for Advance Payment"),
    },
    show_menu => {
      invoice_for_advance_payment => 0,
      final_invoice               => 0,
      credit_note                 => 1,
      sales_order                 => 1,
      sales_reclamation           => 0,
      use_as_new => 1,
      # delete     => sub { die "not implemented" },
    },
    properties => {
      customervendor => "customer",
      is_customer    => 1,
      nr_key         => "invnumber",
      worflow_needed => 1,
      is_credit_note => 0,
      has_marge      => 0,
    },
    defaults => {
      # TODO
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    rights => {
      # TODO
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => 0,
    },
  },
  FINAL_INVOICE_TYPE() => {
    text => {
      delete     => t8('The final invoice has been deleted'),
      list       => t8("Final Invoices"),
      add        => t8("Add Final Invoice"),
      edit       => t8("Edit Final Invoice"),
      type       => t8("Final Invoice"),
    },
    show_menu => {
      invoice_for_advance_payment => 0,
      final_invoice               => 0,
      credit_note                 => 1,
      sales_order                 => 1,
      sales_reclamation           => 0,
      use_as_new => 1,
      # delete     => sub { die "not implemented" },
    },
    properties => {
      customervendor => "customer",
      is_customer    => 1,
      nr_key         => "invnumber",
      worflow_needed => 1,
      is_credit_note => 0,
      has_marge      => 1,
    },
    defaults => {
      # TODO
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    rights => {
      # TODO
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => 0,
    },
  },
  INVOICE_STORNO_TYPE() => {
    text => {
      delete     => t8('The storno invoice has been deleted'),
      list       => t8("Storno Invoices"),
      add        => t8("Add Storno Invoice"),
      edit       => t8("Edit Storno Invoice"),
      type       => t8("Storno Invoice"),
    },
    show_menu => {
      invoice_for_advance_payment => 0,
      final_invoice               => 0,
      credit_note                 => 1,
      sales_order                 => 1,
      sales_reclamation           => 0,
      use_as_new => 1,
      # delete     => sub { die "not implemented" },
    },
    properties => {
      customervendor => "customer",
      is_customer    => 1,
      nr_key         => "invnumber",
      worflow_needed => 1,
      is_credit_note => 0,
      has_marge      => 0,
    },
    defaults => {
      # TODO
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    rights => {
      # TODO
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => 0,
    },
  },
  CREDIT_NOTE_TYPE() => {
    text => {
      delete     => t8('The credit note has been deleted'),
      list       => t8("Credit Notes"),
      add        => t8("Add Credit Note"),
      edit       => t8("Edit Credit Note"),
      type       => t8("Credit Note"),
    },
    show_menu => {
      invoice_for_advance_payment => 0,
      final_invoice               => 0,
      credit_note                 => 1,
      sales_order                 => 1,
      sales_reclamation           => 0,
      use_as_new => 1,
      # delete     => sub { die "not implemented" },
    },
    properties => {
      customervendor => "customer",
      is_customer    => 1,
      nr_key         => "invnumber",
      worflow_needed => 0,
      is_credit_note => 1,
      has_marge      => 0,
    },
    defaults => {
      # TODO
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    rights => {
      # TODO
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => 0,
    },
  },
  CREDIT_NOTE_STORNO_TYPE() => {
    text => {
      delete     => t8('The storno credit note has been deleted'),
      list       => t8("Storno Credit Notes"),
      add        => t8("Add Storno Credit Note"),
      edit       => t8("Edit Storno Credit Note"),
      type       => t8("Storno Credit Note"),
    },
    show_menu => {
      invoice_for_advance_payment => 0,
      final_invoice               => 0,
      credit_note                 => 1,
      sales_order                 => 1,
      sales_reclamation           => 0,
      use_as_new => 1,
      # delete     => sub { die "not implemented" },
    },
    properties => {
      customervendor => "customer",
      is_customer    => 1,
      nr_key         => "invnumber",
      worflow_needed => 1,
      is_credit_note => 1,
      has_marge      => 0,
    },
    defaults => {
      # TODO
    },
    part_classification_query => [ "used_for_sale" => 1 ],
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
  INVOICE_TYPE,
  INVOICE_FOR_ADVANCE_PAYMENT_TYPE,
  INVOICE_FOR_ADVANCE_PAYMENT_STORNO_TYPE,
  FINAL_INVOICE_TYPE,
  INVOICE_STORNO_TYPE,
  CREDIT_NOTE_TYPE,
  CREDIT_NOTE_STORNO_TYPE,
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
