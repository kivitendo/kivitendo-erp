package SL::Dispatcher::AuthHandler::User;

use strict;
use parent qw(Rose::Object);

use SL::Layout::Dispatcher;

sub handle {
  my ($self, %param) = @_;

  my $login = $::form->{'{AUTH}login'} || $::auth->get_session_value('login');
  return $self->_error(%param) if !defined $login;

  my $client_id = $::form->{'{AUTH}client_id'} || $::auth->get_session_value('client_id');
  return $self->_error(%param) if !$client_id || !$::auth->set_client($client_id);

  %::myconfig = User->get_default_myconfig($::auth->read_user(login => $login));

  return $self->_error(%param) unless $::myconfig{login};

  $::locale = Locale->new($::myconfig{countrycode});
  $::request->{layout} = SL::Layout::Dispatcher->new(style => $::myconfig{menustyle});

  my $ok   =  $::auth->is_api_token_cookie_valid;
  $ok    ||=  $::form->{'{AUTH}login'} && (SL::Auth::OK() == $::auth->authenticate($::myconfig{login}, $::form->{'{AUTH}password'}));
  $ok    ||= !$::form->{'{AUTH}login'} && (SL::Auth::OK() == $::auth->authenticate($::myconfig{login}, undef));

  return $self->_error(%param) if !$ok;

  $::auth->create_or_refresh_session;
  $::auth->delete_session_value('FLASH');
  $::instance_conf->reload->data;

  return 1;
}

sub _error {
  my $self = shift;

  $::auth->punish_wrong_login;

  require SL::Controller::Base;
  SL::Controller::Base->new->redirect_to('controller.pl?action=LoginScreen/user_login&error=password');
  return 0;
}

1;
