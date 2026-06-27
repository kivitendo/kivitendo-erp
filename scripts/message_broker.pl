#!/usr/bin/perl

use strict;

my $exe_dir;

BEGIN {
  use FindBin;

  unshift(@INC, $FindBin::Bin . '/../modules/override'); # Use our own versions of various modules (e.g. YAML).
  push   (@INC, $FindBin::Bin . '/..');                  # '.' will be removed from @INC soon.
}

use Mojolicious::Lite;
#use Mojo::Transaction::WebSocket;

use DateTime;
use List::Util qw(first);
use Data::Dumper;
use CGI qw( -no_xhtml);
use Cwd;
use POSIX qw(locale_h setlocale);

use SL::Locale;
use SL::LXDebug;
use SL::LxOfficeConf;
use SL::Form;
use SL::Auth::Constants qw(:all);

use SL::DBUtils;
use SL::DB::AsyncEvent;
use SL::DB::Employee;

our %lx_office_conf;

my %ws_cons = ();

my $last_unique_string_counter;

my %totals = (
  server_start_time    => now_local_as_string(),
  ws_con_authenticated => 0,
  ws_con_errors        => 0,
  ws_msg_sent          => 0,
);

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

  $c->render(template => 'index', rows => \@rows, page_load => now_local_as_string(), totals => \%totals);
};

websocket '/ws' => sub {
  my ($ws) = @_;
  my $cookie_name    = $::lx_office_conf{authentication}{cookie_name} || 'kivitendo_session_id';
  my $session_cookie = first { $_->name eq $cookie_name } @{$ws->req->cookies};

  $totals{ws_con_errors}++;

  if (!$session_cookie) {
    return $ws->reply->exception('no session cookie');
  }

  $::auth->init;
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
  my $client_id = $::auth->get_session_value('client_id');
  my $login     = $::auth->get_session_value('login');

  $::auth->reset;
  $::auth->set_client($client_id);

  return $ws->reply->exception('!client_id') if (!$client_id);
  return $ws->reply->exception('!login') if (!$login);

  $totals{ws_con_errors}--;
  $totals{ws_con_authenticated}++;

  my %employees_by_login = map { ($_->login => $_) } @{ SL::DB::Manager::Employee->get_all };

  my $seqno_min          = 0;

  my $query  = qq|SELECT *, extract(epoch from itime) as timestamp FROM async_events WHERE id > ? ORDER BY id;|;
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
  $totals{ws_msg_sent}++;



  $ws_cons{$client_id}{$login} //= [];
  my $obj = { ws => $ws, id => unique_dt_string };
  push @{$ws_cons{$client_id}{$login}}, $obj;

  #print "$client_id $login " . Dumper([ map { $_->{id} } @{$ws_cons{$client_id}{$login} // []} ]);

  $ws->on(finish => sub {
    my ($self, $code, $reason) = @_;
    $self->app->log->debug("Connection closed. $code");
    $ws_cons{$client_id}{$login} = [ grep { $_->{id} ne $obj->{id} } @{$ws_cons{$client_id}{$login}} ];
  });

  $ws->inactivity_timeout(8*3600); # 8 hours

  $ws->on(message => sub { my ($ws, $msg) = @_; say "Client message: $client_id $login $msg" });
};

# Initialize character type locale to be UTF-8 instead of C:
foreach my $locale (qw(de_DE.UTF-8 en_US.UTF-8)) {
  last if setlocale(LC_CTYPE, $locale);
}

# for showing debug output immediately
STDOUT->autoflush;

$exe_dir = SL::System::Process->exe_dir;
chdir($exe_dir) || die "Cannot change directory to ${exe_dir}\n";

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

    my $query  = qq|SELECT *, extract(epoch from itime) as timestamp FROM async_events WHERE id > ? ORDER BY id;|;
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
        $totals{ws_msg_sent}++;
      }
    }
  }
}

Mojo::IOLoop->recurring(0.1 => sub { pong; });


app->hook(after_dispatch => sub {
  $_[0]->res->headers->remove('Server');
});

my $location = $lx_office_conf{async_events}{message_broker_listen_location}
               or die "Missing config entry: [async_events] message_broker_listen_location = \n";

