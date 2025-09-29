package SL::DB::Invoice::TypeData;

use strict;
use Carp;
use Exporter qw(import);
use SL::Locale::String qw(t8);

use constant {
  AR_TRANSACTION_TYPE                     =>  'ar_transaction',
  AR_TRANSACTION_STORNO_TYPE              =>  'ar_transaction_storno',
  INVOICE_TYPE                            =>  'invoice',
  INVOICE_STORNO_TYPE                     =>  'invoice_storno',
  INVOICE_FOR_ADVANCE_PAYMENT_TYPE        =>  'invoice_for_advance_payment',
  INVOICE_FOR_ADVANCE_PAYMENT_STORNO_TYPE =>  'invoice_for_advance_payment_storno',
  FINAL_INVOICE_TYPE                      =>  'final_invoice',
  CREDIT_NOTE_TYPE                        =>  'credit_note',
  CREDIT_NOTE_STORNO_TYPE                 =>  'credit_note_storno',
};

my @export_types = qw(
  AR_TRANSACTION_TYPE AR_TRANSACTION_STORNO_TYPE
  INVOICE_TYPE INVOICE_STORNO_TYPE
  INVOICE_FOR_ADVANCE_PAYMENT_TYPE INVOICE_FOR_ADVANCE_PAYMENT_STORNO_TYPE
  FINAL_INVOICE_TYPE
  CREDIT_NOTE_TYPE CREDIT_NOTE_STORNO_TYPE
);
my @export_subs = qw(valid_types validate_type is_valid_type get get3);

our @EXPORT_OK = (@export_types, @export_subs);
our %EXPORT_TAGS = (types => \@export_types, subs => \@export_subs);

