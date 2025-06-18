package SL::InstanceConfiguration;

use strict;

use Carp;
use SL::DBUtils ();
use SL::System::Process;

use parent qw(Rose::Object);
use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(data currencies default_currency _table_currencies_exists crm_installed) ],
);

sub init_data {
  return {} if !$::auth->client;
  return SL::DBUtils::selectfirst_hashref_query($::form, $::form->get_standard_dbh, qq|SELECT * FROM defaults|);
}

sub init__table_currencies_exists {
  return 0 if !$::auth->client;
  return !!(SL::DBUtils::selectall_hashref_query($::form, $::form->get_standard_dbh, qq|SELECT tablename FROM pg_tables WHERE (schemaname = 'public') AND (tablename = 'currencies')|))[0];
}

sub init_currencies {
  my ($self) = @_;

  return [] if !$self->_table_currencies_exists;
  return [ map { $_->{name} } SL::DBUtils::selectall_hashref_query($::form, $::form->get_standard_dbh, qq|SELECT name FROM currencies ORDER BY id ASC|) ];
}

sub init_default_currency {
  my ($self) = @_;

  return undef if !$self->_table_currencies_exists || !$self->data->{currency_id};
  return (SL::DBUtils::selectfirst_array_query($::form, $::form->get_standard_dbh, qq|SELECT name FROM currencies WHERE id = ?|, $self->data->{currency_id}))[0];
}

sub init_crm_installed {
  return -f (SL::System::Process->exe_dir . '/crm/Changelog');
}

sub reload {
  my ($self) = @_;

  delete @{ $self }{qw(data currencies default_currency)};

  return $self;
}

sub get_currencies {
  my ($self) = @_;
  return @{ $self->currencies };
}

sub get_address {
  # Compatibility function: back in the day there was only a single
  # address field.
  my ($self) = @_;

  my $zipcode_city = join ' ', grep { $_ } ($self->get_address_zipcode, $self->get_address_city);

  return join "\n", grep { $_ } ($self->get_address_street1, $self->get_address_street2, $zipcode_city, $self->get_address_country);
}

sub get_layout_style {
  return $_[0]->data->{layout_style} if exists $_[0]->data->{layout_style};
  return '';
}

sub AUTOLOAD {
  our $AUTOLOAD;

  my $self   =  shift;
  my $method =  $AUTOLOAD;
  $method    =~ s/.*:://;

  return if $method eq 'DESTROY';

  if ($method =~ m/^get_/) {
    $method = substr $method, 4;
    return $self->data->{$method} if exists $self->data->{$method};
    croak "Invalid method 'get_${method}'";
  }

  croak "Invalid method '${method}'" if !$self->can($method);
  return $self->$method(@_);
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::InstanceConfiguration - Provide instance-specific configuration data

=head1 SYNOPSIS

kivitendo has two configuration levels: installation specific
(provided by the global variable C<%::lx_office_conf>) and instance
specific. The latter is provided by a global instance of this class,
C<$::instance_conf>.

=head1 FUNCTIONS

=over 4

=item C<new>

Creates a new instance. Does not read the configuration.

=item C<crm_installed>

Returns trueish if the CRM component is installed.

=item C<get_currencies>

Returns an array of configured currencies.

=item C<get_default_currency>

Returns the default currency or undef if no currency has been
configured.

=item C<get_layout_style>

Returns the forced default layout style or '' if the database column
does not exist yet.

=item C<get_accounting_method>

Returns the default accounting method, accrual or cash

=item C<get_inventory_system>

Returns the default inventory system, perpetual or periodic

=item C<get_profit_determination>

Returns the default profit determination method, balance or income

=item C<get_balance_startdate_method>

Returns the default method for determining the startdate for the balance
report.

Valid options:
closed_to start_of_year all_transactions last_ob_or_all_transactions last_ob_or_start_of_year

=item C<get_is_changeable>

=item C<get_ir_changeable>

=item C<get_ar_changeable>

=item C<get_ap_changeable>

=item C<get_gl_changeable>

Returns if and when these record types are changeable or deleteable after
posting. 0 means never, 1 means always and 2 means on the same day.

=item C<get_datev_check_on_sales_invoice>

Returns true if datev check should be performed on sales invoices

=item C<get_datev_check_on_purchase_invoice>

Returns true if datev check should be performed on purchase invoices

=item C<get_datev_check_on_ar_transaction>

Returns true if datev check should be performed on ar transactions

=item C<get_datev_check_on_ap_transaction>

Returns true if datev check should be performed on ap transactions

=item C<get_datev_check_on_gl_transaction>

Returns true if datev check should be performed on gl transactions

=item C<get_show_bestbefore>

Returns the default behavior for showing best before date, true or false

=item C<get_is_show_mark_as_paid>

=item C<get_ir_show_mark_as_paid>

=item C<get_ar_show_mark_as_paid>

=item C<get_ap_show_mark_as_paid>

Returns the default behavior for showing the "mark as paid" button for the
corresponding record type (true or false).

=item C<get_sales_order_show_delete>

=item C<get_purchase_order_show_delete>

=item C<get_sales_delivery_order_show_delete>

=item C<get_purchase_delivery_order_show_delete>

Returns the default behavior for showing the delete button for the
corresponding record type (true or false).

=item C<get_warehouse_id>

Returns the default warehouse_id

=item C<get_bin_id>

Returns the default bin_id

=item C<get_warehouse_id_ignore_onhand>

Returns the default warehouse_id for transfers without checking the
current stock quantity

=item C<get_bin_id_ignore_onhand>

Returns the default bin_id for transfers without checking the
current stock quantity

=item C<get_transfer_default>

=item C<get_transfer_default_use_master_default_bin>

=item C<get_transfer_default_ignore_onhand>

Returns the default behavior for the transfer out default feature (true or false)

=item C<get_max_future_booking_interval>

Returns the maximum interval value for future bookings

=item C<get_webdav>

Returns the configuration for WebDAV

=item C<get_webdav_documents>

Returns the configuration for storing documents in the corresponding WebDAV folder

=item C<get_parts_show_image>

Returns the configuarion for show image in parts

=item C<get_parts_image_css>

Returns the css format string for images shown in parts

=item C<get_parts_listing_image>

Returns the configuration for showing the picture in the results when you search for parts

=back

=head1 BUGS

Updates to the I<defaults> table require that the instance
configuration is re-read. This has not been implemented yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
