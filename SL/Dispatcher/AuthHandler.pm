package SL::Dispatcher::AuthHandler;

use strict;

use parent qw(Rose::Object);

use SL::Dispatcher::AuthHandler::Admin;
use SL::Dispatcher::AuthHandler::User;

sub handle {
  my ($self, %param) = @_;

  my $auth_level                       = $self->get_auth_level(%param);
  my $handler_name                     = "SL::Dispatcher::AuthHandler::" . ucfirst($auth_level);
  $self->{handlers}                  ||= {};
  $self->{handlers}->{$handler_name} ||= $handler_name->new;
  $self->{handlers}->{$handler_name}->handle;

  return $auth_level;
}

sub get_auth_level {
  my ($self, %param) = @_;

  my $auth_level = $param{routing_type} eq 'old'        ? ($param{script} eq 'admin' ? 'admin' : 'user')
                 : $param{routing_type} eq 'controller' ? "SL::Controller::$param{controller}"->get_auth_level($param{action})
                 :                                        'user';

  return $auth_level eq 'user' ? 'user' : 'admin';
}

1;
