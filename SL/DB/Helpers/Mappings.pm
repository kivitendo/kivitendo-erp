package SL::DB::Helpers::Mappings;

use strict;

# threse will not be managed as Rose::DB models, because they are not normalized
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
  bank_accounts buchungsgruppen contacts custom_variable_configs
  custom_variables custom_variables_validity drafts dunning dunning_config
  employee follow_up_links follow_ups generic_translations history_erp language
  license notes payment_terms pricegroup rma schema_info sepa_export
  sepa_export_items tax taxkeys
);

my @lxoffice_blacklist = (@lxoffice_blacklist_permanent, @lxoffice_blacklist_temp);

# map table names to their models.
# unlike rails we have no singular<->plural magic.
# remeber: tables should be named as the plural of the model name.
my %lxoffice_package_names = (
  ar                             => 'invoice',
  ap                             => 'purchase_invoice',
  delivery_orders                => 'delivery_order',
  delivery_order_items           => 'delivery_order_item',
  gl                             => 'GLTransaction',
  invoice                        => 'invoice_item',
  orderitems                     => 'order_item',
  oe                             => 'order',
  parts                          => 'part',
  price_factors                  => 'price_factor',
  printers                       => 'Printer',
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
