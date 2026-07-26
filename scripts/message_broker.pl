#!/usr/bin/perl

use strict;
use utf8;

my $exe_dir;

BEGIN {
  use FindBin;

  unshift(@INC, $FindBin::Bin . '/../modules/override'); # Use our own versions of various modules (e.g. YAML).
  push   (@INC, $FindBin::Bin . '/..');                  # '.' will be removed from @INC soon.
}

use Mojolicious::Lite;
#use Mojo::Transaction::WebSocket;
use Mojo::IOLoop::Client;

use Crypt::Misc qw(slow_eq);
use DateTime;
use List::Util qw(first);
use Data::Dumper;
use CGI qw( -no_xhtml);
use Cwd;
use POSIX qw(locale_h setlocale);
use Crypt::Misc 'slow_eq';

use SL::Locale;
use SL::LXDebug;
use SL::LxOfficeConf;
use SL::Form;
use SL::Auth::Constants qw(:all);
use SL::Auth::Password;

use SL::DBUtils;
use SL::DB::AsyncEvent;
use SL::DB::Employee;
use SL::Controller::PhoneNumber;

our %lx_office_conf;

my %ami = (
  state => 0,
  connection_count => 0,
);

my @ami_log = ();

my %ws_cons = ();

my %next_seqno = ();

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

  $c->render(template => 'login');
};

post '/' => sub {
  my $c = shift;

  my $password = $c->param('password');

  my $admin_password    = SL::Auth::Password->hash_if_unhashed(login => 'root', password => $::lx_office_conf{async_events}{message_broker_ui_password});
  $password             = SL::Auth::Password->hash(login => 'root', password => $password, stored_password => $admin_password);

  if (1 != Crypt::Misc::slow_eq($admin_password, $password)) {
    return $c->render(template => 'login');
  }

  my @rows = ();
  for my $client_id (sort keys %ws_cons) {
    for my $login (sort keys %{$ws_cons{$client_id}}) {
      for my $obj (sort @{$ws_cons{$client_id}{$login}}) {
        push @rows, { client => $client_id, login => $login, id => $obj->{id} };
      }
    }
  }

  $c->render(template => 'index',
    rows      => \@rows,
    page_load => now_local_as_string(),
    totals    => \%totals,
    ami       => \%ami,
    ami_calls => $ami{calls} // [],
    ami_log   => [ reverse @ami_log ],
  );
};

post '/api/call' => sub {
  my ($c) = @_;
  my $req = $c->req;


  if (1 != slow_eq('Bearer '.$::lx_office_conf{async_events}{api_bearer_token},
                   $req->headers->header('Authorization'))) {
    return $c->reply->exception('Unauthorized');
  }

  return $c->reply->exception('AMI connection down') if $ami{state} != 2;

  my %params = %{ $req->json };

  my $config         = $::lx_office_conf{cti} || {};
  my $auto_answer    = 0;
  my $number_to_call = $params{number};
  my $channel        = $params{ami_channel};
  my $caller_id      = $params{ami_outbound_caller_id};
  my $context        = $config->{asterisk_manager_interface_originate_context};

  if (!$number_to_call || !$channel || !$caller_id || !$context) {
    return $c->reply->exception("missing parameter");
  }

  $ami{stream}->write(ami_build_request_str({
    Action   => 'Originate',
    Async    => 'true',      # Asterisk shall not wait for phone pickup before responding
    Callerid => $caller_id,
    Channel  => $channel,
    Context  => $context,
    Exten    => $number_to_call,
    Priority => '1',
    (Variable => 'PJSIP_HEADER(add,Alert-Info)=<http://notused>;info=alert-autoanswer;delay=0') x !!$auto_answer,
  }));

  push @ami_log, { type => 'AMI', subtype => 'Originate', ts => now_local_as_string() };

  $c->render(json => {});
};

