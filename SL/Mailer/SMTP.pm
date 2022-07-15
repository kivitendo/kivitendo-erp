package SL::Mailer::SMTP;

use strict;

use parent qw(Rose::Object);

use Rose::Object::MakeMethods::Generic
(
  scalar => [ qw(myconfig mailer form status extended_status) ]
);

my %security_config = (
  none => { require_module => 'Net::SMTP',          package => 'Net::SMTP',      port =>  25 },
  tls  => { require_module => 'Net::SSLGlue::SMTP', package => 'Net::SMTP',      port =>  25 },
  ssl  => { require_module => 'Net::SMTP::SSL',     package => 'Net::SMTP::SSL', port => 465 },
);

sub init {
  my ($self) = @_;

  Rose::Object::init(
    @_,
    status          => 'failed',
    extended_status => 'no send attempt made',
  );

  my $cfg           = $::lx_office_conf{mail_delivery} || {};
  $self->{security} = exists $security_config{lc $cfg->{security}} ? lc $cfg->{security} : 'none';
  my $sec_cfg       = $security_config{ $self->{security} };

  eval "require $sec_cfg->{require_module}" or do {
    $self->extended_status("$@");
    die $self->extended_status;
  };

  $self->{smtp} = $sec_cfg->{package}->new($cfg->{host} || 'localhost', Port => $cfg->{port} || $sec_cfg->{port});
  if (!$self->{smtp}) {
    $self->extended_status('SMTP connection could not be initialized');
    die $self->extended_status;
  }

  if ($self->{security} eq 'tls') {
    $self->{smtp}->starttls(SSL_verify_mode => 0) or do {
      $self->extended_status("$@");
      die $self->extended_status;
    };
  }

  # Backwards compatibility: older Versions used 'user' instead of the
  # intended 'login'. Support both.
  my $login = $cfg->{login} || $cfg->{user};

  return 1 unless $login;

  if (!$self->{smtp}->auth($login, $cfg->{password})) {
    $self->extended_status('SMTP authentication failed');
    die $self->extended_status;
  }
}

sub start_mail {
  my ($self, %params) = @_;

  $self->{smtp}->mail($params{from})         or do { $self->extended_status($self->{smtp}->message); die $self->extended_status; };
  $self->{smtp}->recipient(@{ $params{to} }) or do { $self->extended_status($self->{smtp}->message); die $self->extended_status; };
  $self->{smtp}->data                        or do { $self->extended_status($self->{smtp}->message); die $self->extended_status; };
}

sub print {
  my $self = shift;

  # SMTP requires at most 1000 characters per line. Each line must be
  # terminated with <CRLF>, meaning \r\n in Perl.

  # First, normalize the string by removing all \r in order to fix
  # possible wrong combinations like \n\r.
  my $str = join '', @_;
  $str    =~ s/\r//g;

  # Now remove the very last newline so that we don't create a
  # superfluous empty line at the very end.
  $str =~ s/\n$//;

  # Split the string on newlines keeping trailing empty parts. This is
  # requires so that input like "Content-Disposition: ..... \n\n" is
  # treated correctly. That's also why we had to remove the very last
  # \n in the prior step.
  my @lines = split /\n/, $str, -1;

  # Send each line terminating it with \r\n.
  $self->{smtp}->datasend("$_\r\n") for @lines;
}

sub send {
  my ($self) = @_;

  my $ok = $self->{smtp}->dataend;
  $self->extended_status($self->{smtp}->message);
  $self->status('ok') if $ok;

  $self->{smtp}->quit;

  delete $self->{smtp};

  die $self->extended_status if !$ok;
}

sub keep_from_header {
  my ($self, $item) = @_;
  return lc($item) eq 'bcc';
}

1;
