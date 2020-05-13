package SL::DB;

use strict;

use Carp;
use Data::Dumper;
use English qw(-no_match_vars);
use Rose::DB;
use SL::DB::Helper::Cache;
use Scalar::Util qw(blessed);

use base qw(Rose::DB);

__PACKAGE__->db_cache_class('SL::DB::Helper::Cache');
__PACKAGE__->use_private_registry;

my (%_db_registered);

sub dbi_connect {
  shift;

  # runtime require to break circular include
  require SL::DBConnect;
  return SL::DBConnect->connect(@_);
}

sub create {
  my $domain = shift || SL::DB->default_domain;
  my $type   = shift || SL::DB->default_type;

  ($domain, $type) = _register_db($domain, $type);

  my $db = __PACKAGE__->new_or_cached(domain => $domain, type => $type);

  return $db;
}

sub client {
  create(undef, 'KIVITENDO');
}

sub auth {
  create(undef, 'KIVITENDO_AUTH');
}

sub _register_db {
  my $domain = shift;
  my $type   = shift;

  require SL::DBConnect;
  my %specific_connect_settings;
  my %common_connect_settings = (
    driver           => 'Pg',
    european_dates   => ((SL::DBConnect->get_datestyle || '') =~ m/european/i) ? 1 : 0,
    connect_options  => {
      pg_enable_utf8 => 1,
    },
  );

  if (($type eq 'KIVITENDO_AUTH') && $::auth && $::auth->{DB_config} && $::auth->session_tables_present) {
    %specific_connect_settings = (
      database        => $::auth->{DB_config}->{db},
      host            => $::auth->{DB_config}->{host} || 'localhost',
      port            => $::auth->{DB_config}->{port} || 5432,
      username        => $::auth->{DB_config}->{user},
      password        => $::auth->{DB_config}->{password},
    );

  } elsif ($::auth && $::auth->client) {
    my $client        = $::auth->client;
    %specific_connect_settings = (
      database        => $client->{dbname},
      host            => $client->{dbhost} || 'localhost',
      port            => $client->{dbport} || 5432,
      username        => $client->{dbuser},
      password        => $client->{dbpasswd},
    );

  } elsif (%::myconfig && $::myconfig{dbname}) {
    %specific_connect_settings = (
      database        => $::myconfig{dbname},
      host            => $::myconfig{dbhost} || 'localhost',
      port            => $::myconfig{dbport} || 5432,
      username        => $::myconfig{dbuser},
      password        => $::myconfig{dbpasswd},
    );

  } else {
    $type = 'KIVITENDO_EMPTY';
  }

  my %connect_settings   = (%common_connect_settings, %specific_connect_settings);
  my %flattened_settings = _flatten_settings(%connect_settings);

  $domain                = 'KIVITENDO' if $type =~ m/^KIVITENDO/;
  $type                 .= join($SUBSCRIPT_SEPARATOR, map { ($_, $flattened_settings{$_} || '') } sort grep { $_ ne 'password' } keys %flattened_settings);
  my $idx                = "${domain}::${type}";

  if (!$_db_registered{$idx}) {
    $_db_registered{$idx} = 1;

    __PACKAGE__->register_db(domain => $domain,
                             type   => $type,
                             %connect_settings,
                            );
  }

  return ($domain, $type);
}

sub _flatten_settings {
  my %settings  = @_;
  my %flattened = ();

  while (my ($key, $value) = each %settings) {
    if ('HASH' eq ref $value) {
      %flattened = ( %flattened, _flatten_settings(%{ $value }) );
    } else {
      $flattened{$key} = $value;
    }
  }

  return %flattened;
}

sub with_transaction {
  my ($self, $code, @args) = @_;

  return $code->(@args) if $self->in_transaction;

  my (@result, $result);
  my $rv = 1;

  local $@;
  my $return_array = wantarray;
  eval {
    $return_array
      ? $self->do_transaction(sub { @result = $code->(@args) })
      : $self->do_transaction(sub { $result = $code->(@args) });
  } or do {
    my $error = $self->error;
    if (blessed $error) {
      if ($error->isa('SL::X::DBError')) {
        # gobble the exception
      } else {
        $error->rethrow;
      }
    } else {
      die $self->error;
    }
  };

  return $return_array ? @result : $result;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB - Database access class for all RDB objects

=head1 FUNCTIONS

=over 4

=item C<create $domain, $type>

Registers the database information with Rose, creates a cached
connection and executes initial SQL statements. Those can include
setting the time & date format to the user's preferences.

=item C<dbi_connect $dsn, $login, $password, $options>

Forwards the call to L<SL::DBConnect/connect> which connects to the
database. This indirection allows L<SL::DBConnect/connect> to route
the calls through L<DBIx::Log4Perl> if this is enabled in the
configuration.

=item C<with_transaction $code_ref, @args>

Executes C<$code_ref> with parameters C<@args> within a transaction,
starting one only if none is currently active. Example:

  return $self->db->with_transaction(sub {
    # do stuff with $self
  });

This is a wrapper around L<Rose::DB/do_transaction> that does a few additional
things, and should always be used in favour of the other:

=over 4

=item Composition of transactions

When C<with_transaction> is called without a running transaction, a new one is
created. If it is called within a running transaction, it performs no
additional handling. This means that C<with_transaction> can be safely used
within another C<with_transaction>, whereas L<Rose::DB/do_transaction> can not.

=item Return values

C<with_transaction> adopts the behaviour of C<eval> in that it returns the
result of the inner block, and C<undef> if an error occurred. This way you can
use the same pattern you would normally use with C<eval> for
C<with_transaction>:

  SL::DB->client->with_transaction(sub {
     # do stuff
     # and return nominal true value
     1;
  }) or do {
    # transaction error handling
    my $error = SL::DB->client->error;
  }

or you can use it to safely calulate things.

=item Error handling

The original L<Rose::DB/do_transaction> gobbles up all exceptions and expects
the caller to manually check the return value and error, and then to process
all exceptions as strings. This is very fragile and generally a step backwards
from proper exception handling.

C<with_transaction> only gobbles up exceptions that are used to signal an
error in the transaction, and returns undef on those. All other exceptions
bubble out of the transaction like normal, so that it is transparent to typos,
runtime exceptions and other generally wanted things.

If you just use the snippet above, your code will catch everything related to
the transaction aborting, but will not catch other errors that might have been
thrown. The transaction will be rolled back in both cases.

If you want to play nice in case your transaction is embedded in another
transaction, just rethrow the error:

  $db->with_transaction(sub {
    # code deep in the engine
    1;
  }) or die $db->error;

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
