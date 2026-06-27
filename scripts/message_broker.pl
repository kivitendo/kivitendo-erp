#!/usr/bin/perl

use strict;

my $exe_dir;

BEGIN {
  use FindBin;

  unshift(@INC, $FindBin::Bin . '/../modules/override'); # Use our own versions of various modules (e.g. YAML).
  push   (@INC, $FindBin::Bin . '/..');                  # '.' will be removed from @INC soon.
}

use Mojolicious::Lite;
use Mojo::Transaction::WebSocket;

use IO::Socket::SSL;
#use Net::AS2::HTTPS;
#use Net::AS2;

use File::Copy qw(copy move);
use File::Path qw(make_path);
use File::Spec;
use DateTime;
use HTTP::Headers;
use MIME::Base64;
use List::Util qw(first);

use Data::Dumper;

use English qw(-no_match_vars);
use CGI qw( -no_xhtml);
use Cwd;
use POSIX qw(locale_h setlocale setuid setgid);

use SL::Locale;
use SL::LXDebug;
use SL::LxOfficeConf;
use SL::System::Process;
use SL::Form;
use SL::Auth::Constants qw(:all);

use SL::DBUtils;
use SL::DB::AsyncEvent;
use SL::DB::Employee;
use DateTime;

our %lx_office_conf;

my %ws_cons = ();

my $last_unique_string_counter;


my $_tr=<<'EOF';
sub initialize_kivitendo {
  my ($login, $client) = @_;

  chdir $exe_dir;

  package main;

  $::lxdebug       = LXDebug->new;
  $::locale        = Locale->new($::lx_office_conf{system}->{language});
  $::form          = Form->new;
  $::auth          = SL::Auth->new;

  return if !$client;

  $::auth->set_client($client->id);

  $::form->{__ERROR_HANDLER} = sub { die @_ };

  $::instance_conf = SL::InstanceConfiguration->new;
  $::request       = SL::Request->new(
    cgi            => CGI->new({}),
    layout         => SL::Layout::None->new,
  );

  die 'cannot reach auth db'               unless $::auth->session_tables_present;

  $::auth->restore_session;
  $::auth->create_or_refresh_session;

  die "cannot find user $login"            unless %::myconfig = $::auth->read_user(login => $login);
  die "cannot find locale for user $login" unless $::locale   = Locale->new($::myconfig{countrycode} || $::lx_office_conf{system}->{language});

  $::form->{login} = $login; # normaly implicit at login

  $::instance_conf->init;
}

sub cleanup_kivitendo {
  eval { SL::DB->client->dbh->rollback; };

  $::auth->save_session;
  $::auth->expire_sessions;
  $::auth->reset;

  $::form     = undef;
  $::myconfig = ();
  $::request  = undef;
  $::auth     = undef;
}

sub clean_before_sleeping {
  SL::DBConnect::Cache->disconnect_all_and_clear;
  SL::DB->db_cache->clear;

  File::Temp::cleanup();
}

sub drop_privileges {
  my $user = $lx_office_conf{as2_receiver}->{run_as};
  $user = 'www-data';
  return unless $user;

  my ($uid, $gid);
  while (my @details = getpwent()) {
    next unless $details[0] eq $user;
    ($uid, $gid) = @details[2, 3];
    last;
  }
  endpwent();

  if (!$uid) {
    print "Error: Cannot drop privileges to ${user}: user does not exist\n";
    exit 1;
  }

  if (!setgid($gid)) {
    print "Error: Cannot drop group privileges to ${user} (group ID $gid): $!\n";
    exit 1;
  }

  if (!setuid($uid)) {
    print "Error: Cannot drop user privileges to ${user} (user ID $uid): $!\n";
    exit 1;
  }
}
EOF


sub now_local_as_string {
  my $dt = DateTime->now(time_zone => DateTime::TimeZone->new(name => 'local'));
  $dt->ymd('') . '-' . $dt->hms('');
}

