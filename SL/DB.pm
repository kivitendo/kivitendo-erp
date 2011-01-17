package SL::DB;

use strict;

use Carp;
use Data::Dumper;
use English qw(-no_match_vars);
use Rose::DB;

use base qw(Rose::DB);

__PACKAGE__->use_private_registry;

my (%_db_registered, %_initial_sql_executed);

sub dbi_connect {
  shift;

  return DBI->connect(@_) unless $::lx_office_conf{debug} && $::lx_office_conf{debug}->{dbix_log4perl};

  require Log::Log4perl;
  require DBIx::Log4perl;

  my $filename =  $LXDebug::file_name;
  my $config   =  $::lx_office_conf{debug}->{dbix_log4perl_config};
  $config      =~ s/LXDEBUGFILE/${filename}/g;

  Log::Log4perl->init(\$config);
  return DBIx::Log4perl->connect(@_);
}

sub create {
  my $domain = shift || SL::DB->default_domain;
  my $type   = shift || SL::DB->default_type;

  my ($domain, $type) = _register_db($domain, $type);

  my $db = __PACKAGE__->new_or_cached(domain => $domain, type => $type);

  _execute_initial_sql($db);

  return $db;
}

my %_dateformats = ( 'yy-mm-dd'   => 'ISO',
                     'yyyy-mm-dd' => 'ISO',
                     'mm/dd/yy'   => 'SQL, US',
                     'mm-dd-yy'   => 'POSTGRES, US',
                     'dd/mm/yy'   => 'SQL, EUROPEAN',
                     'dd-mm-yy'   => 'POSTGRES, EUROPEAN',
                     'dd.mm.yy'   => 'GERMAN'
                   );

sub _register_db {
  my $domain = shift;
  my $type   = shift;

  my %connect_settings;
  my $initial_sql;

  if (!%::myconfig) {
    $type = 'LXOFFICE_EMPTY';
    %connect_settings = ( driver => 'Pg' );

  } elsif ($type eq 'LXOFFICE_AUTH') {
    %connect_settings = ( driver          => $::myconfig{dbdriver} || 'Pg',
                          database        => $::auth->{DB_config}->{db},
                          host            => $::auth->{DB_config}->{host},
                          port            => $::auth->{DB_config}->{port} || 5432,
                          username        => $::auth->{DB_config}->{user},
                          password        => $::auth->{DB_config}->{password},
                          connect_options => { pg_enable_utf8 => $::locale && $::locale->is_utf8,
                                             });
  } else {
    my $european_dates = 0;
    if ($::myconfig{dateformat}) {
      $european_dates = 1 if $_dateformats{ $::myconfig{dateformat} } =~ m/european/i;
    }

    %connect_settings = ( driver          => $::myconfig{dbdriver} || 'Pg',
                          database        => $::myconfig{dbname},
                          host            => $::myconfig{dbhost},
                          port            => $::myconfig{dbport} || 5432,
                          username        => $::myconfig{dbuser},
                          password        => $::myconfig{dbpasswd},
                          connect_options => { pg_enable_utf8 => $::locale && $::locale->is_utf8,
                                             },
                          european_dates  => $european_dates);
  }

  my %flattened_settings = _flatten_settings(%connect_settings);

  $domain = 'LXOFFICE' if $type =~ m/^LXOFFICE/;
  $type  .= join($SUBSCRIPT_SEPARATOR, map { ($_, $flattened_settings{$_}) } sort keys %flattened_settings);
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

1;