websocket '/ws' => sub {
  my ($ws) = @_;
  my $cookie_name    = $::lx_office_conf{authentication}{cookie_name} || 'kivitendo_session_id';
  my $session_cookie = first { $_->name eq $cookie_name } @{$ws->req->cookies};

  $::request       = SL::Request->new(
    cgi            => CGI->new({}),
    layout         => SL::Layout::None->new,
  );

  #my $session_result = $::auth->restore_session;
  #$::auth->create_or_refresh_session;


  $totals{ws_con_errors}++;

  if (!$session_cookie) {
    return $ws->reply->exception('no session cookie');
  }

  $::auth->init;
  my $session_result = $::auth->restore_session($session_cookie->value);
  $::auth->create_or_refresh_session;

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

  return $ws->reply->exception('!client_id') if (!$client_id);

  #$::auth->reset;
  #$::auth->set_client($client_id);
  if (!$::auth->set_client($client_id)) {
    #$::auth->punish_wrong_login;
    $::auth->destroy_session;
    $::auth->create_or_refresh_session;
    return $ws->reply->exception('wrong login');
  }

  return $ws->reply->exception('!login') if (!$login);

  $totals{ws_con_errors}--;
  $totals{ws_con_authenticated}++;

  my %employees_by_login = map { ($_->login => $_) } @{ SL::DB::Manager::Employee->get_all };

  my $last_msg_id = 0+$c->param('last_msg_id');

  my $seqno_max = $next_seqno{$client_id} // 0;

  my $query  = qq|SELECT *, extract(epoch from itime) as timestamp FROM async_events WHERE ? < id AND id <= ? ORDER BY id;|;
  my $events = selectall_hashref_query($::form, SL::DB->client->dbh, $query, $last_msg_id, $seqno_max);

  foreach my $e (@$events) {
    $e->{ts_fmt} = DateTime->from_epoch(epoch => $e->{timestamp})
                           ->to_kivitendo(precision => 'minute') if $e->{timestamp};
  }

  my $user_id = $employees_by_login{$login}->auth_user->id;
  my @user_events             = grep { $_->{user_id} == $user_id } @$events;
  my @user_new_events         =                             grep { !$_->{redact_msg_id} } @user_events;
  my @user_redacted_event_ids = map { $_->{redact_msg_id} } grep {  $_->{redact_msg_id} } @user_events;
  my $last_msg_id = scalar(@user_events) ? $user_events[-1]->{id} : undef;
  my $body = SL::JSON::to_json({
    events             => \@user_new_events,
    redacted_event_ids => \@user_redacted_event_ids,
    (last_msg_id       => $last_msg_id) x !! defined($last_msg_id),
  });
  $ws->send($body);
  $totals{ws_msg_sent}++;



  $ws_cons{$client_id}{$login} //= [];
  my $obj = { ws => $ws, id => unique_dt_string, last_msg_id => $last_msg_id };
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


sub dispatch_events_for_all_clients {
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
      next if (!@user_events);

      my $last_msg_id = $user_events[-1]->{id};
      my $body = SL::JSON::to_json({
        events             => \@user_new_events,
        redacted_event_ids => \@user_redacted_event_ids,
        last_msg_id        => $last_msg_id,
      });
      for my $obj (@{$ws_cons{$client_id}{$login}}) {
        $obj->{ws}->send($body);
        $totals{ws_msg_sent}++;
      }
    }
  }
}

Mojo::IOLoop->recurring(0.1 => sub { dispatch_events_for_all_clients; });

#
# Asterisk Manager Interface for CTI
#

