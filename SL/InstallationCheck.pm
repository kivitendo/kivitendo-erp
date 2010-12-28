package SL::InstallationCheck;

use English '-no_match_vars';
use IO::File;

use vars qw(@required_modules @optional_modules);

use strict;

BEGIN {
@required_modules = (
  { name => "parent",                              url => "http://search.cpan.org/~corion/" },
  { name => "Archive::Zip",    version => '1.16',  url => "http://search.cpan.org/~adamk/" },
  { name => "Class::Accessor", version => '0.30',  url => "http://search.cpan.org/~kasei/" },
  { name => "CGI::Ajax",       version => '0.697', url => "http://search.cpan.org/~bct/" },
  { name => "DateTime",                            url => "http://search.cpan.org/~drolsky/" },
  { name => "DBI",             version => '1.50',  url => "http://search.cpan.org/~timb/" },
  { name => "DBD::Pg",         version => '1.49',  url => "http://search.cpan.org/~dbdpg/" },
  { name => "Email::Address",                      url => "http://search.cpan.org/~rjbs/" },
  { name => "FCGI",                                url => "http://search.cpan.org/~mstrout/" },
  { name => "List::MoreUtils", version => '0.21',  url => "http://search.cpan.org/~vparseval/" },
  { name => "PDF::API2",       version => '2.000', url => "http://search.cpan.org/~areibens/" },
  { name => "Template",        version => '2.18',  url => "http://search.cpan.org/~abw/" },
  { name => "Text::CSV_XS",    version => '0.23',  url => "http://search.cpan.org/~hmbrand/" },
  { name => "Text::Iconv",     version => '1.2',   url => "http://search.cpan.org/~mpiotr/" },
  { name => "URI",             version => '1.35',  url => "http://search.cpan.org/~gaas/" },
  { name => "XML::Writer",     version => '0.602', url => "http://search.cpan.org/~josephw/" },
  { name => "YAML",            version => '0.62',  url => "http://search.cpan.org/~ingy/" },
);

@optional_modules = ();

$_->{fullname} = join ' ', grep $_, @$_{qw(name version)}
  for @required_modules, @optional_modules;
}

sub module_available {
  my $module  = $_[0];
  my $version = $_[1] || '' ;

  return eval "use $module $version; 1";
}

my %conditional_dependencies;

sub check_for_conditional_dependencies {
  return if $conditional_dependencies{net_ldap}++;

  my $self = {};
  eval do { local (@ARGV, $/) = 'config/authentication.pl'; <> } or return;

  push @required_modules, { 'name' => 'Net::LDAP', 'url' => 'http://search.cpan.org/~gbarr/' }
    if $self->{module} && ($self->{module} eq 'LDAP');
}

sub test_all_modules {
  return grep { !module_available($_->{name}) } @required_modules;
}

1;