my %type_data = (
  AR_TRANSACTION_TYPE() => {
    text => {
      delete       => t8("The ar transaction has been deleted"),
      posted       => t8("The ar transaction has been posted"),
      list         => t8("AR Transactions"),
      add          => t8("Add AR Transaction"),
      edit         => t8("Edit AR Transaction"),
      type         => t8("AR Transaction"),
      abbreviation => t8("AR Transaction (abbreviation)"),
    },
    show_menu => {
      post_payment                => 0,
      mark_as_paid                => 0,
      advance_payment             => 0,
      credit_note                 => 0,
      reclamation                 => 0,
    },
    properties => {
      customervendor => "customer",
      is_invoice     => 0,
      is_customer    => 1,
      nr_key         => "invnumber",
      worflow_needed => 0,
      is_credit_note => 0,
      has_marge      => 0,
      show_serialno  => 1,
      show_reqdate   => 1,
    },
    defaults => {
      duedate => sub { DateTime->today_local },
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    rights => {
      view => 'ar_transactions',
      edit => 'ar_transactions',
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => 0,
    },
  },
  AR_TRANSACTION_STORNO_TYPE() => {
    text => {
      delete       => t8("The storno ar transaction has been deleted"),
      posted       => t8("The storno ar transaction has been posted"),
      list         => t8("Storno AR Transactions"),
      add          => t8("Add Storno AR Transaction"),
      edit         => t8("Edit Storno AR Transaction"),
      type         => t8("Storno AR Transaction"),
      abbreviation => t8("Storno (one letter abbreviation)"),
    },
    show_menu => {
      post_payment                => 0,
      mark_as_paid                => 0,
      advance_payment             => 0,
      credit_note                 => 0,
      reclamation                 => 0,
    },
    properties => {
      customervendor => "customer",
      is_invoice     => 0,
      is_customer    => 1,
      nr_key         => "invnumber",
      worflow_needed => 1,
      is_credit_note => 0,
      has_marge      => 0,
      show_serialno  => 1,
      show_reqdate   => 1,
    },
    defaults => {
      duedate => sub { DateTime->today_local },
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    rights => {
      view => 'ar_transactions',
      edit => 'ar_transactions',
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => 0,
    },
  },
  INVOICE_TYPE() => {
    text => {
      delete       => t8("The invoice has been deleted"),
      posted       => t8("The invoice has been posted"),
      list         => t8("Invoices"),
      add          => t8("Add Invoice"),
      edit         => t8("Edit Invoice"),
      type         => t8("Invoice"),
      abbreviation => t8("Invoice (one letter abbreviation)"),
    },
    show_menu => {
      invoice_for_advance_payment => 0,
      final_invoice               => 0,
      credit_note                 => 1,
      sales_order                 => 1,
      sales_reclamation           => 1,
      use_as_new => 1,
      # delete     => sub { die "not implemented" },
      post_payment                => 1,
      mark_as_paid                => sub { $::instance_conf->get_is_show_mark_as_paid },
      advance_payment             => 0,
      credit_note                 => 0,
      reclamation                 => sub { $::instance_conf->get_show_sales_reclamation },
    },
    properties => {
      customervendor => "customer",
      is_invoice     => 1,
      is_customer    => 1,
      nr_key         => "invnumber",
      worflow_needed => 0,
      is_credit_note => 0,
      has_marge      => 1,
      show_serialno  => 1,
      show_reqdate   => 1,
    },
    defaults => {
      duedate => sub { },
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    rights => {
      view => 'sales_invoice_view',
      edit => 'invoice_edit' ,
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => 0,
    },
  },
  INVOICE_FOR_ADVANCE_PAYMENT_TYPE() => {
    text => {
      delete       => t8("The invoice for advance payment has been deleted"),
      posted       => t8("The invoice for advance payment has been posted"),
      list         => t8("Invoices for Advance Payment"),
      add          => t8("Add Invoice for Advance Payment"),
      edit         => t8("Edit Invoice for Advance Payment"),
      type         => t8("Invoice for Advance Payment"),
      abbreviation => t8("Invoice for Advance Payment (one letter abbreviation)"),
    },
    show_menu => {
      invoice_for_advance_payment => 1,
      final_invoice               => 1,
      credit_note                 => 1,
      sales_order                 => 1,
      sales_reclamation           => 0,
      use_as_new => 1,
      # delete     => sub { die "not implemented" },
      post_payment                => 0,
      mark_as_paid                => 0,
      advance_payment             => 1,
      credit_note                 => 0,
      reclamation                 => 0,
    },
    properties => {
      customervendor => "customer",
      is_invoice     => 1,
      is_customer    => 1,
      nr_key         => "invnumber",
      worflow_needed => 0,
      is_credit_note => 0,
      has_marge      => 1,
      show_serialno  => 1,
      show_reqdate   => 1,
    },
    defaults => {
      duedate => sub { },
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    rights => {
      view => 'sales_invoice_view',
      edit => 'invoice_edit',
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => 0,
    },
  },
  INVOICE_FOR_ADVANCE_PAYMENT_STORNO_TYPE() => {
    text => {
      delete       => t8("The storno invoice for advance payment has been deleted"),
      posted       => t8("The storno invoice for advance payment has been posted"),
      list         => t8("Storno Invoices for Advance Payment"),
      add          => t8("Add Storno Invoice for Advance Payment"),
      edit         => t8("Edit Storno Invoice for Advance Payment"),
      type         => t8("Storno Invoice for Advance Payment"),
      abbreviation => t8("Storno (one letter abbreviation)"),
    },
    show_menu => {
      invoice_for_advance_payment => 0,
      final_invoice               => 0,
      credit_note                 => 1,
      sales_order                 => 1,
      sales_reclamation           => 0,
      use_as_new => 1,
      # delete     => sub { die "not implemented" },
      post_payment                => 1,
      mark_as_paid                => sub { $::instance_conf->get_is_show_mark_as_paid },
      advance_payment             => sub { $::instance_conf->get_show_invoice_for_advance_payment },
      credit_note                 => 0,
      reclamation                 => 0,
    },
    properties => {
      customervendor => "customer",
      is_invoice     => 1,
      is_customer    => 1,
      nr_key         => "invnumber",
      worflow_needed => 1,
      is_credit_note => 0,
      has_marge      => 0,
      show_serialno  => 1,
      show_reqdate   => 1,
    },
    defaults => {
      duedate => sub { },
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    rights => {
      view => 'sales_invoice_view',
      edit => 'invoice_edit',
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => 0,
    },
  },
  FINAL_INVOICE_TYPE() => {
    text => {
      delete       => t8("The final invoice has been deleted"),
      posted       => t8("The final invoice has been posted"),
      list         => t8("Final Invoices"),
      add          => t8("Add Final Invoice"),
      edit         => t8("Edit Final Invoice"),
      type         => t8("Final Invoice"),
      abbreviation => t8("Final Invoice (one letter abbreviation)"),
    },
    show_menu => {
      invoice_for_advance_payment => 0,
      final_invoice               => 0,
      credit_note                 => 1,
      sales_order                 => 1,
      sales_reclamation           => 0,
      use_as_new => 1,
      # delete     => sub { die "not implemented" },
      post_payment                => 1,
      mark_as_paid                => 1,
      advance_payment             => 0,
      credit_note                 => 0,
      reclamation                 => 0,
    },
    properties => {
      customervendor => "customer",
      is_invoice     => 1,
      is_customer    => 1,
      nr_key         => "invnumber",
      worflow_needed => 1,
      is_credit_note => 0,
      has_marge      => 1,
      show_serialno  => 1,
      show_reqdate   => 1,
    },
    defaults => {
      duedate => sub { },
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    rights => {
      view => 'sales_invoice_view',
      edit => 'invoice_edit',
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => 0,
    },
  },
  INVOICE_STORNO_TYPE() => {
    text => {
      delete       => t8("The storno invoice has been deleted"),
      posted       => t8("The storno invoice has been posted"),
      list         => t8("Storno Invoices"),
      add          => t8("Add Storno Invoice"),
      edit         => t8("Edit Storno Invoice"),
      type         => t8("Storno Invoice"),
      abbreviation => t8("Storno (one letter abbreviation)"),
    },
    show_menu => {
      invoice_for_advance_payment => 0,
      final_invoice               => 0,
      credit_note                 => 1,
      sales_order                 => 1,
      sales_reclamation           => 0,
      use_as_new => 1,
      # delete     => sub { die "not implemented" },
      post_payment                => 1,
      mark_as_paid                => sub { $::instance_conf->get_is_show_mark_as_paid },
      advance_payment             => 0,
      credit_note                 => 0,
      reclamation                 => 0,
    },
    properties => {
      customervendor => "customer",
      is_invoice     => 1,
      is_customer    => 1,
      nr_key         => "invnumber",
      worflow_needed => 1,
      is_credit_note => 0,
      has_marge      => 0,
      show_serialno  => 1,
      show_reqdate   => 1,
    },
    defaults => {
      duedate => sub { },
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    rights => {
      view => 'sales_invoice_view',
      edit => 'invoice_edit',
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => 0,
    },
  },
  CREDIT_NOTE_TYPE() => {
    text => {
      delete       => t8("The credit note has been deleted"),
      posted       => t8("The credit note has been posted"),
      list         => t8("Credit Notes"),
      add          => t8("Add Credit Note"),
      edit         => t8("Edit Credit Note"),
      type         => t8("Credit Note"),
      abbreviation => t8("Credit note (one letter abbreviation)"),
    },
    show_menu => {
      invoice_for_advance_payment => 0,
      final_invoice               => 0,
      credit_note                 => 1,
      sales_order                 => 1,
      sales_reclamation           => 0,
      use_as_new => 1,
      # delete     => sub { die "not implemented" },
      post_payment                => 1,
      mark_as_paid                => sub { $::instance_conf->get_is_show_mark_as_paid },
      advance_payment             => 0,
      credit_note                 => 0,
      reclamation                 => 0,
    },
    properties => {
      customervendor => "customer",
      is_invoice     => 1,
      is_customer    => 1,
      nr_key         => "invnumber",
      worflow_needed => 0,
      is_credit_note => 1,
      has_marge      => 0,
      show_serialno  => 1,
      show_reqdate   => 1,
    },
    defaults => {
      duedate => sub { },
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    rights => {
      view => 'sales_invoice_view',
      edit => 'invoice_edit',
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => 0,
    },
  },
  CREDIT_NOTE_STORNO_TYPE() => {
    text => {
      delete       => t8("The storno credit note has been deleted"),
      posted       => t8("The storno credit note has been posted"),
      list         => t8("Storno Credit Notes"),
      add          => t8("Add Storno Credit Note"),
      edit         => t8("Edit Storno Credit Note"),
      type         => t8("Storno Credit Note"),
      abbreviation => t8("Storno (one letter abbreviation)"),
    },
    show_menu => {
      invoice_for_advance_payment => 0,
      final_invoice               => 0,
      credit_note                 => 1,
      sales_order                 => 1,
      sales_reclamation           => 0,
      use_as_new => 1,
      # delete     => sub { die "not implemented" },
      post_payment                => 1,
      mark_as_paid                => sub { $::instance_conf->get_is_show_mark_as_paid },
      advance_payment             => 0,
      credit_note                 => 0,
      reclamation                 => 0,
    },
    properties => {
      customervendor => "customer",
      is_invoice     => 1,
      is_customer    => 1,
      nr_key         => "invnumber",
      worflow_needed => 1,
      is_credit_note => 1,
      has_marge      => 0,
      show_serialno  => 1,
      show_reqdate   => 1,
    },
    defaults => {
      duedate => sub { },
    },
    part_classification_query => [ "used_for_sale" => 1 ],
    rights => {
      view => 'sales_invoice_view',
      edit => 'invoice_edit',
    },
    features => {
      price_tax   => 1,
      stock       => 0,
      subversions => 0,
    },
  },
);

my @valid_types = (
  AR_TRANSACTION_TYPE,
  AR_TRANSACTION_STORNO_TYPE,
  INVOICE_TYPE,
  INVOICE_STORNO_TYPE,
  INVOICE_FOR_ADVANCE_PAYMENT_TYPE,
  INVOICE_FOR_ADVANCE_PAYMENT_STORNO_TYPE,
  FINAL_INVOICE_TYPE,
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
