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

=item C<get_currencies>

Returns an array of configured currencies.

=back

=head1 BUGS

Updates to the I<defaults> table require that the instance
configuration is re-read. This has not been implemented yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
