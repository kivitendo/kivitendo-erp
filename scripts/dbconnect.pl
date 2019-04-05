#!/usr/bin/perl

BEGIN {
  use FindBin;

  unshift(@INC, $FindBin::Bin . '/../modules/override'); # Use our own versions of various modules (e.g. YAML).
  push   (@INC, $FindBin::Bin . '/..');                  # '.' will be removed from @INC soon.
}

use strict;
use warnings;

use Data::Dumper;
use DBI;
use List::MoreUtils qw(any);
use SL::LxOfficeConf;

our %lx_office_conf;
SL::LxOfficeConf->read;

sub psql {
  my ($title, %params) = @_;
  print "Connecting to ${title} database '" . $params{db} . "' on " . $params{host} . ':' . $params{port} . " with PostgreSQL username " . $params{user} . "\n\n";
  print "If asked for the password use this: " . $params{password} . "\n\n";
  exec "psql", "-U", $params{user}, "-h", $params{host}, "-p", $params{port}, $params{db};
}

my $settings = $lx_office_conf{'authentication/database'};
die "Missing configuration section 'authentication/database'" unless $settings;
die "Incomplete database settings" if any { !$settings->{$_} } qw (host db user);
$settings->{port} ||= 5432;

psql("authentication", %{ $settings }) if !@ARGV;

my $dbh = DBI->connect('dbi:Pg:dbname=' . $settings->{db} . ';host=' . $settings->{host} . ($settings->{port} ? ';port=' . $settings->{port} : ''), $settings->{user}, $settings->{password})
  or die "Database connection to authentication database failed: " . $DBI::errstr;

my $user_id = $dbh->selectrow_array(qq|SELECT id FROM auth.user WHERE login = ?|, undef, $ARGV[0])
  or do {
    $dbh->disconnect;
    die "No such user in authentication database: " . $ARGV[0];
  };

my $href = $dbh->selectall_hashref(qq|SELECT cfg_key, cfg_value FROM auth.user_config WHERE user_id = ?|, 'cfg_key', undef, $user_id);
$dbh->disconnect;

my %params = (
  host     => $href->{dbhost}->{cfg_value},
  db       => $href->{dbname}->{cfg_value},
  port     => $href->{dbport}->{cfg_value} || 5432,
  user     => $href->{dbuser}->{cfg_value},
  password => $href->{dbpasswd}->{cfg_value},
);

die "Incomplete database settings for user " . $ARGV[0] if any { !$settings->{$_} } qw (host db user);

psql($ARGV[0] . "'s", %params);
