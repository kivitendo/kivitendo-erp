package SL::DB::Helpers::Mappings;

use strict;

# these will not be managed as Rose::DB models, because they are not normalized
# significant changes are needed to get them done.
my @lxoffice_blacklist_permanent = qw(
  acc_trans audittrail customertax datev defaults department dpt_trans
  exchangerate finanzamt follow_up_access gifi inventory leads licenseinvoice
  makemodel partsgroup partstax prices record_links rmaitems status tax_zones
  todo_user_config translation translation_payment_terms units_language
  vendortax);

# these are not managed _yet_, but will hopefully at some point.
# if you are confident that one of these works, remove it here.
my @lxoffice_blacklist_temp = qw(
);

my @lxoffice_blacklist = (@lxoffice_blacklist_permanent, @lxoffice_blacklist_temp);

# map table names to their models.
# unlike rails we have no singular<->plural magic.
# remeber: tables should be named as the plural of the model name.
my %lxoffice_package_names = (
  ar                             => 'invoice',
  ap                             => 'purchase_invoice',
  bank_accounts                  => 'bank_account',
  buchungsgruppen                => 'buchungsgruppe',
  contacts                       => 'contact',
  custom_variable_configs        => 'custom_variable_config',
  custom_variables               => 'custom_variable',
  custom_variables_validity      => 'custom_variable_validity',
  delivery_orders                => 'delivery_order',
  delivery_order_items           => 'delivery_order_item',
  drafts                         => 'draft',
  dunning                        => 'dunning',
  dunning_config                 => 'dunning_config',
  employee                       => 'employee',
  follow_up_links                => 'follow_up_link',
  follow_ups                     => 'follow_up',
  generic_translations           => 'generic_translation',
  gl                             => 'GLTransaction',
  history_erp                    => 'history',
  invoice                        => 'invoice_item',
  language                       => 'language',
  license                        => 'licemse',
  notes                          => 'note',
  orderitems                     => 'order_item',
  oe                             => 'order',
  parts                          => 'part',
  payment_terms                  => 'payment_term',
  price_factors                  => 'price_factor',
  pricegroup                     => 'pricegroup',
  printers                       => 'Printer',
  rma                            => 'RMA',
  sepa_export                    => 'sepa_export',
  sepa_export_items              => 'sepa_export_item',
  schema_info                    => 'schema_info',
  tax                            => 'tax',
  taxkeys                        => 'taxkey',
  units                          => 'unit',
);

sub get_blacklist {
  return LXOFFICE => \@lxoffice_blacklist;
}

sub get_package_names {
  return LXOFFICE => \%lxoffice_package_names;
}

1;

__END__

=head1 NAME

SL::DB::Helpers::Mappings - Rose Table <-> Model mapping information

=head1 SYNOPSIS

  use SL::DB::Helpers::Mappings qw(@blacklist %table2model);

=head1 DESCRIPTION

This modul stores table <-> model mappings used by the
L<scripts/rose_auto_create_model.pl> script.  If you add a new table that has
custom mappings, add it here.

=head1 BUGS

nothing yet

=head1 SEE ALSO

L<scripts/rose_auto_create_model.pl>

=head1 AUTHOR

Sven Schöling <s.schoeling@linet-services.de>

=cut
