package SL::DB::Helpers::Mappings;

use strict;

# these will not be managed as Rose::DB models, because they are not normalized
# significant changes are needed to get them done.
my @lxoffice_blacklist_permanent = qw(
);

# these are not managed _yet_, but will hopefully at some point.
# if you are confident that one of these works, remove it here.
my @lxoffice_blacklist_temp = qw(
);

my @lxoffice_blacklist = (@lxoffice_blacklist_permanent, @lxoffice_blacklist_temp);

# map table names to their models.
# unlike rails we have no singular<->plural magic.
# remeber: tables should be named as the plural of the model name.
my %lxoffice_package_names = (
  acc_trans                      => 'acc_transaction',
  audittrail                     => 'audit_trail',
  ar                             => 'invoice',
  ap                             => 'purchase_invoice',
  bank_accounts                  => 'bank_account',
  buchungsgruppen                => 'buchungsgruppe',
  contacts                       => 'contact',
  custom_variable_configs        => 'custom_variable_config',
  custom_variables               => 'custom_variable',
  custom_variables_validity      => 'custom_variable_validity',
  customertax                    => 'customer_tax',
  datev                          => 'datev',
  defaults                       => 'default',
  delivery_orders                => 'delivery_order',
  delivery_order_items           => 'delivery_order_item',
  department                     => 'department',
  dpt_trans                      => 'dpt_trans',
  drafts                         => 'draft',
  dunning                        => 'dunning',
  dunning_config                 => 'dunning_config',
  employee                       => 'employee',
  exchangerate                   => 'exchangerate',
  finanzamt                      => 'finanzamt',
  follow_up_access               => 'follow_up_access',
  follow_up_links                => 'follow_up_link',
  follow_ups                     => 'follow_up',
  generic_translations           => 'generic_translation',
  gifi                           => 'gifi',
  gl                             => 'GLTransaction',
  history_erp                    => 'history',
  inventory                      => 'inventory',
  invoice                        => 'invoice_item',
  language                       => 'language',
  leads                          => 'lead',
  license                        => 'license',
  licenseinvoice                 => 'license_invoice',
  makemodel                      => 'make_model',
  notes                          => 'note',
  orderitems                     => 'order_item',
  oe                             => 'order',
  parts                          => 'part',
  partsgroup                     => 'parts_group',
  partstax                       => 'parts_tax',
  payment_terms                  => 'payment_term',
  prices                         => 'prices',
  price_factors                  => 'price_factor',
  pricegroup                     => 'pricegroup',
  printers                       => 'Printer',
  record_links                   => 'record_link',
  rma                            => 'RMA',
  rmaitems                       => 'RMA_item',
  sepa_export                    => 'sepa_export',
  sepa_export_items              => 'sepa_export_item',
  schema_info                    => 'schema_info',
  status                         => 'status',
  tax                            => 'tax',
  taxkeys                        => 'tax_key',
  tax_zones                      => 'tax_zone',
  todo_user_config               => 'todo_user_config',
  translation                    => 'translation',
  translation_payment_terms      => 'translation_payment_term',
  units                          => 'unit',
  units_language                 => 'units_language',
  vendortax                      => 'vendor_tax',
);

sub get_blacklist {
  return LXOFFICE => \@lxoffice_blacklist;
}

sub get_package_names {
  return LXOFFICE => \%lxoffice_package_names;
}

sub db {
  my $string = $_[0];
  my $lookup = $lxoffice_package_names{$_[0]} ||
      plurify($lxoffice_package_names{singlify($_[0])});

  for my $thing ($string, $lookup) {

    # best guess? its already the name. like part. camelize it first
    my $class = "SL::DB::" . camelify($thing);
    return $class if defined *{ $class. '::' };

    # next, someone wants a manager and pluralized.
    my $manager = "SL::DB::Manager::" . singlify(camelify($thing));
    return $manager if defined *{ $manager . '::' };
  }

  die "Can't resolve '$string' as a database model, sorry. Did you perhaps forgot to load it?";
}

sub camelify {
  my ($str) = @_;
  $str =~ s/_+(.)/uc($1)/ge;
  ucfirst $str;
}

sub snakify {
  my ($str) = @_;
  $str =~ s/(?<!^)\u(.)/'_' . lc($1)/ge;
  lcfirst $str;
}

sub plurify {
  my ($str) = @_;
  $str . 's';
}

sub singlify {
  my ($str) = @_;
  local $/ = 's';
  chomp $str;
  $str;
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

=head2 db

A special function provided here is E<db>. Without it you'd have to write:

  my $part = SL::DB::Part->new(id => 1234);
  my @all_parts = SL::DB::Manager::Part->get_all;

with them it becomes:

  my $part = db('part')->new(id => 123);
  my @all_parts = db('parts')->get_all;

You don't have to care about add that SL::DB:: incantation anymore. Also, a
simple s at the end will get you the associated Manager class.

db is written to try to make sense of what you give it, but if all fails, it
will die with an error.

=head1 BUGS

nothing yet

=head1 SEE ALSO

L<scripts/rose_auto_create_model.pl>

=head1 AUTHOR

Sven Schöling <s.schoeling@linet-services.de>

=cut
