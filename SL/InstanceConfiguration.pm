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

  my $curr            =  $self->{data}->{curr} || '';
  $curr               =~ s/\s+//g;
  $self->{currencies} =  [ split m/:/, $curr ];

  return $self;
}

sub get_default_currency {
  my ($self) = @_;

  return ($self->get_currencies)[0];
}

sub get_currencies {
  my ($self) = @_;

  return $self->{currencies} ? @{ $self->{currencies} } : ();
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

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::InstanceConfiguration - Provide instance-specific configuration data

=head1 SYNOPSIS

Lx-Office has two configuration levels: installation specific
(provided by the global variable C<%::lxoffice_conf>) and instance
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

=back

=head1 BUGS

Updates to the I<defaults> table require that the instance
configuration is re-read. This has not been implemented yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
