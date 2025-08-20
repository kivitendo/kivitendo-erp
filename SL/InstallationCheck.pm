package SL::InstallationCheck;

use English '-no_match_vars';
use IO::File;

use vars qw(@required_modules @optional_modules @developer_modules);

use strict;

BEGIN {
#   name:      the name of the module if you install it with cpan
#   version:   the minimum version required to run. optional
#   url:       web path to the author page of the module
#   debian:    dpkg package name for debianoid distos
#              note: (suse) (fedora) (redhat) entries welcome if you
#              are willing to maintain them
#   dist_name: name of the package in cpan if it differs from name (ex.: LWP != libwww-perl)
@required_modules = (
  { name => "parent",                              url => "http://search.cpan.org/~corion/",    debian => 'libparent-perl' },
  { name => "Algorithm::CheckDigits",              url => "http://search.cpan.org/~mamawe/",    debian => 'libalgorithm-checkdigits-perl' },
  { name => "Archive::Zip",    version => '1.40',  url => "http://search.cpan.org/~phred/",     debian => 'libarchive-zip-perl' },
  { name => "CGI",             version => '3.43',  url => "http://search.cpan.org/~leejo/",     debian => 'libcgi-pm-perl' }, # 4.09 is not core anymore (perl 5.20)
  { name => "Clone",                               url => "http://search.cpan.org/~rdf/",       debian => 'libclone-perl' },
  { name => "Config::Std",                         url => "http://search.cpan.org/~dconway/",   debian => 'libconfig-std-perl' },
  { name => "CryptX",          version => '0.065', url => "http://search.cpan.org/~mik/",       debian => 'libcryptx-perl' },
  { name => "Daemon::Generic", version => '0.71',  url => "http://search.cpan.org/~muir/",      debian => 'libdaemon-generic-perl'},
  { name => "DateTime",                            url => "http://search.cpan.org/~drolsky/",   debian => 'libdatetime-perl' },
  { name => "DateTime::Event::Cron", version => '0.08', url => "http://search.cpan.org/~msisk/", debian => 'libdatetime-event-cron-perl' },
  { name => "DateTime::Format::Strptime",          url => "http://search.cpan.org/~drolsky/",   debian => 'libdatetime-format-strptime-perl' },
  { name => "DateTime::Set",   version => '0.12',  url => "http://search.cpan.org/~fglock/",    debian => 'libdatetime-set-perl' },
  { name => "DBI",             version => '1.50',  url => "http://search.cpan.org/~timb/",      debian => 'libdbi-perl' },
  { name => "DBD::Pg",         version => '1.49',  url => "http://search.cpan.org/~dbdpg/",     debian => 'libdbd-pg-perl' },
  { name => "Digest::SHA",                         url => "http://search.cpan.org/~mshelor/",   debian => 'libdigest-sha-perl' },
  { name => "Exception::Class", version => '1.44', url => "https://metacpan.org/pod/Exception::Class", debian => 'libexception-class-perl' },
  { name => "Email::Address",  version => '1.888', url => "http://search.cpan.org/~rjbs/",      debian => 'libemail-address-perl' },
  { name => "Email::MIME",                         url => "http://search.cpan.org/~rjbs/",      debian => 'libemail-mime-perl' },
  { name => "Encode::IMAPUTF7",                    url => "https://metacpan.org/pod/Encode::IMAPUTF7", debian => 'libencode-imaputf7-perl' },
  { name => "FCGI",            version => '0.72',  url => "http://search.cpan.org/~mstrout/",   debian => 'libfcgi-perl' },
  { name => "File::Copy::Recursive",               url => "http://search.cpan.org/~dmuey/",     debian => 'libfile-copy-recursive-perl' },
  { name => "File::Flock",   version => '2008.01', url => "http://search.cpan.org/~muir/",      debian => 'libfile-flock-perl' },
  { name => "File::MimeInfo",                      url => "http://search.cpan.org/~michielb/",  debian => 'libfile-mimeinfo-perl' },
  { name => "File::Slurp",                         url => "https://metacpan.org/author/CAPOEIRAB", debian => 'libfile-slurp-perl' },
  { name => "GD",                                  url => "http://search.cpan.org/~lds/",       debian => 'libgd-gd2-perl', },
  { name => 'HTML::Parser',                        url => 'http://search.cpan.org/~gaas/',      debian => 'libhtml-parser-perl', },
  { name => 'HTML::Restrict',                      url => 'http://search.cpan.org/~oalders/',   debian => 'libhtml-restrict-perl'},
  { name => "Image::Info",                         url => "http://search.cpan.org/~srezic/",    debian => 'libimage-info-perl' },
  { name => "Imager",                              url => "http://search.cpan.org/~tonyc/",     debian => 'libimager-perl' },
  { name => "Imager::QRCode",                      url => "http://search.cpan.org/~kurihara/",  debian => 'libimager-qrcode-perl' },
  { name => "IPC::Run",                            url => "https://metacpan.org/pod/IPC::Run",  debian => 'libipc-run-perl' },
  { name => "JSON",                                url => "http://search.cpan.org/~makamaka",   debian => 'libjson-perl' },
  { name => "List::MoreUtils", version => '0.30',  url => "http://search.cpan.org/~vparseval/", debian => 'liblist-moreutils-perl' },
  { name => "List::UtilsBy",   version => '0.09',  url => "http://search.cpan.org/~pevans/",    debian => 'liblist-utilsby-perl' },
  { name => "LWP::Authen::Digest",                 url => "http://search.cpan.org/~gaas/",      debian => 'libwww-perl', dist_name => 'libwww-perl' },
  { name => "LWP::UserAgent",                      url => "http://search.cpan.org/~gaas/",      debian => 'libwww-perl', dist_name => 'libwww-perl' },
  { name => "Math::Round",                         url => "https://metacpan.org/pod/Math::Round", debian => 'libmath-round-perl' },
  { name => "Mail::IMAPClient",                    url => "https://metacpan.org/pod/Mail::IMAPClient", debian => 'libmail-imapclient-perl' },
  { name => "Params::Validate",                    url => "http://search.cpan.org/~drolsky/",   debian => 'libparams-validate-perl' },
  { name => "PBKDF2::Tiny",    version => '0.005', url => "http://search.cpan.org/~dagolden/",  debian => 'libpbkdf2-tiny-perl' },
  { name => "PDF::API2",       version => '2.000', url => "http://search.cpan.org/~areibens/",  debian => 'libpdf-api2-perl' },
  { name => "Regexp::IPv6",    version => '0.03',  url => "http://search.cpan.org/~salva/",     debian => 'libregexp-ipv6-perl' },
  { name => "REST::Client",                        url => "https://metacpan.org/pod/REST::Client", debian => 'librest-client-perl' },
  { name => "Rose::Object",                        url => "http://search.cpan.org/~jsiracusa/", debian => 'librose-object-perl' },
  { name => "Rose::DB",                            url => "http://search.cpan.org/~jsiracusa/", debian => 'librose-db-perl' },
  { name => "Rose::DB::Object", version => 0.788,  url => "http://search.cpan.org/~jsiracusa/", debian => 'librose-db-object-perl' },
  { name => "Set::Infinite",    version => '0.63', url => "http://search.cpan.org/~fglock/",    debian => 'libset-infinite-perl' },
  { name => "String::ShellQuote", version => 1.01, url => "http://search.cpan.org/~rosch/",     debian => 'libstring-shellquote-perl' },
  { name => "Sort::Naturally",                     url => "http://search.cpan.org/~sburke/",    debian => 'libsort-naturally-perl' },
  { name => "Template",        version => '2.18',  url => "http://search.cpan.org/~abw/",       debian => 'libtemplate-perl' },
  { name => "Text::CSV_XS",    version => '0.23',  url => "http://search.cpan.org/~hmbrand/",   debian => 'libtext-csv-xs-perl' },
  { name => "Text::Iconv",     version => '1.2',   url => "http://search.cpan.org/~mpiotr/",    debian => 'libtext-iconv-perl' },
  { name => "Text::Unidecode",                     url => "http://search.cpan.org/~sburke/",    debian => 'libtext-unidecode-perl' },
  { name => "Try::Tiny",                           url => "https://metacpan.org/release/Try-Tiny", debian => 'libtry-tiny-perl' },
  { name => "URI",             version => '1.35',  url => "http://search.cpan.org/~gaas/",      debian => 'liburi-perl' },
  { name => "UUID::Tiny",                          url => "https://metacpan.org/pod/UUID::Tiny",  debian => 'libuuid-tiny-perl' },
  { name => "XML::LibXML",                         url => "https://metacpan.org/pod/XML::LibXML", debian => 'libxml-libxml-perl' },
  { name => "XML::Writer",     version => '0.602', url => "http://search.cpan.org/~josephw/",   debian => 'libxml-writer-perl' },
  { name => "YAML",            version => '0.62',  url => "http://search.cpan.org/~ingy/",      debian => 'libyaml-perl' },
);

@optional_modules = (
  { name => 'HTTP::DAV', version => 0.46,          url => 'http://search.cpan.org/~cosimo/',    debian => 'libhttp-dav-perl' },
  { name => "IO::Socket::SSL",                     url => "http://search.cpan.org/~sullr/",     debian => 'libio-socket-ssl-perl' },
  { name => "Net::LDAP",                           url => "http://search.cpan.org/~gbarr/",     debian => 'libnet-ldap-perl' },
  # Net::SMTP is core since 5.7.3
  { name => "Net::SMTP::SSL",                      url => "http://search.cpan.org/~cwest/",     debian => 'libnet-smtp-ssl-perl' },
  { name => "Net::SSLGlue",                        url => "http://search.cpan.org/~sullr/",     debian => 'libnet-sslglue-perl' },
  { name => "YAML::XS",                            url => "https://metacpan.org/pod/distribution/YAML-LibYAML/lib/YAML/LibYAML.pod", debian => 'libyaml-libyaml-perl' },
);

@developer_modules = (
  { name => "DBIx::Log4perl",                      url => "http://search.cpan.org/~mjevans/", },
  { name => "Devel::REPL",                         url => "http://search.cpan.org/~doy/",       debian => 'libdevel-repl-perl' },
  { name => "Term::ReadLine::Gnu",                 url => "http://search.cpan.org/~hayashi/",   debian => 'libterm-readline-gnu-perl' },
  { name => "Log::Log4perl",                       url => "http://search.cpan.org/~mschilli/",  debian => 'liblog-log4perl-perl' },
  { name => "LWP::Simple",                         url => "http://search.cpan.org/~gaas/",      debian => 'libwww-perl', dist_name => 'libwww-perl' },
  { name => "Moose::Role",                         url => "http://search.cpan.org/~doy/",       debian => 'libmoose-perl' },
  { name => "Sys::CPU",                            url => "http://search.cpan.org/~mkoderer/",  debian => 'libsys-cpu-perl' },
  { name => "Test::Deep",                          url => "http://search.cpan.org/~rjbs/",      debian => 'libtest-deep-perl' },
  { name => "Test::Exception",                     url => "http://search.cpan.org/~adie/",      debian => 'libtest-exception-perl' },
  { name => "Test::Output",                        url => "http://search.cpan.org/~bdfoy/",     debian => 'libtest-output-perl' },
  { name => "Thread::Pool::Simple",                url => "http://search.cpan.org/~jwu/",       debian => 'libthread-pool-simple-perl' },
  { name => "URI::Find",                           url => "http://search.cpan.org/~mschwern/",  debian => 'liburi-find-perl' },
  { name => "GD",              version => '2.00',  url => "http://search.cpan.org/~lds/",       debian => 'libgd-perl' },
  { name => "Rose::DB::Object", version => 0.809,  url => "http://search.cpan.org/~jsiracusa/", debian => 'librose-db-object-perl' },
  { name => "PPI",                                 url => "ttps://metacpan.org/pod/PPI",        debian => 'libppi-perl' },

  # first available in debian trixie and ubuntu 23.10
  { name => "HTML::Query",                         url => "http://search.cpan.org/~kamelkev/",  debian => 'libhtml-query-perl' },
);

$_->{fullname} = join ' ', grep $_, @$_{qw(name version)}
  for @required_modules, @optional_modules, @developer_modules;

}

