package SL::CTI::AsteriskManagerInterface;

use strict;

use IO::Socket::SSL;
use List::MoreUtils qw(any);
use Crypt::PRNG;

use parent qw(Rose::Object);
use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(event_listen_actionid) ],
 'scalar --get_set_init' => [ qw(connector) ],
);


sub init_connector {
  my ($class) = @_;

  my $config = $::lx_office_conf{cti} || {};

  my $cl = IO::Socket::SSL->new(
    PeerHost        => $config->{asterisk_manager_interface_host},
    PeerPort        => $config->{asterisk_manager_interface_port},
    SSL_fingerprint => $config->{asterisk_manager_interface_ssl_fingerprint},
  ) or die "error=$!, ssl_error=$SSL_ERROR";

  syswrite($cl, _build_request_str({
    Action   => 'Login',
    Username => $config->{asterisk_manager_interface_username},
    Secret   => $config->{asterisk_manager_interface_secret},
  }));

  my $data = '';
  sysread($cl, $data, 1024);

  die 'cant connect' unless $data =~ m/^Asterisk Call Manager\/\d\.\d\.\d/;

  sysread($cl, $data, 1024);
  die 'cant login' unless $data =~ m/Response: Success/;
  die 'cant login' unless $data =~ m/Message: Authentication accepted/;

  $cl;
}

sub DESTROY {
  my ($self) = @_;
  $self->connector->close;
}

sub originate {
  my ($self, %params) = @_;

  my $config         = $::lx_office_conf{cti} || {};
  my $auto_answer    = 0;
  my $number_to_call = $params{number};
  my $channel        = $params{ami_channel};
  my $caller_id      = $params{ami_outbound_caller_id};
  my $context        = $config->{asterisk_manager_interface_originate_context};

  syswrite($self->connector, _build_request_str({
    Action   => 'Originate',
    Async    => 'true',      # Asterisk shall not wait for phone pickup before responding
    Callerid => $caller_id,
    Channel  => $channel,
    Context  => $context,
    Exten    => $number_to_call,
    Priority => '1',
    (Variable => 'PJSIP_HEADER(add,Alert-Info)=<http://notused>;info=alert-autoanswer;delay=0') x !!$auto_answer,
  }));

  my $data = '';
  sysread($self->connector, $data, 1024);

  unless ( ($data =~ m/Response: Error/   && $data =~ m/Message: Originate failed/) ||
           ($data =~ m/Response: Success/ && $data =~ m/Message: Originate successfully queued/) )
  {
    $self->connector->close;
    die 'AMI originate: ' . $data;
  }

  $data;
}

sub list_pjsip_endpoints {
  my ($self, %params) = @_;

  my $unique_id = Crypt::PRNG::random_string(12);

  syswrite($self->connector, _build_request_str({
    Action   => 'PJSIPShowEndpoints',
    ActionID => $unique_id,
  }));

  [ grep { $_->{Event} ne 'EndpointListComplete' } @{ $self->wait_for_event('EndpointListComplete', $unique_id) } ];
}

sub wait_for_event {
  my ($self, $event, $action_id, $return_with_empty_id) = @_;


  my $data = '';
  while (1) {

    if (any { $_->{Event} eq $event } @{ $self->{events_by_actionid}{$action_id} // [] }) {
      return delete $self->{events_by_actionid}{$action_id};
    }
    if ($return_with_empty_id && @{ $self->{events_by_actionid}{''} // [] }) {
      return delete $self->{events_by_actionid}{''};
    }

    die "no connection" unless $self->connector->connected;

    my $rbuf = '';
    sysread($self->connector, $rbuf, 1024);
    $data .= $rbuf;
    next unless ($data =~ m/\r\n\r\n/);

    my $ev_txt;
    ($ev_txt, $data) = split(m/\r\n\r\n/, $data, 2);
    my %kv = map { +( split(/: /, $_, 2) ) } split(/\r\n/, $ev_txt);

    if (!defined $kv{Event} && $kv{Response} eq 'Success') {
      next;
    }
    if (!defined $kv{Event} && $kv{Response} eq 'Error') {
      die $main::lxdebug->dump(0, 'AMI Error', \%kv);
      return;
    }

    push @{ $self->{events_by_actionid}{$kv{ActionID} // ''} }, \%kv if $kv{Event};

    $main::lxdebug->dump(0, 'AMI trow away: Event missing', \%kv) # ".join(", ", map { "$_: $kv{$_}" } keys %kv)."\n"
    if !$kv{Event};
  }
}

sub event_stop_listen {
  my ($self) = @_;
  $self->event_listen_actionid(undef);
}

sub event_start_listen {
  my ($self) = @_;

  $self->event_stop_listen if $self->event_listen_actionid;

  my $unique_id = Crypt::PRNG::random_string(12);
  $self->event_listen_actionid($unique_id);

  syswrite($self->connector, _build_request_str({
    Action    => 'WaitEvent',
    ActionID  => $unique_id,
    EventMask => 'call'
  }));

  $self->connector;
}

sub event_get_next {
  my ($self) = @_;

  return [] unless $self->event_listen_actionid;

  [ grep { $_->{Event} ne 'WaitEventComplete' } @{ $self->wait_for_event('WaitEventComplete', $self->event_listen_actionid, 1) } ];
}

sub _encode {
  my ($s) = @_;
  return '' unless defined $s;
  $s =~ s/[\r\n\\]*//g;      # delete unsupported characters
  $s;
}

sub _build_request_str {
  my ($params) = @_;
  (join "\n", map { _encode($_) . ': ' . _encode($params->{$_}) } sort keys %$params) . "\n\n";
}

1;


__END__

=encoding utf-8

=head1 NAME

my $ami;
$ami = SL::CTI::AsteriskManagerInterface->new();
$ami->originate;


kivitendo.conf:

[cti]
dial_command = "notused"
external_prefix =
international_dialing_prefix = 00
our_country_code = 49

asterisk_manager_interface_host              = alpine.lab
asterisk_manager_interface_port              = 5049
# openssl x509 -in asterisk.pem -noout -sha256 -fingerprint | tr -d ':'
asterisk_manager_interface_ssl_fingerprint   = 6E123BA7C3BBD8B0D03428FC099B9A3E9B67C8D76DD4341F0E7398673057552B
asterisk_manager_interface_username          = kivitendo
asterisk_manager_interface_secret            = kivi1234
asterisk_manager_interface_originate_context = toll

=cut
