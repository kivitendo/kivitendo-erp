package SL::Dispatcher::AuthHandler::User;

use strict;

use parent qw(Rose::Object);

sub handle {
  my $login = $::form->{'{AUTH}login'} || $::auth->get_session_value('login');
  SL::Dispatcher::show_error('login/password_error', 'password') if not defined $login;

  %::myconfig = $::auth->read_user(login => $login);

  SL::Dispatcher::show_error('login/password_error', 'password') unless $::myconfig{login};

  $::locale = Locale->new($::myconfig{countrycode});

  my $ok   =  $::form->{'{AUTH}login'} && (SL::Auth::OK == $::auth->authenticate($login, $::form->{'{AUTH}password'}));
  $ok    ||= !$::form->{'{AUTH}login'} && (SL::Auth::OK == $::auth->authenticate($login, undef));

  SL::Dispatcher::show_error('login/password_error', 'password') if !$ok;

  $::auth->create_or_refresh_session;
  $::auth->delete_session_value('FLASH');
}

1;
