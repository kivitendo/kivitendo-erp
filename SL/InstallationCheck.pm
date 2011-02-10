package SL::InstallationCheck;

use English '-no_match_vars';
use IO::File;

use vars qw(@required_modules @optional_modules);

use strict;

BEGIN {
@required_modules = (
  { name => "parent",                              url => "http://search.cpan.org/~corion/",    debian => 'libparent-perl' },
  { name => "Archive::Zip",    version => '1.16',  url => "http://search.cpan.org/~adamk/",     debian => 'libarchive-zip-perl' },
  { name => "Class::Accessor", version => '0.30',  url => "http://search.cpan.org/~kasei/",     debian => 'libclass-accessor-perl' },
  { name => "Config::Std",                         url => "http://search.cpan.org/~dconway/",   debian => 'libconfig-std-perl' },
  { name => "CGI::Ajax",       version => '0.697', url => "http://search.cpan.org/~bct/" }, # no debian package, ours contains bugfixes
  { name => "DateTime",                            url => "http://search.cpan.org/~drolsky/",   debian => 'libdatetime-perl' },
  { name => "DBI",             version => '1.50',  url => "http://search.cpan.org/~timb/",      debian => 'libdbi-perl' },
  { name => "DBD::Pg",         version => '1.49',  url => "http://search.cpan.org/~dbdpg/",     debian => 'libdbd-pg' },
  { name => "Email::Address",                      url => "http://search.cpan.org/~rjbs/",      debian => 'libemail-address-perl' },
  { name => "FCGI",                                url => "http://search.cpan.org/~mstrout/",   debian => 'libfcgi-perl' },
  { name => "List::MoreUtils", version => '0.21',  url => "http://search.cpan.org/~vparseval/", debian => 'liblist-moreutils-perl' },
  { name => "Params::Validate",                    url => "http://search.cpan.org/~drolsky/",   debian => 'libparams-validate-perl' },
  { name => "PDF::API2",       version => '2.000', url => "http://search.cpan.org/~areibens/",  debian => 'libpdf-api2-perl' },
  { name => "Rose::Object",                        url => "http://search.cpan.org/~jsiracusa/", debian => 'librose-object-perl' },
  { name => "Rose::DB",                            url => "http://search.cpan.org/~jsiracusa/", debian => 'librose-db-perl' },
  { name => "Rose::DB::Object",                    url => "http://search.cpan.org/~jsiracusa/", debian => 'librose-db-object-perl' },
  { name => "Sort::Naturally",                     url => "http://search.cpan.org/~sburke/",    debian => 'libsort-naturally-perl' },
  { name => "Template",        version => '2.18',  url => "http://search.cpan.org/~abw/",       debian => 'libtemplate-perl' },
  { name => "Text::CSV_XS",    version => '0.23',  url => "http://search.cpan.org/~hmbrand/",   debian => 'libtext-csv-xs-perl' },
  { name => "Text::Iconv",     version => '1.2',   url => "http://search.cpan.org/~mpiotr/",    debian => 'libtext-iconv-perl' },
  { name => "URI",             version => '1.35',  url => "http://search.cpan.org/~gaas/",      debian => 'liburi-perl' },
  { name => "XML::Writer",     version => '0.602', url => "http://search.cpan.org/~josephw/",   debian => 'libxml-writer-perl' },
  { name => "YAML",            version => '0.62',  url => "http://search.cpan.org/~ingy/",      debian => 'libyaml-perl' },
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

  push @required_modules, { 'name' => 'Net::LDAP', 'url' => 'http://search.cpan.org/~gbarr/' }
    if $::lx_office_conf{authentication} && ($::lx_office_conf{authentication}->{module} eq 'LDAP');
}

sub test_all_modules {
  return grep { !module_available($_->{name}) } @required_modules;
}

1;
