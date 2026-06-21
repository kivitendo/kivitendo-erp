#!/usr/bin/perl

BEGIN {
  use FindBin;

  if (! -d "bin" || ! -d "SL") {
    print("This tool must be run from the kivitendo ERP base directory.\n");
    exit(1);
  }

  unshift @INC, $FindBin::Bin . '/../modules/override'; # Use our own versions of various modules (e.g. YAML).
  push    @INC, $FindBin::Bin . '/..';
}

use strict;
use warnings;
use feature qw(say);
use utf8;
use English '-no_match_vars';
use POSIX qw(setuid setgid);
use Text::CSV_XS;

use Config::Std;
use DBI;
use SL::LXDebug;
use SL::LxOfficeConf;

use SL::DBUtils;
use SL::DB::Contact;
use SL::DB::Customer;
use SL::DB::Vendor;
use SL::DB::AuthUserConfig;
use SL::Auth;
use SL::Form;
use SL::User;
use SL::Locale;
use SL::File;
use SL::InstanceConfiguration;
use SL::CTI;
use SL::CTI::AsteriskManagerInterface;
use Getopt::Long;
use Pod::Usage;
use Term::ANSIColor;
use SL::Controller::PhoneNumber;
use sigtrap 'handler' => \&sig_handler, qw(INT TERM KILL QUIT);

my $running = 1;

sub sig_handler {
  my $sig_name = shift;
  $running = 0;
  print "received $sig_name, shutting down\n";
}

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

  my $client = $config{client};

  if (!$client) {
    error("Please provide a client:");
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

sub main_loop {
  my $ami = SL::CTI::AsteriskManagerInterface->new();
  $ami->event_start_listen();

  my %ev_dispatch = (
    DialBegin => sub {
      #print $main::lxdebug->dump(0, 'Event', $_[0]->{Event});
      my $num_from = $_[0]->{CallerIDNum};
      #my $num_to   = $_[0]->{Exten};
      my $exten_to = $_[0]->{DestChannel}; $exten_to =~ s/-[a-z0-9]*$//;
      handle_incoming_call($num_from, $exten_to);
    },
    ExtensionStatus => sub {
      #print $main::lxdebug->dump(0, 'Event', $_[0]->{Event});
    },
  );

  while ($running) {
    my $ev = $ami->event_get_next();
    return if !$ev->{Event};
    #print $main::lxdebug->dump(0, 'Event', $ev);
    #print "Event: $ev->{Event}\n";
    my $func = $ev_dispatch{$ev->{Event}};
    $func->($ev) if defined $func;
  }
}

# Anruf von 301 zu 306
# 'AccountCode' => '',
# 'CallerIDName' => 'Niklas',
# 'CallerIDNum' => '301',
# 'Channel' => 'PJSIP/genuine-00000027',
# 'ChannelState' => '4',
# 'ChannelStateDesc' => 'Ring',
# 'ConnectedLineName' => '<unknown>',
# 'ConnectedLineNum' => '<unknown>',
# 'Context' => 'toll-o2',
# 'DestAccountCode' => '',
# 'DestCallerIDName' => 'Niklas',
# 'DestCallerIDNum' => '306',
# 'DestChannel' => 'PJSIP/webtux14-00000028',
# 'DestChannelState' => '0',
# 'DestChannelStateDesc' => 'Down',
# 'DestConnectedLineName' => 'Niklas',
# 'DestConnectedLineNum' => '301',
# 'DestContext' => 'toll',
# 'DestExten' => '306',
# 'DestLanguage' => 'en',
# 'DestLinkedid' => '1776269938.56',
# 'DestPriority' => '1',
# 'DestUniqueid' => '1776269938.57',
# 'DialString' => 'webtux14/sip:464vi29l@192.168.1.10:49814;transport=ws;x-ast-orig-host=192.0.2.91:0',
# 'Event' => 'DialBegin',
# 'Exten' => '306',
# 'Language' => 'en',
# 'Linkedid' => '1776269938.56',
# 'Priority' => '1',
# 'Privilege' => 'call,all',
# 'Uniqueid' => '1776269938.56'

sub handle_incoming_call {
  my ($num, $exten_to) = @_;

  return unless $num;

  my $user_configs = $exten_to ? SL::DB::Manager::AuthUserConfig->get_all(
    where => [
      cfg_key      => 'phone_extension',
      cfg_value => $exten_to,
    ],
    with_objects => [ qw(user) ],
  ) : [];

  my @user_ids = map { $_->{user}{id} } @$user_configs;

  return unless @user_ids;

  print "call to user id " . (join ", ", @user_ids) . "\n";

  my $phone_number = SL::Controller::PhoneNumber->new();
  my $number = $phone_number->normalize_number($num // '');

  print "call from number $number\n";
  my $msg = "$number ";

  my $contact = $phone_number->find_contact_for_number($number);
  if ($contact) {
    $msg .= "(".$contact->{full_name};
    #$main::lxdebug->dump(0, '', $contact);

    my $c = SL::DB::Contact->new(cp_id => $contact->{id})->load;
    my $cv = SL::DB::Manager::Customer->get_first(where => [id => $c->cp_cv_id]) //
             SL::DB::Manager::Vendor->get_first(where => [id => $c->cp_cv_id]);
    $msg .= ' ';
    $msg .= $cv->is_customer
           ? SL::DB::Customer->new(id => $cv->{id})->load->presenter->customer(target => '_blank')
           : SL::DB::Vendor  ->new(id => $cv->{id})->load->presenter->vendor  (target => '_blank');
    $msg .= ')';
  }

  my $cv = $phone_number->find_customer_vendor_for_number($number);
  if ($cv) {
    $msg .= $cv->{type} eq 'customer'
           ? SL::DB::Customer->new(id => $cv->{id})->load->presenter->customer(target => '_blank')
           : SL::DB::Vendor  ->new(id => $cv->{id})->load->presenter->vendor  (target => '_blank');

    my $open_orders = SL::DB::Manager::Order->get_all(
              query   => [
                           "$cv->{type}_id" => $cv->{id},
                           closed      => 'F',
                         ],
              sort_by => 'transdate DESC',
            );
    $msg .= join(', ', (map {
      $_->record_type . ' ' . $_->presenter->show()
    } @$open_orders));
  }

  my $dbh = SL::DB->client->dbh;
  my $sql = "INSERT INTO async_events (user_id, subject, body) VALUES (?, ?, ?);";
  my $sth = prepare_query(undef, $dbh, $sql);
  for my $user_id (@user_ids) {
    do_statement(undef, $sth, $sql, $user_id, 'Telefonanruf', $msg);
  }
  $sth->finish;
}



parse_args(\%config);
setup();
while ($running) {
  main_loop();
  if ($running) {
    print "reconnect\n";
    sleep(2);
  }
}

1;