sub ami_spawn_connect {
  $ami{state} = 1;
  $ami{connection_count}++;
  push @ami_log, { type => 'AMI', subtype => 'Connect', ts => now_local_as_string() };
  my $config = $::lx_office_conf{cti} || {};
  $ami{client} = Mojo::IOLoop->client(
    {
      address     => $config->{asterisk_manager_interface_host},
      port        => $config->{asterisk_manager_interface_port},
      tls         => 1,
      tls_options => { Timeout => 600, SSL_fingerprint => $config->{asterisk_manager_interface_ssl_fingerprint} }
    } => sub {
      my ($loop, $err, $stream) = @_;

      my $rcv_buf = '';
      my $version_header;
      $ami{state} = 2;
      $ami{stream} = $stream;
      $ami{calls} = [];

      if ($err) {
        print STDERR "AMI: $err\n";
        return;
      }
      # timeout must be larger than timeout for Action: Pong below!
      $stream->timeout(3600);

      $stream->on(read => sub {
        my ($stream, $bytes) = @_;

        my $ev_txt;
        my %kv;

        $rcv_buf .= $bytes;

        if (!$version_header && $rcv_buf =~ m/\r\n/) {
          ($version_header, $rcv_buf) = split(m/\r\n/, $rcv_buf, 2);
          $ami{version} = $version_header;
        }

        return unless ($rcv_buf =~ m/\r\n\r\n/);
        ($ev_txt, $rcv_buf) = split(m/\r\n\r\n/, $rcv_buf, 2);
        %kv = map { +( split(/: /, $_, 2) ) } split(/\r\n/, $ev_txt);
        push @ami_log, {
          type    => $kv{Response} ? 'Response'
                   : $kv{Event} ? 'Event' : '-',
          subtype => join(' ', grep { $_ } ($kv{Response}, $kv{Message}, $kv{Ping}, $kv{Event})),
          ts      => now_local_as_string(),
        };
        my $log_limit = 200;
        my $log_len   = scalar @ami_log;
        if ($log_len > $log_limit) {
          @ami_log = @ami_log[($log_len-$log_limit) .. ($log_len-1)];
        }
        ami_handle_event(\%kv);
      });

      $stream->on(error => sub {
        my ($err) = @_;
        say $err;
        $ami{state} = 0;
        delete $ami{client};
        delete $ami{stream};
        delete $ami{calls};
        push @ami_log, { type => 'AMI', subtype => 'Disconnect', ts => now_local_as_string() };
      });

      $stream->on(close => sub {
        my ($err) = @_;
        say "close";
        @ami_log = ();
        $ami{state} = 0;
        delete $ami{client};
        delete $ami{stream};
        delete $ami{calls};
        push @ami_log, { type => 'AMI', subtype => 'Disconnect', ts => now_local_as_string() };
      });

      $stream->write(ami_build_request_str({
        Action   => 'Login',
        Username => $config->{asterisk_manager_interface_username},
        Secret   => $config->{asterisk_manager_interface_secret},
      }));
      $stream->write(ami_build_request_str({
        Action    => 'WaitEvent',
        EventMask => 'call'
      }));

    }
  );
}
ami_spawn_connect();
Mojo::IOLoop->recurring(600 => sub {
  if ($ami{state} == 2) {
    # prevent timeout on IO::Socket::SSL
    $ami{stream}->write(ami_build_request_str({ Action => 'Ping' }));
  }
});
Mojo::IOLoop->recurring(30 => sub {
  if ($ami{state} == 0) {
    ami_spawn_connect();
  }
});

