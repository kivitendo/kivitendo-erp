package SL::InstallationCheck;

use English '-no_match_vars';
use IO::File;

use vars qw(@required_modules @optional_modules);

use strict;

@required_modules = (
  { name => "Archive::Zip",    url => "http://search.cpan.org/~adamk/" },
  { name => "Class::Accessor", url => "http://search.cpan.org/~kasei/" },
  { name => "CGI::Ajax",       url => "http://search.cpan.org/~bct/" },
  { name => "DateTime",        url => "http://search.cpan.org/~drolsky/" },
  { name => "DBI",             url => "http://search.cpan.org/~timb/" },
  { name => "DBD::Pg",         url => "http://search.cpan.org/~dbdpg/" },
  { name => "Email::Address",  url => "http://search.cpan.org/~rjbs/" },
  { name => "FCGI",            url => "http://search.cpan.org/~mstrout/" },
  { name => "IO::Wrap",        url => "http://search.cpan.org/~dskoll/" },
  { name => "List::MoreUtils", url => "http://search.cpan.org/~vparseval/" },
  { name => "PDF::API2",       url => "http://search.cpan.org/~areibens/" },
  { name => "Template",        url => "http://search.cpan.org/~abw/" },
  { name => "Text::CSV_XS",    url => "http://search.cpan.org/~hmbrand/" },
  { name => "Text::Iconv",     url => "http://search.cpan.org/~mpiotr/" },
  { name => "URI",             url => "http://search.cpan.org/~gaas/" },
  { name => "XML::Writer",     url => "http://search.cpan.org/~josephw/" },
  { name => "YAML",            url => "http://search.cpan.org/~ingy/" },
  { name => "parent",          url => "http://search.cpan.org/dist/parent/" },
);

@optional_modules = ();

sub module_available {
  my ($module) = @_;

  if (!defined(eval("require $module;"))) {
    return 0;
  } else {
    return 1;
  }
}

my %conditional_dependencies;

sub check_for_conditional_dependencies {
  if (!$conditional_dependencies{net_ldap}) {
    $conditional_dependencies{net_ldap} = 1;

    my $in = IO::File->new('config/authentication.pl', 'r');
    if ($in) {
      my $self = {};
      my $code;

      while (my $line = <$in>) {
        $code .= $line;
      }
      $in->close();

      eval $code;

      if (! $EVAL_ERROR) {

        if ($self->{module} && ($self->{module} eq 'LDAP')) {
          push @required_modules, { 'name' => 'Net::LDAP', 'url' => 'http://search.cpan.org/~gbarr/' };
        }
      }
    }
  }
}

sub test_all_modules {
  return grep { !module_available($_->{name}) } @required_modules;
}

1;
