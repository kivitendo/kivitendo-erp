#!/usr/bin/perl

BEGIN {
  if (! -d "bin" || ! -d "SL") {
    print("This tool must be run from the kivitendo ERP base directory.\n");
    exit(1);
  }

  unshift @INC, "modules/override"; # Use our own versions of various modules (e.g. YAML).
  push    @INC, "modules/fallback"; # Only use our own versions of modules if there's no system version.
}


use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use POSIX qw(setuid setgid);
use Text::CSV_XS;

use Config::Std;
use DBI;
use SL::LXDebug;
use SL::LxOfficeConf;

use SL::DBUtils;
use SL::Auth;
use SL::Form;
use SL::User;
use SL::Locale;
use SL::File;
use SL::InstanceConfiguration;
use Getopt::Long;
use Pod::Usage;
use Term::ANSIColor;

my %config;

sub parse_args {
  my ($options) = @_;
  GetOptions(
    'client=s'          => \ my $client,
  );

  $options->{client}   = $client;
}

sub setup {

  SL::LxOfficeConf->read;

  my $client = $config{client} || $::lx_office_conf{devel}{client};

  if (!$client) {
    error("No client found in config. Please provide a client:");
    usage();
  }

  $::lxdebug      = LXDebug->new();
  $::locale       = Locale->new("de");
  $::form         = new Form;
  $::auth         = SL::Auth->new();

  if (!$::auth->set_client($client)) {
    error("No client with ID or name '$client' found in config. Please provide a client:");
    usage();
  }
  $::instance_conf = SL::InstanceConfiguration->new;
  $::instance_conf->init;
}

sub error {
  print STDERR colored(shift, 'red'), $/;
}

sub usage {
  print STDERR "scripts/sync_files_from_backend.pl --client name-or-id\n" ;
  exit 1;
}

parse_args(\%config);
setup();

SL::File->sync_from_backend( file_type => 'document');
SL::File->sync_from_backend( file_type => 'attachment');
SL::File->sync_from_backend( file_type => 'image');

1;
