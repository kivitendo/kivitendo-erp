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

  $self->{smtp}->datasend(@_);
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
