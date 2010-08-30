package SL::DB;

use strict;

use Carp;
use Data::Dumper;
use English qw(-no_match_vars);
use Rose::DB;

use base qw(Rose::DB);

__PACKAGE__->use_private_registry;

my (%_db_registered, %_initial_sql_executed);

sub create {
  my $domain = shift || SL::DB->default_domain;
  my $type   = shift || SL::DB->default_type;

  if ($type eq 'LXOFFICE') {
    $domain = 'LXEMPTY' unless %::myconfig && $::myconfig{dbname};
    $type   = join $SUBSCRIPT_SEPARATOR, map { $::myconfig{$_} } qw(dbdriver dbname dbhost dbport dbuser dbpasswd) if %::myconfig;
  }

  _register_db($domain, $type);

  my $db = __PACKAGE__->new_or_cached(domain => $domain, type => $type);

  return $db;
}

sub _register_db {
  my $domain = shift;
  my $type   = shift;

  my $idx    = "${domain}::${type}";
  return if $_db_registered{$idx};

  $_db_registered{$idx} = 1;

  __PACKAGE__->register_db(domain          => $domain,
                           type            => $type,
                           driver          => $::myconfig{dbdriver} || 'Pg',
                           database        => $::myconfig{dbname},
                           host            => $::myconfig{dbhost},
                           port            => $::myconfig{dbport} || 5432,
                           username        => $::myconfig{dbuser},
                           password        => $::myconfig{dbpasswd},
                           connect_options => { pg_enable_utf8 => $::locale && $::locale->is_utf8,
                                              },
                          );
}

1;
