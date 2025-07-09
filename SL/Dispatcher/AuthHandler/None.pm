package SL::Dispatcher::AuthHandler::None;

use strict;
use parent qw(SL::Dispatcher::AuthHandler::Base);

use SL::Auth::Constants;

sub handle {
  my ($self) = @_;


  my ($http_auth_login,     $http_auth_password) = $self->_parse_http_basic_auth;
  my ($http_headers_client, $http_headers_login) = $self->_parse_http_headers_auth;

  my $client_id = $http_headers_client // $::auth->get_default_client_id;
  my $login     = $http_headers_login  // $http_auth_login;

  if ($client_id && $login) {
    $::auth->set_client($client_id);
    %::myconfig = User->get_default_myconfig($::auth->read_user(login => $login));

    $::auth->create_or_refresh_session;
    $::auth->set_session_value('client_id', $client_id);
    $::auth->set_session_value('login',     $login);

    $::auth->set_session_authenticated($login, SL::Auth::Constants::SESSION_OK());

  } else {
    %::myconfig = User->get_default_myconfig;
  }

  return 1;
}

1;
