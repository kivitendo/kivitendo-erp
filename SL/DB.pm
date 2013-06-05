package SL::DB;

use strict;

use Carp;
use Data::Dumper;
use SL::DBConnect;
use English qw(-no_match_vars);
use Rose::DB;
use Rose::DBx::Cache::Anywhere;

use base qw(Rose::DB);

__PACKAGE__->db_cache_class('Rose::DBx::Cache::Anywhere');
__PACKAGE__->use_private_registry;

my (%_db_registered, %_initial_sql_executed);

sub dbi_connect {
  shift;

  return SL::DBConnect->connect(@_);
}

sub create {
  my $domain = shift || SL::DB->default_domain;
  my $type   = shift || SL::DB->default_type;

  ($domain, $type) = _register_db($domain, $type);

  my $db = __PACKAGE__->new_or_cached(domain => $domain, type => $type);

  _execute_initial_sql($db);

  return $db;
}

my %_dateformats = ( 'yy-mm-dd'   => 'ISO',
                     'yyyy-mm-dd' => 'ISO',
                     'mm/dd/yy'   => 'SQL, US',
                     'dd/mm/yy'   => 'SQL, EUROPEAN',
                     'dd.mm.yy'   => 'GERMAN'
                   );

sub _register_db {
  my $domain = shift;
  my $type   = shift;

  my %connect_settings;
  my $initial_sql;

  if ($type eq 'KIVITENDO_AUTH') {
    %connect_settings = ( driver          => 'Pg',
                          database        => $::auth->{DB_config}->{db},
                          host            => $::auth->{DB_config}->{host} || 'localhost',
                          port            => $::auth->{DB_config}->{port} || 5432,
                          username        => $::auth->{DB_config}->{user},
                          password        => $::auth->{DB_config}->{password},
                          connect_options => { pg_enable_utf8 => $::locale && $::locale->is_utf8,
                                             });
  } elsif (!%::myconfig) {
    $type = 'KIVITENDO_EMPTY';
    %connect_settings = ( driver => 'Pg' );

  } else {
    my $european_dates = 0;
    if ($::myconfig{dateformat}) {
      $european_dates = 1 if $_dateformats{ $::myconfig{dateformat} }
                          && $_dateformats{ $::myconfig{dateformat} } =~ m/european/i;
    }

    %connect_settings = ( driver          => $::myconfig{dbdriver} || 'Pg',
                          database        => $::myconfig{dbname},
                          host            => $::myconfig{dbhost} || 'localhost',
                          port            => $::myconfig{dbport} || 5432,
                          username        => $::myconfig{dbuser},
                          password        => $::myconfig{dbpasswd},
                          connect_options => { pg_enable_utf8 => $::locale && $::locale->is_utf8,
                                             },
                          european_dates  => $european_dates);
  }

  my %flattened_settings = _flatten_settings(%connect_settings);

  $domain = 'KIVITENDO' if $type =~ m/^KIVITENDO/;
  $type  .= join($SUBSCRIPT_SEPARATOR, map { ($_, $flattened_settings{$_} || '') } sort grep { $_ ne 'dbpasswd' } keys %flattened_settings);
  my $idx = "${domain}::${type}";

  if (!$_db_registered{$idx}) {
    $_db_registered{$idx} = 1;

    __PACKAGE__->register_db(domain => $domain,
                             type   => $type,
                             %connect_settings,
                            );
  }

  return ($domain, $type);
}

sub _execute_initial_sql {
  my ($db) = @_;

  return if $_initial_sql_executed{$db} || !%::myconfig || !$::myconfig{dateformat};

  $_initial_sql_executed{$db} = 1;

  # Don't rely on dboptions being set properly. Chose them from
  # dateformat instead.
  my $pg_dateformat = $_dateformats{ $::myconfig{dateformat} };
  $db->dbh->do("set DateStyle to '${pg_dateformat}'") if $pg_dateformat;
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
  if (wantarray) {
    my @result;
    return $self->do_transaction(sub { @result = $code->(@args) }) ? @result : ();

  } else {
    my $result;
    return $self->do_transaction(sub { $result = $code->(@args) }) ? $result : undef;
  }
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
starting one if none is currently active. Example:

  return $self->db->with_transaction(sub {
    # do stuff with $self
  });

One big difference to L<Rose::DB/do_transaction> is the return code
handling. If a transaction is already active then C<with_transcation>
simply returns the result of calling C<$code_ref> as-is.

Otherwise the return value depends on the result of the underlying
transaction. If the transaction fails then C<undef> is returned in
scalar context and an empty list in list context. If the transaction
succeeds then the return value of C<$code_ref> is returned preserving
context.

So if you want to differentiate between "transaction failed" and
"succeeded" then your C<$code_ref> should never return C<undef>
itself.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
