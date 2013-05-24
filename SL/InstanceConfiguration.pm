package SL::InstanceConfiguration;

use strict;

use SL::DBUtils;

sub new {
  my ($class) = @_;

  return bless {}, $class;
}

sub init {
  my ($self) = @_;

  $self->{data} = selectfirst_hashref_query($::form, $::form->get_standard_dbh, qq|SELECT * FROM defaults|);

  #To get all currencies and the default currency:
  ($self->{data}->{curr}) = selectrow_query($::form, $::form->get_standard_dbh, qq|SELECT name AS curr FROM currencies WHERE id = (SELECT currency_id FROM defaults)|);
  $self->{currencies}     = [ map { $_->{name} } selectall_hashref_query($::form, $::form->get_standard_dbh, qq|SELECT name FROM currencies ORDER BY id|) ];

  return $self;
}

sub get_default_currency {
  my ($self) = @_;

  return $self->{data}->{curr};
}

sub get_currencies {
  my ($self) = @_;

  return @{ $self->{currencies} };
}

sub get_accounting_method {
  my ($self) = @_;
  return $self->{data}->{accounting_method};
}

sub get_inventory_system {
  my ($self) = @_;
  return $self->{data}->{inventory_system};
}

sub get_profit_determination {
  my ($self) = @_;
  return $self->{data}->{profit_determination};
}

sub get_is_changeable {
  my ($self) = @_;
  return $self->{data}->{is_changeable};
}

sub get_ir_changeable {
  my ($self) = @_;
  return $self->{data}->{ir_changeable};
}

sub get_ar_changeable {
  my ($self) = @_;
  return $self->{data}->{ar_changeable};
}

sub get_ap_changeable {
  my ($self) = @_;
  return $self->{data}->{ap_changeable};
}

sub get_gl_changeable {
  my ($self) = @_;
  return $self->{data}->{gl_changeable};
}

sub get_datev_check_on_sales_invoice {
  my ($self) = @_;
  return $self->{data}->{datev_check_on_sales_invoice};
}

sub get_datev_check_on_purchase_invoice {
  my ($self) = @_;
  return $self->{data}->{datev_check_on_purchase_invoice};
}

sub get_datev_check_on_ar_transaction {
  my ($self) = @_;
  return $self->{data}->{datev_check_on_ar_transaction};
}

sub get_datev_check_on_ap_transaction {
  my ($self) = @_;
  return $self->{data}->{datev_check_on_ap_transaction};
}

sub get_datev_check_on_gl_transaction {
  my ($self) = @_;
  return $self->{data}->{datev_check_on_gl_transaction};
}

sub get_show_bestbefore {
  my ($self) = @_;
  return $self->{data}->{show_bestbefore};
}

sub get_is_show_mark_as_paid {
  my ($self) = @_;
  return $self->{data}->{is_show_mark_as_paid};
}

sub get_ir_show_mark_as_paid {
  my ($self) = @_;
  return $self->{data}->{ir_show_mark_as_paid};
}

sub get_ar_show_mark_as_paid {
  my ($self) = @_;
  return $self->{data}->{ar_show_mark_as_paid};
}

sub get_ap_show_mark_as_paid {
  my ($self) = @_;
  return $self->{data}->{ap_show_mark_as_paid};
}

sub get_sales_order_show_delete {
  my ($self) = @_;
  return $self->{data}->{sales_order_show_delete};
}

sub get_purchase_order_show_delete {
  my ($self) = @_;
  return $self->{data}->{purchase_order_show_delete};
}

sub get_sales_delivery_order_show_delete {
  my ($self) = @_;
  return $self->{data}->{sales_delivery_order_show_delete};
}

sub get_purchase_delivery_order_show_delete {
  my ($self) = @_;
  return $self->{data}->{purchase_delivery_order_show_delete};
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

=item C<init>

Reads the configuration from the database. Returns C<$self>.

=item C<get_currencies>

Returns an array of configured currencies.

=item C<get_default_currency>

Returns the default currency or undef if no currency has been
configured.

=item C<get_accounting_method>

Returns the default accounting method, accrual or cash

=item C<get_inventory_system>

Returns the default inventory system, perpetual or periodic

=item C<get_profit_determination>

Returns the default profit determination method, balance or income


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

Returns the default behavior for showing the mark as paid button for the
corresponding record type (true or false).

=item C<get_sales_order_show_delete>

=item C<get_purchase_order_show_delete>

=item C<get_sales_delivery_order_show_delete>

=item C<get_purchase_delivery_order_show_delete>

Returns the default behavior for showing the delete button for the
corresponding record type (true or false).

=back

=head1 BUGS

Updates to the I<defaults> table require that the instance
configuration is re-read. This has not been implemented yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
