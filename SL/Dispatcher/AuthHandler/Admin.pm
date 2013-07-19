package SL::Dispatcher::AuthHandler::Admin;

use strict;
use parent qw(Rose::Object);

use SL::Layout::Dispatcher;

sub handle {
  my ($self, %params) = @_;

  %::myconfig = ();

  my $ok =  $::auth->is_api_token_cookie_valid;
  $ok  ||=  $::form->{'{AUTH}admin_password'} && ($::auth->authenticate_root($::form->{'{AUTH}admin_password'})            == $::auth->OK());
  $ok  ||= !$::form->{'{AUTH}admin_password'} && ($::auth->authenticate_root($::auth->get_session_value('admin_password')) == $::auth->OK());
  $ok  ||=  $params{action} eq 'login';

  $::auth->create_or_refresh_session;

  if ($ok) {
    $::auth->delete_session_value('FLASH');
    return 1;
  }

  $::request->{layout} = SL::Layout::Dispatcher->new(style => 'admin');
  $::request->layout->no_menu(1);
  $::auth->delete_session_value('admin_password');
  $::auth->punish_wrong_login;
  SL::Dispatcher::show_error('admin/adminlogin', 'password');

  return 0;
}

1;
