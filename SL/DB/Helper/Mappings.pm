package SL::DB::Helper::Mappings;

use utf8;
use strict;

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(get_table_for_package get_package_for_table get_package_names);

# these will not be managed as Rose::DB models, because they are not normalized,
# significant changes are needed to get them done, or they were done by CRM.
my @lxoffice_blacklist_permanent = qw(
  leads
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
  auth_group                     => 'auth_groups',
  auth_group_right               => 'auth_group_rights',
  auth_user                      => 'auth_users',
  auth_user_config               => 'auth_user_configs',
  auth_user_group                => 'auth_user_groups',
  ar                             => 'invoice',
  ap                             => 'purchase_invoice',
  background_jobs                => 'background_job',
  background_job_histories       => 'background_job_history',
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
  periodic_invoices              => 'periodic_invoice',
  periodic_invoices_configs      => 'periodic_invoices_config',
  prices                         => 'price',
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

my (%lxoffice_tables_to_packages, %lxoffice_tables_to_manager_packages, %lxoffice_packages_to_tables);

sub get_blacklist {
  return LXOFFICE => \@lxoffice_blacklist;
}

sub get_package_names {
  return LXOFFICE => \%lxoffice_package_names;
}

sub get_package_for_table {
  %lxoffice_tables_to_packages = map { ($_ => "SL::DB::" . camelify($lxoffice_package_names{$_})) } keys %lxoffice_package_names
    unless %lxoffice_tables_to_packages;

  return $lxoffice_tables_to_packages{ $_[0] };
}

sub get_manager_package_for_table {
  %lxoffice_tables_to_manager_packages = map { ($_ => "SL::DB::Manager::" . camelify($lxoffice_package_names{$_})) } keys %lxoffice_package_names
    unless %lxoffice_tables_to_manager_packages;

  return $lxoffice_tables_to_manager_packages{ $_[0] };
}

sub get_table_for_package {
  get_package_for_table('dummy') if !%lxoffice_tables_to_packages;
  %lxoffice_packages_to_tables = reverse %lxoffice_tables_to_packages unless %lxoffice_packages_to_tables;

  my $package = $_[0] =~ m/^SL::DB::/ ? $_[0] : "SL::DB::" . $_[0];
  return $lxoffice_packages_to_tables{ $package };
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

=encoding utf8

=head1 NAME

SL::DB::Helper::Mappings - Rose Table <-> Model mapping information

=head1 SYNOPSIS

  use SL::DB::Helper::Mappings qw(@blacklist %table2model);

=head1 DESCRIPTION

This modul stores table <-> model mappings used by the
L<scripts/rose_auto_create_model.pl> script.  If you add a new table that has
custom mappings, add it here.

=head1 FUNCTIONS

=over 4

=item C<db $name>

A special function provided here is C<db>. Without it you'd have to write:

  my $part = SL::DB::Part->new(id => 1234);
  my @all_parts = SL::DB::Manager::Part->get_all;

with them it becomes:

  my $part = db('part')->new(id => 123);
  my @all_parts = db('parts')->get_all;

You don't have to care about add that SL::DB:: incantation anymore. Also, a
simple s at the end will get you the associated Manager class.

db is written to try to make sense of what you give it, but if all fails, it
will die with an error.

=item C<get_package_for_table $table_name>

Returns the package name for a table name:

  SL::DB::Helpers::Mappings::get_package_for_table('oe')
  # SL::DB::Order

=item C<get_manager_package_for_table $table_name>

Returns the manager package name for a table name:

  SL::DB::Helpers::Mappings::get_manager_package_for_table('oe')
  # SL::DB::Manager::Order

=item C<get_table_for_package $package_name>

Returns the table name for a package name:

  SL::DB::Helpers::Mappings::get_table_for_package('SL::DB::Order')
  # oe
  SL::DB::Helpers::Mappings::get_table_for_package('Order')
  # oe

=back

=head1 BUGS

nothing yet

=head1 SEE ALSO

L<scripts/rose_auto_create_model.pl>

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>,
Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