sub ami_handle_event {
  my ($ev) = @_;

  if (($ev->{Event}//'') eq 'DialBegin') {
    my $num_from = $ev->{CallerIDNum};
    my $exten_to = $ev->{DestChannel}; $exten_to =~ s/-[a-z0-9]*$//;


    my $calls    = handle_incoming_call($num_from, $exten_to);
    if ($calls) {
      push @{$ami{calls}}, {
        calls      => $calls,
        channel    => $ev->{DestChannel},
        remote_num => $num_from,
        ts_begin   => now_local_as_string(),
        status     => 'RINGING',
      };
    }
  } elsif (($ev->{Event}//'') eq 'DialEnd') {
    my $c = first { $_->{channel} eq $ev->{DestChannel} } @{$ami{calls}};
    if ($c) {
      $c->{ts_end} = now_local_as_string();
      $c->{status} = $ev->{DialStatus};

      foreach my $ue (@{$c->{calls}}) {
        my $ae = SL::DB::Manager::AsyncEvent->get_first(where => [ id => $ue->{async_event_id} ]);
        if ($ae) {
          SL::DB::AsyncEvent->new(
            msg_type      => $ev->{DialStatus} eq 'BUSY'     ? 'callreject'
                           : $ev->{DialStatus} eq 'ANSWER'   ? 'callanswer'
                           : $ev->{DialStatus} eq 'CANCEL'   ? 'callmiss'
                           : $ev->{DialStatus} eq 'NOANSWER' ? 'callmiss'
                                                             : 'call',
            user_id       => $ae->user_id,
            subject       => $ae->subject,
            body          => $ae->body,
          )->save;
          SL::DB::AsyncEvent->new(
            redact_msg_id => $ae->id,
            user_id       => $ae->user_id,
          )->save;
          $ae->delete;
        }
      }
    }
  }
}

sub ami_build_request_str {
  my ($params) = @_;
  (join "\n", map { ami_encode($_) . ': ' . ami_encode($params->{$_}) } sort keys %$params) . "\n\n";
}

sub ami_encode {
  my ($s) = @_;
  return '' unless defined $s;
  $s =~ s/[\r\n\\]*//g;      # delete unsupported characters
  $s;
}

sub handle_incoming_call {
  my ($num, $exten_to) = @_;

  return unless $num;
  my $client_id = $::lx_office_conf{async_events}{client_id_for_phone_lookup};
  return unless $client_id;
  $::auth->set_client($client_id);

  my $user_configs = $exten_to ? SL::DB::Manager::AuthUserConfig->get_all(
    where => [
      cfg_key      => 'ami_channel',
      cfg_value => $exten_to,
    ],
    with_objects => [ qw(user) ],
  ) : [];


  return unless @$user_configs;


  my $phone_number = SL::Controller::PhoneNumber->new();
  my $number = $phone_number->normalize_number($num // '');

  my $msg = "$number ";

  my $contact = $phone_number->find_contact_for_number($number);
  if ($contact) {
    $msg .= "(".$contact->{full_name};

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

  my @users_and_events = ();
  foreach my $user_conf (@$user_configs) {
    my $user_id = $user_conf->{user}{id};
    my $login   = $user_conf->{user}{login};
    my $e = SL::DB::AsyncEvent->new(
      msg_type => 'call',
      user_id => $user_id,
      subject => 'Tel.',
      body    => $msg,
    );
    $e->save;
    push @users_and_events, {
      login          => $login,
      async_event_id => $e->id,
    };
  }

  \@users_and_events;
}




app->hook(after_dispatch => sub {
  $_[0]->res->headers->remove('Server');
});

my $location = $lx_office_conf{async_events}{message_broker_listen_location}
               or die "Missing config entry: [async_events] message_broker_listen_location = \n";

my @args = scalar @ARGV
         ? @ARGV
         : ('daemon', '-l', $location, '-m', 'production');

app->start(@args);

if ($ami{stream}) {
  $ami{stream}->handle->stop_SSL(SSL_fast_shutdown => 0);
  #$ami{stream}->close(SSL_fast_shutdown => 0);
}

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

@@ login.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title>kivitendo Message Broker Statistics</title>
  </head>
  <body>
    <form action="." method="post">
      Login required: <input type="password" name="password" />
    </form>
  </body>
</html>



@@ index.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title>kivitendo Message Broker Statistics</title>
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
        <th>?last_msg_id=</th>
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
        <td>
          %= $row->{last_msg_id}
        </td>
      </tr>
      % }
    </table>

    <h2>Asterisk Manager Interface</h2>

    <table>
      <tr>
        <th>
          total AMI connection count
        </th>
        <td>
          %= $ami->{connection_count}
        </td>
      </tr>
      <tr>
        <th>
          remote AMI version
        </th>
        <td>
          %= $ami->{version}
        </td>
      </tr>
      <tr>
        <th>
          AMI state
        </th>
        <td>
          %= $ami->{state}
        </td>
      </tr>
    </table>

    <h2>AMI Dial Event Log</h2>

    <table>
      <tr>
        <th>channel</th>
        <th>status</th>
        <th>remote num</th>
        <th>timestamp begin</th>
        <th>timestamp end</th>
        <th>users notified</th>
      </tr>
      % for my $row (@$ami_calls) {
      <tr>
        <td>
          %= $row->{channel}
        </td>
        <td>
          %= $row->{status}
        </td>
        <td>
          %= $row->{remote_num}
        </td>
        <td>
          %= $row->{ts_begin}
        </td>
        <td>
          %= $row->{ts_end}
        </td>
        <td>
          % for my $c (@{$row->{calls}}) {
          %= $c->{login}
          % }
        </td>
      </tr>
      % }
    </table>


    <h2>AMI Event Log</h2>

    <table>
      <tr>
        <th>Evt/Resp</th>
        <th>subtype</th>
        <th>timestamp</th>
      </tr>
      % for my $row (@$ami_log) {
      <tr>
        <td>
          %= $row->{type}
        </td>
        <td>
          %= $row->{subtype}
        </td>
        <td>
          %= $row->{ts}
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