sub unique_dt_string {
  my $us = now_local_as_string();
  $last_unique_string_counter->{$us} = ($last_unique_string_counter->{$us} || 0) + 1;
  $us . '-' . sprintf("%05s", $last_unique_string_counter->{$us});
}

get '/' => sub {
  my $c = shift;

  my @rows = ();
  for my $client_id (sort keys %ws_cons) {
    for my $login (sort keys %{$ws_cons{$client_id}}) {
      for my $obj (sort @{$ws_cons{$client_id}{$login}}) {
        push @rows, { client => $client_id, login => $login, id => $obj->{id} };
      }
    }
  }

  $c->render(template => 'index', rows => \@rows, page_load => now_local_as_string());
};

websocket '/ws' => sub {
  my ($ws) = @_;
  my $cookie_name    = $::lx_office_conf{authentication}{cookie_name} || 'kivitendo_session_id';
  my $session_cookie = first { $_->name eq $cookie_name } @{$ws->req->cookies};

  if (!$session_cookie) {
    return $ws->reply->exception('no session cookie');
  }

  my $session_result = $::auth->restore_session($session_cookie->value);

  if ($session_result == SESSION_EXPIRED) {
    return $ws->reply->exception('SESSION_EXPIRED');
  }
  if ($session_result == SESSION_NONE) {
    return $ws->reply->exception('SESSION_NONE');
  }
  if ($session_result != SESSION_OK) {
    return $ws->reply->exception('!SESSION_OK');
  }

  $::auth->create_or_refresh_session;

  my $client_id = $::auth->get_session_value('client_id');
  my $login     = $::auth->get_session_value('login');

  eval { SL::DB->client->dbh->rollback; };

  $::auth->save_session;
  $::auth->expire_sessions;
  $::auth->reset;
  $::auth->set_client($client_id);

  my %employees_by_login = map { ($_->login => $_) } @{ SL::DB::Manager::Employee->get_all };

  my $seqno_min          = 0;

  my $query  = qq|SELECT *, extract(epoch from itime) as timestamp FROM async_events WHERE id > ?;|;
  my $events = selectall_hashref_query($::form, SL::DB->client->dbh, $query, $seqno_min);

  foreach my $e (@$events) {
    $e->{ts_fmt} = DateTime->from_epoch(epoch => $e->{timestamp})
                           ->to_kivitendo(precision => 'minute') if $e->{timestamp};
  }

  my $user_id = $employees_by_login{$login}->auth_user->id;
  my @user_events             = grep { $_->{user_id} == $user_id } @$events;
  my @user_new_events         =                             grep { !$_->{redact_msg_id} } @user_events;
  my @user_redacted_event_ids = map { $_->{redact_msg_id} } grep {  $_->{redact_msg_id} } @user_events;
  my $body = SL::JSON::to_json({ events => \@user_new_events, redacted_event_ids => \@user_redacted_event_ids });
  $ws->send($body);



  $ws_cons{$client_id}{$login} //= [];
  my $obj = { ws => $ws, id => unique_dt_string };
  push @{$ws_cons{$client_id}{$login}}, $obj;

  #print "$client_id $login " . Dumper([ map { $_->{id} } @{$ws_cons{$client_id}{$login} // []} ]);

  $ws->on(finish => sub {
    my ($self, $code, $reason) = @_;
    $self->app->log->debug("Connection closed. $code");
    $ws_cons{$client_id}{$login} = [ grep { $_->{id} ne $obj->{id} } @{$ws_cons{$client_id}{$login}} ];
  });

  $ws->inactivity_timeout(3600); # 1 hour

  $ws->on(message => sub { my ($ws, $msg) = @_; say "Client message: $client_id $login $msg" });
};

# Initialize character type locale to be UTF-8 instead of C:
foreach my $locale (qw(de_DE.UTF-8 en_US.UTF-8)) {
  last if setlocale(LC_CTYPE, $locale);
}

# for showing debug output immediately
STDOUT->autoflush;

#drop_privileges();

$exe_dir = SL::System::Process->exe_dir;
chdir($exe_dir) || die "Cannot change directory to ${exe_dir}\n";

