package SL::Dispatcher::AuthHandler::Admin;

use strict;

use parent qw(Rose::Object);

sub handle {
  %::myconfig = ();

  return if $::auth->authenticate_root($::auth->get_session_value('rpw')) == $::auth->OK();

  $::auth->delete_session_value('rpw');
  SL::Dispatcher::show_error('login/password_error', 'password', is_admin => 1);
}

1;