sub module_available {
  my $module  = $_[0];
  my $version = $_[1] || '' ;

  my $got = eval "use $module $version (); 1";

  if ($got) {
    return ($got, $module->VERSION);
  } else {
    return
  }
}

sub check_kpsewhich {
  my $exit = system("which kpsewhich > /dev/null");

  return $exit > 0 ? 0 : 1;
}

sub template_dirs {
  my ($path) = @_;
  opendir my $dh, $path || die "can't open $path";
  my @templates = sort grep { !/^\.\.?$/ } readdir $dh;
  close $dh;

  return @templates;
}

sub classes_from_latex {
  my ($path, $class) = @_;
  eval { require String::ShellQuote; 1 } or warn "can't load String::ShellQuote" && return;
  $path  = String::ShellQuote::shell_quote $path;
  $class = String::ShellQuote::shell_quote $class;

  open my $pipe, q#egrep -rs '^[\ \t]*# . "$class' $path". q# | sed 's/ //g' | awk -F '{' '{print $2}' | awk -F '}' '{print $1}' |#;
  my @cls = <$pipe>;
  close $pipe;

  # can't use uniq here
  my %class_hash = map { $_ => 1 } map { s/\n//; $_ } split ',', join ',', @cls;
  return sort keys %class_hash;
}

my %conditional_dependencies;

sub check_for_conditional_dependencies {
  return if $conditional_dependencies{net_ldap}++;

  push @required_modules, grep { $_->{name} eq 'Net::LDAP' } @optional_modules
    if $::lx_office_conf{authentication} && ($::lx_office_conf{authentication}->{module} eq 'LDAP');
}

sub test_all_modules {
  return grep { !module_available($_->{name}) } @required_modules;
}

1;