#initialize_kivitendo('ceos', 'niklas');
#pre_run_checks();

{
  package main;
  $::form->{__ERROR_HANDLER} = sub { die @_ };
  $::lx_office_conf = undef;
  $::lx_office_conf = SL::LxOfficeConf->read();

  $::lxdebug     = LXDebug->new;
  $::locale      = Locale->new($lx_office_conf{system}->{language});

  $::auth        = SL::Auth->new;
  die 'cannot reach auth db'               unless $::auth->session_tables_present;

  # required for cookie handling in SL::Auth
  $::request       = SL::Request->new(
    cgi            => CGI->new({}),
    layout         => SL::Layout::None->new,
  );

}


my %next_seqno = ();
sub pong {
  for my $client_id (keys %ws_cons) {

    $::auth->set_client($client_id);

    my %employees_by_login = map { ($_->login => $_) } @{ SL::DB::Manager::Employee->get_all };

    my $seqno_min          = $next_seqno{$client_id} // 0;

    my $query  = qq|SELECT *, extract(epoch from itime) as timestamp FROM async_events WHERE id > ?;|;
    my $events = selectall_hashref_query($::form, SL::DB->client->dbh, $query, $seqno_min);

    foreach my $e (@$events) {
      $e->{ts_fmt} = DateTime->from_epoch(epoch => $e->{timestamp})
                             ->to_kivitendo(precision => 'minute') if $e->{timestamp};
    }

    $next_seqno{$client_id} = @$events ? ($events->[-1]{id}) : $seqno_min;

    for my $login (keys %{$ws_cons{$client_id}}) {
      my $user_id = $employees_by_login{$login}->auth_user->id;
      my @user_events             = grep { $_->{user_id} == $user_id } @$events;
      my @user_new_events         =                             grep { !$_->{redact_msg_id} } @user_events;
      my @user_redacted_event_ids = map { $_->{redact_msg_id} } grep {  $_->{redact_msg_id} } @user_events;
      next if (!@user_events && !@user_redacted_event_ids);
      my $body = SL::JSON::to_json({ events => \@user_new_events, redacted_event_ids => \@user_redacted_event_ids });
      for my $obj (@{$ws_cons{$client_id}{$login}}) {
        $obj->{ws}->send($body);
      }
    }
  }
}

Mojo::IOLoop->recurring(0.1 => sub { pong; });


app->hook(after_dispatch => sub {
  $_[0]->res->headers->remove('Server');
});

my @args = scalar @ARGV
         ? @ARGV
         : ('daemon', '-l', 'http://*:8081', '-m', 'production');

app->start(@args);

1;

__DATA__
@@ not_found.html.ep
<!DOCTYPE html>
<html>
  <head><title>Page not found</title></head>
  <body>Page not found</body>
</html>

@@ exception.html.ep
<!DOCTYPE html>
<html>
  <head><title>Error</title></head>
  <body>An error occurred</body>
</html>


@@ index.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title>kivitendo Message Broker Statistics</title>
    <meta http-equiv="refresh" content="5">
    <style>
table, th, td { border: 1px solid; }
table { border-collapse: collapse }
th, td { padding: 5px; }
th { background-color: #eee; }
    </style>
  </head>
  <body>
    <h1>kivitendo Message Broker Statistics</h1>
    <p>
      Current Websocket connections:
    </p>
    <table>
      <tr>
        <th>client ID</th>
        <th>user login</th>
        <th>Websocket connection ID</th>
      </tr>
      % for my $row (@$rows) {
      <tr>
        <td>
          %= $row->{client}
        </td>
        <td>
          %= $row->{login}
        </td>
        <td>
          %= $row->{id}
        </td>
      </tr>
      % }
    </table>
    <p>Page loaded
    %= $page_load
    </p>
    <p>
      Developed for CEOS Corrected Electron Optical Systems GmbH
      <br>
      2026 Niklas Schmidt &lt;niklas@kivitendo.de&gt;
      <br>
      2023 Bernd Bleßmann &lt;bernd@kivitendo-premium.de&gt;
    </p>
  </body>
</html>
