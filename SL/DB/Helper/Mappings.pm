package SL::DB::Helper::Mappings;

use utf8;
use strict;

use SL::Util qw(camelify);

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(get_table_for_package get_package_for_table get_package_names);

# these will not be managed as Rose::DB models, because they are not normalized,
# significant changes are needed to get them done, or they were done by CRM.
my @kivitendo_blacklist_permanent = qw(
  leads
);

# these are not managed _yet_, but will hopefully at some point.
# if you are confident that one of these works, remove it here.
my @kivitendo_blacklist_temp = qw(
);

# tables created by crm module
my @crm_blacklist = qw(
  blz_data
  bundesland
  contmasch
  contract
  crm
  crmdefaults
  crmemployee
  custmsg
  docfelder
  documents
  documenttotc
  docvorlage
  extra_felder
  geodb_changelog
  geodb_coordinates
  geodb_floatdata
  geodb_hierarchies
  geodb_intdata
  geodb_locations
  geodb_textdata
  geodb_type_names
  grpusr
  gruppenname
  history
  labels
  labeltxt
  mailvorlage
  maschine
  maschmat
  opport_status
  opportunity
  postit
  repauftrag
  telcall
  telcallhistory
  telnr
  tempcsvdata
  termdate
  termincat
  termine
  terminmember
  timetrack
  tt_event
  tt_parts
  wiedervorlage
  wissencategorie
  wissencontent
);

# tables created by cash register
my @cash_register_blacklist = qw(
ekartikel ekbon ekkunde ektext erptasten
);

my @kivitendo_blacklist = (@kivitendo_blacklist_permanent, @kivitendo_blacklist_temp, @crm_blacklist, @cash_register_blacklist);

# map table names to their models.
# unlike rails we have no singular<->plural magic.
# remeber: tables should be named as the plural of the model name.
my %kivitendo_package_names = (
  # TABLE                           # MODEL (given in C style)
  acc_trans                      => 'acc_transaction',
  additional_billing_addresses   => 'additional_billing_address',
  'auth.clients'                 => 'auth_client',
  'auth.clients_users'           => 'auth_client_user',
  'auth.clients_groups'          => 'auth_client_group',
  'auth.group'                   => 'auth_group',
  'auth.group_rights'            => 'auth_group_right',
  'auth.master_rights'           => 'auth_master_right',
  'auth.schema_info'             => 'auth_schema_info',
  'auth.session'                 => 'auth_session',
  'auth.session_content'         => 'auth_session_content',
  'auth.user'                    => 'auth_user',
  'auth.user_config'             => 'auth_user_config',
  'auth.user_group'              => 'auth_user_group',
  ar                             => 'invoice',
  ap                             => 'purchase_invoice',
  ap_gl                          => 'ap_gl',
  assembly                       => 'assembly',
  assortment_items               => 'assortment_item',
  background_jobs                => 'background_job',
  background_job_histories       => 'background_job_history',
  bank_accounts                  => 'bank_account',
  bank_transactions              => 'bank_transaction',
  bank_transaction_acc_trans     => 'bank_transaction_acc_trans',
  buchungsgruppen                => 'buchungsgruppe',
  bin                            => 'bin',
  business                       => 'business',
  business_models                => 'business_model',
  chart                          => 'chart',
  contact_departments            => 'contact_department',
  contact_titles                 => 'contact_title',
  contacts                       => 'contact',
  customer                       => 'customer',
  csv_import_profiles            => 'csv_import_profile',
  csv_import_profile_settings    => 'csv_import_profile_setting',
  csv_import_reports             => 'csv_import_report',
  csv_import_report_rows         => 'csv_import_report_row',
  csv_import_report_status       => 'csv_import_report_status',
  currencies                     => 'currency',
  custom_data_export_queries     => 'CustomDataExportQuery',
  custom_data_export_query_parameters => 'CustomDataExportQueryParameter',
  custom_variable_config_partsgroups => 'custom_variable_config_partsgroup',
  custom_variable_configs        => 'custom_variable_config',
  custom_variables               => 'custom_variable',
  custom_variables_validity      => 'custom_variable_validity',
  datev                          => 'datev',
  defaults                       => 'default',
  delivery_orders                => 'delivery_order',
  delivery_order_items           => 'delivery_order_item',
  delivery_order_items_stock     => 'delivery_order_items_stock',
  delivery_terms                 => 'delivery_term',
  department                     => 'department',
  drafts                         => 'draft',
  dunning                        => 'dunning',
  dunning_config                 => 'dunning_config',
  email_imports                  => 'EmailImport',
  email_journal                  => 'EmailJournal',
  email_journal_attachments      => 'EmailJournalAttachment',
  employee                       => 'employee',
  employee_project_invoices      => 'EmployeeProjectInvoices',
  exchangerate                   => 'exchangerate',
  files                          => 'file',
  file_versions                  => 'file_version',
  file_full_texts                => 'file_full_text',
  finanzamt                      => 'finanzamt',
  follow_up_access               => 'follow_up_access',
  follow_up_created_for_employees => 'follow_up_created_for_employee',
  follow_up_done                 => 'follow_up_done',
  follow_up_links                => 'follow_up_link',
  follow_ups                     => 'follow_up',
  generic_translations           => 'generic_translation',
  gl                             => 'GLTransaction',
  greetings                      => 'greeting',
  history_erp                    => 'history',
  inventory                      => 'inventory',
  invoice                        => 'invoice_item',
  language                       => 'language',
  letter                         => 'letter',
  letter_draft                   => 'letter_draft',
  makemodel                      => 'make_model',
  notes                          => 'note',
  order_statuses                 => 'order_status',
  orderitems                     => 'order_item',
  oe                             => 'order',
  oe_version                     => 'order_version',
  parts                          => 'part',
  partsgroup                     => 'parts_group',
  part_classifications           => 'PartClassification',
  part_customer_prices           => 'PartCustomerPrice',
  parts_price_history            => 'PartsPriceHistory',
  payment_terms                  => 'payment_term',
  periodic_invoices              => 'periodic_invoice',
  periodic_invoices_configs      => 'periodic_invoices_config',
  prices                         => 'price',
  price_factors                  => 'price_factor',
  price_rules                    => 'price_rule',
  price_rule_items               => 'price_rule_item',
  pricegroup                     => 'pricegroup',
  printers                       => 'printer',
  project                        => 'project',
  project_participants           => 'project_participant',
  project_phase_participants     => 'project_phase_participant',
  project_phases                 => 'project_phase',
  project_roles                  => 'project_role',
  project_statuses               => 'project_status',
  project_types                  => 'project_type',
  purchase_basket_items          => 'purchase_basket_item',
  reclamations                   => 'Reclamation',
  reclamation_items              => 'ReclamationItem',
  reclamation_reasons            => 'ReclamationReason',
  reconciliation_links           => 'reconciliation_link',
  record_links                   => 'record_link',
  record_templates               => 'record_template',
  record_template_items          => 'record_template_item',
  requirement_spec_acceptance_statuses => 'RequirementSpecAcceptanceStatus',
  requirement_spec_complexities        => 'RequirementSpecComplexity',
  requirement_spec_item_dependencies   => 'RequirementSpecDependency',
  requirement_spec_items               => 'RequirementSpecItem',
  requirement_spec_orders              => 'RequirementSpecOrder',
  requirement_spec_parts               => 'RequirementSpecPart',
  requirement_spec_pictures            => 'RequirementSpecPicture',
  requirement_spec_predefined_texts    => 'RequirementSpecPredefinedText',
  requirement_spec_risks               => 'RequirementSpecRisk',
  requirement_spec_statuses            => 'RequirementSpecStatus',
  requirement_spec_text_blocks         => 'RequirementSpecTextBlock',
  requirement_spec_types               => 'RequirementSpecType',
  requirement_spec_versions            => 'RequirementSpecVersion',
  requirement_specs                    => 'RequirementSpec',
  secrets                        => 'secret',
  sepa_export                    => 'sepa_export',
  sepa_export_items              => 'sepa_export_item',
  sepa_export_message_ids        => 'SepaExportMessageId',
  schema_info                    => 'schema_info',
  shipto                         => 'shipto',
  shops                          => 'shop',
  shop_images                    => 'shop_image',
  shop_orders                    => 'shop_order',
  shop_order_items               => 'shop_order_item',
  shop_parts                     => 'shop_part',
  status                         => 'status',
  stocktakings                   => 'stocktaking',
  tax                            => 'tax',
  taxkeys                        => 'tax_key',
  tax_zones                      => 'tax_zone',
  taxzone_charts                 => 'taxzone_chart',
  time_recording_articles        => 'time_recording_article',
  time_recordings                => 'time_recording',
  todo_user_config               => 'todo_user_config',
  transfer_type                  => 'transfer_type',
  translation                    => 'translation',
  trigger_information            => 'trigger_information',
  units                          => 'unit',
  units_language                 => 'units_language',
  user_preferences               => 'user_preference',
  validity_tokens                => 'ValidityToken',
  vendor                         => 'vendor',
  warehouse                      => 'warehouse',
);

