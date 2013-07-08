package SL::Mailer::SMTP;

use strict;

use parent qw(Rose::Object);

use Rose::Object::MakeMethods::Generic
(
  scalar => [ qw(myconfig mailer form) ]
);

my %security_config = (
  none => { require_module => 'Net::SMTP',          package => 'Net::SMTP',      port =>  25 },
  tls  => { require_module => 'Net::SSLGlue::SMTP', package => 'Net::SMTP',      port =>  25 },
  ssl  => { require_module => 'Net::SMTP::SSL',     package => 'Net::SMTP::SSL', port => 465 },
);

sub init {
  my ($self) = @_;

  Rose::Object::init(@_);

  my $cfg           = $::lx_office_conf{mail_delivery} || {};
  $self->{security} = exists $security_config{lc $cfg->{security}} ? lc $cfg->{security} : 'none';
  my $sec_cfg       = $security_config{ $self->{security} };

  eval "require $sec_cfg->{require_module}" or die "$@";

  $self->{smtp} = $sec_cfg->{package}->new($cfg->{host} || 'localhost', Port => $cfg->{port} || $sec_cfg->{port});
  die unless $self->{smtp};

  $self->{smtp}->starttls(SSL_verify_mode => 0) || die if $self->{security} eq 'tls';

  # Backwards compatibility: older Versions used 'user' instead of the
  # intended 'login'. Support both.
  my $login = $cfg->{login} || $cfg->{user};

  return 1 unless $login;

  $self->{smtp}->auth($login, $cfg->{password}) or die;
}

sub start_mail {
  my ($self, %params) = @_;

  $self->{smtp}->mail($params{from});
  $self->{smtp}->recipient(@{ $params{to} });
  $self->{smtp}->data;
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

  $self->{smtp}->dataend;
  $self->{smtp}->quit;
  delete $self->{smtp};
}

sub keep_from_header {
  my ($self, $item) = @_;
  return lc($item) eq 'bcc';
}

1;
