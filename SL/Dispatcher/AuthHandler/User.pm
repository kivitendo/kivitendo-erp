package SL::Dispatcher::AuthHandler::User;

use strict;
use parent qw(Rose::Object);

use Encode ();
use MIME::Base64 ();

use SL::Layout::Dispatcher;

sub handle {
  my ($self, %param) = @_;

  my ($http_auth_login, $http_auth_password) = $self->_parse_http_basic_auth;

  my $login = $::form->{'{AUTH}login'} // $http_auth_login // $::auth->get_session_value('login');

  return $self->_error(%param) if !defined $login;

  my $client_id = $::form->{'{AUTH}client_id'} // $::auth->get_session_value('client_id') // $::auth->get_default_client_id;

  return $self->_error(%param) if !$client_id || !$::auth->set_client($client_id);

  %::myconfig = User->get_default_myconfig($::auth->read_user(login => $login));

  return $self->_error(%param) unless $::myconfig{login};

  $::locale = Locale->new($::myconfig{countrycode});
  $::request->{layout} = SL::Layout::Dispatcher->new(style => $::myconfig{menustyle});

  my $ok   =  $::auth->is_api_token_cookie_valid;
  $ok    ||=  $::form->{'{AUTH}login'}                      && (SL::Auth::OK() == $::auth->authenticate($::myconfig{login}, $::form->{'{AUTH}password'}));
  $ok    ||= !$::form->{'{AUTH}login'} &&  $http_auth_login && (SL::Auth::OK() == $::auth->authenticate($::myconfig{login}, $http_auth_password));
  $ok    ||= !$::form->{'{AUTH}login'} && !$http_auth_login && (SL::Auth::OK() == $::auth->authenticate($::myconfig{login}, undef));

  return $self->_error(%param) if !$ok;

  $::auth->create_or_refresh_session;
  $::auth->delete_session_value('FLASH');
  $::instance_conf->reload->data;

  return 1;
}

sub _error {
  my ($self, %param) = @_;

  $::auth->punish_wrong_login;
  $::dispatcher->handle_login_error(%param, error => 'password');

  return 0;
}

sub _parse_http_basic_auth {
  my ($self) = @_;

  # See RFC 7617.

  # Requires that the server passes the 'Authorization' header as the
  # environment variable 'HTTP_AUTHORIZATION'. Example code for
  # Apache:

  # SetEnvIf Authorization "(.*)" HTTP_AUTHORIZATION=$1

  my $data = $ENV{HTTP_AUTHORIZATION};

  return unless ($data // '') =~ m{^basic +(.+)}i;

  $data = Encode::decode('utf-8', MIME::Base64::decode($1));

  return unless $data =~ m{(.+?):(.+)};

  return ($1, $2);
}

1;