my (%kivitendo_tables_to_packages, %kivitendo_tables_to_manager_packages, %kivitendo_packages_to_tables);

sub get_blacklist {
  return KIVITENDO => \@kivitendo_blacklist;
}

sub get_package_names {
  return KIVITENDO => \%kivitendo_package_names;
}

sub get_name_for_table {
  return $kivitendo_package_names{ $_[0] };
}

sub get_package_for_table {
  %kivitendo_tables_to_packages = map { ($_ => "SL::DB::" . camelify($kivitendo_package_names{$_})) } keys %kivitendo_package_names
    unless %kivitendo_tables_to_packages;

  return $kivitendo_tables_to_packages{ $_[0] };
}

sub get_manager_package_for_table {
  %kivitendo_tables_to_manager_packages = map { ($_ => "SL::DB::Manager::" . camelify($kivitendo_package_names{$_})) } keys %kivitendo_package_names
    unless %kivitendo_tables_to_manager_packages;

  return $kivitendo_tables_to_manager_packages{ $_[0] };
}

sub get_table_for_package {
  get_package_for_table('dummy') if !%kivitendo_tables_to_packages;
  %kivitendo_packages_to_tables = reverse %kivitendo_tables_to_packages unless %kivitendo_packages_to_tables;

  my $package = $_[0] =~ m/^SL::DB::/ ? $_[0] : "SL::DB::" . $_[0];
  return $kivitendo_packages_to_tables{ $package };
}

sub db {
  my $string = $_[0];
  my $lookup = $kivitendo_package_names{$_[0]} ||
      plurify($kivitendo_package_names{singlify($_[0])});

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

  SL::DB::Helper::Mappings::get_package_for_table('oe')
  # SL::DB::Order

=item C<get_manager_package_for_table $table_name>

Returns the manager package name for a table name:

  SL::DB::Helper::Mappings::get_manager_package_for_table('oe')
  # SL::DB::Manager::Order

=item C<get_table_for_package $package_name>

Returns the table name for a package name:

  SL::DB::Helper::Mappings::get_table_for_package('SL::DB::Order')
  # oe
  SL::DB::Helper::Mappings::get_table_for_package('Order')
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
