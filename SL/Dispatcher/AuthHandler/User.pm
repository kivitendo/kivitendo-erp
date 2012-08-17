package SL::Dispatcher::AuthHandler::User;

use strict;

use parent qw(Rose::Object);

sub handle {
  my $login = $::auth->get_session_value('login');
  SL::Dispatcher::show_error('login/password_error', 'password') if not defined $login;

  %::myconfig = $::auth->read_user(login => $login);

  SL::Dispatcher::show_error('login/password_error', 'password') unless $::myconfig{login};

  $::locale = Locale->new($::myconfig{countrycode});

  SL::Dispatcher::show_error('login/password_error', 'password') if SL::Auth::OK != $::auth->authenticate($login, undef);

  $::auth->create_or_refresh_session;
  $::auth->delete_session_value('FLASH');
  delete $::form->{password};
}

1;
