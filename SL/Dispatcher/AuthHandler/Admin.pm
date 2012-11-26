package SL::Dispatcher::AuthHandler::Admin;

use strict;
use parent qw(Rose::Object);

use SL::Layout::Dispatcher;

sub handle {
  %::myconfig = ();

  return 1 if  $::form->{'{AUTH}admin_password'} && ($::auth->authenticate_root($::form->{'{AUTH}admin_password'})            == $::auth->OK());
  return 1 if !$::form->{'{AUTH}admin_password'} && ($::auth->authenticate_root($::auth->get_session_value('admin_password')) == $::auth->OK());

  $::request->{layout} = SL::Layout::Dispatcher->new(style => 'admin');

  $::auth->punish_wrong_login;
  $::auth->delete_session_value('admin_password');
  SL::Dispatcher::show_error('admin/adminlogin', 'password');

  return 0;
}

1;