my @args = scalar @ARGV
         ? @ARGV
         : ('daemon', '-l', $location, '-m', 'production');

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
body { font-family: Verdana,"Helvetica Neue",Helvetica,Arial,sans-serif; margin: 50px; }
table, th, td { border: 1px solid; }
table { border-collapse: collapse }
th, td { padding: 5px; }
th { background-color: #eee; text-align: left; }
    </style>
    <link rel="icon" type="image/x-icon" href="data:image/x-icon;base64,AAABAAEAEBAAAAEAIABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP39/QHGztQ3aoGSkylMZ9UMNlfyBzNU+BE6Wuw3V3HGgpWjetvg4yIAAAAAAAAAAAAAAAAAAAAAAAAAAO7w8hCAk6J9HkZk4Qc3XPkIOmH2Cj1j8wo9ZPIKPWPzCDpg9wk4XPcwU27PpbK8WPv7/AQAAAAAAAAAAOzu8BJed4ufBzZa+Qg7YfYLPmXwCz9n7Qw/aOwLPmbtCjlg8Qg1WvYHMlb6Ay9R/w8zUvGPnapu+/v8BPr6+wV4jZyFBzZa+Qo8Y/MLPmbuDEBp6Q1AaOgKOF7uCTZW9wtIWf0QY2D/E3dm/xN9Z/8PamD/GEpb7qSwulm7xcxBGUJi5gk8Y/QLP2buDUBp6As7YuoJN1f2DlZe/hWJbf8ZonH/Gq50/xqtcv8bunv/G7h5/xWSbv8qVWfaXHWJoQc4XvcLPmXwDD9n6wk2W/ALRFn8FYJr/xmocv8YoWr/Fo9f/xiVY/8VkGD/FpVj/xqzdv8arXb/DExX/iBFYt4JO2L1Cz1k7wg0WPUOVF3+GZ90/xaYZf8Zl2X/HnhU/yeAXv8mfFr/H5pp/xWQYP8btHf/F55y/yJSY+IJNFX1Cjxi9Ag0V/cOVl3+GaJx/xeeaP8clmX/MYNo/2K3rP9ovLT/L3Zc/x6MYP8WlGP/G7N3/xJvZP12ipqICTRV9gc2WvkLRlf+GaBy/xmrcf8ZjmD/KXtb/2zBuv+L6ez/XK6i/yaFYP8WiVz/Gatx/xKJa/9AZXfD4eToHCFGYt4FMVH+FH9p/xqzdv8Vjl7/IJlp/ytyVv9EkX7/PpF5/yONZP8XjV7/GKZu/xOLbP8rWmvaxczTOAAAAABgdomeBzpQ/xmjc/8btnj/FpJh/xqibf8fjGH/HIRa/xmSYv8Vj17/GKdy/xB0ZP8zXXDQv8fPPQAAAAAAAAAAwcjPOx5NXucXonL/G7h5/xmmbv8Ypm7/Fphk/xilbf8YpG7/E4xq/xReYvdZdYim1drfKAAAAAAAAAAAAAAAAPv8/AOBlKJ9EmZh+hefcf8arXf/Gap1/xeecv8Tg2r/F2Jk9ENner+ksLtZ9PX2CgAAAAAAAAAAAAAAAAAAAAAAAAAA7/HzD36Qn4AnVWXdD05Y+RFOWvcoVWfcW3WIpKiyvlXr7e8SAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA//8AAP//AAD4HwAA8AcAAMADAACAAQAAgAAAAAAAAAAAAAAAAAAAAAABAAAAAwAAAAcAAIAPAADAPwAAwP8AAA==">
  </head>
  <body>
    <h1>kivitendo Message Broker Statistics</h1>

    <table>
      <tr>
        <th>
          broker start time
        </th>
        <td>
          %= $totals->{server_start_time}
        </td>
      </tr>
      <tr>
        <th>
          page loaded at
        </th>
        <td>
          %= $page_load
        </td>
      </tr>
      <tr>
        <th>
          total WS connections authenticated
        </th>
        <td>
          %= $totals->{ws_con_authenticated}
        </td>
      </tr>
      <tr>
        <th>
          total WS connection errors
        </th>
        <td>
          %= $totals->{ws_con_errors}
        </td>
      </tr>
      <tr>
        <th>
          total WS messages sent
        </th>
        <td>
          %= $totals->{ws_msg_sent}
        </td>
      </tr>
    </table>

    <h2>Current WebSocket Connections</h2>
    <table>
      <tr>
        <th>client ID</th>
        <th>user login</th>
        <th>WebSocket connection ID</th>
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
    <p>
      Developed for CEOS Corrected Electron Optical Systems GmbH
    <p>
    </p>
      2026 Niklas Schmidt &lt;niklas@kivitendo.de&gt;
      <br>
      2023 Bernd Bleßmann &lt;bernd@kivitendo-premium.de&gt;
    </p>
  </body>
</html>
