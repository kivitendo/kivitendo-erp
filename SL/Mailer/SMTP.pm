package SL::Mailer::SMTP;

use strict;

use parent qw(Rose::Object);

use Rose::Object::MakeMethods::Generic
(
  scalar => [ qw(myconfig mailer form) ]
);

sub init {
  my ($self) = @_;

  Rose::Object::init(@_);

  my $cfg           = $::lx_office_conf{mail_delivery} || {};
  $self->{security} = lc($cfg->{security} || 'none');

  if ($self->{security} eq 'tls') {
    require Net::SMTP::TLS;
    my %params;
    if ($cfg->{login}) {
      $params{User}     = $cfg->{user};
      $params{Password} = $cfg->{password};
    }
    $self->{smtp} = Net::SMTP::TLS->new($cfg->{host} || 'localhost', Port => $cfg->{port} || 25, %params);

  } else {
    my $module       = $self->{security} eq 'ssl' ? 'Net::SMTP::SSL' : 'Net::SMTP';
    my $default_port = $self->{security} eq 'ssl' ? 465              : 25;
    eval "require $module" or die $@;

    $self->{smtp} = $module->new($cfg->{host} || 'localhost', Port => $cfg->{port} || $default_port);
    $self->{smtp}->auth($cfg->{user}, $cfg->{password}) if $cfg->{login};
  }

  die unless $self->{smtp};
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
