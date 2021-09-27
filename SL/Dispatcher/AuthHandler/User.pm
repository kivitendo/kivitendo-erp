package SL::Dispatcher::AuthHandler::User;

use strict;
use parent qw(SL::Dispatcher::AuthHandler::Base);

use SL::Helper::UserPreferences::DisplayPreferences;
use SL::Layout::Dispatcher;

sub handle {
  my ($self, %param) = @_;

  my ($http_auth_login,     $http_auth_password) = $self->_parse_http_basic_auth;
  my ($http_headers_client, $http_headers_login) = $self->_parse_http_headers_auth;

  my $login = $::form->{'{AUTH}login'} // $http_auth_login // $http_headers_login // $::auth->get_session_value('login');

  return $self->_error(%param) if !defined $login;

  my $client_id = $::form->{'{AUTH}client_id'} // $http_headers_client // $::auth->get_session_value('client_id') // $::auth->get_default_client_id;

  return $self->_error(%param) if !$client_id || !$::auth->set_client($client_id);

  %::myconfig = User->get_default_myconfig($::auth->read_user(login => $login));

  return $self->_error(%param) unless $::myconfig{login};

  $::locale = Locale->new($::myconfig{countrycode});

  # user can force a layout version
  my $user_prefs = SL::Helper::UserPreferences::DisplayPreferences->new();
  $::request->is_mobile(0) if ($user_prefs->get_layout_style || '') eq 'desktop';
  $::request->is_mobile(1) if ($user_prefs->get_layout_style || '') eq 'mobile';
  $::request->{layout} = $::request->is_mobile
    ? SL::Layout::Dispatcher->new(style => 'mobile')
    : SL::Layout::Dispatcher->new(style => $::myconfig{menustyle});

  my $ok   =  $::auth->is_api_token_cookie_valid;
  $ok    ||=                            $http_headers_login && (SL::Auth::OK() == $::auth->authenticate($::myconfig{login}, \'dummy!'));
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

1;
