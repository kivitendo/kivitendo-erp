package SL::Dispatcher::AuthHandler;

use strict;

use parent qw(Rose::Object);

use SL::Dispatcher::AuthHandler::Admin;
use SL::Dispatcher::AuthHandler::None;
use SL::Dispatcher::AuthHandler::User;

my %valid_auth_levels = map { ($_ => 1) } qw(user admin none);

sub handle {
  my ($self, %param) = @_;

  my $auth_level                       = $self->get_auth_level(%param);

  my $handler_name                     = "SL::Dispatcher::AuthHandler::" . ucfirst($auth_level);
  $self->{handlers}                  ||= {};
  $self->{handlers}->{$handler_name} ||= $handler_name->new;
  my $ok = $self->{handlers}->{$handler_name}->handle(%param);

  return (
    auth_level     => $auth_level,
    keep_auth_vars => $self->get_keep_auth_vars(%param),
    auth_ok        => $ok,
  );
}

sub get_auth_level {
  my ($self, %param) = @_;

  my $auth_level = $param{routing_type} eq 'old'        ? ($param{script} eq 'admin' ? 'admin' : 'user')
                 : $param{routing_type} eq 'controller' ? "SL::Controller::$param{controller}"->get_auth_level($param{action})
                 :                                        'user';

  return $valid_auth_levels{$auth_level} ? $auth_level : 'user';
}

sub get_keep_auth_vars {
  my ($self, %param) = @_;

  return $param{routing_type} eq 'controller' ? "SL::Controller::$param{controller}"->keep_auth_vars_in_form(action => $param{action}) : 0;
}

1;
