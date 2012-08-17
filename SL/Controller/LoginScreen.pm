package SL::Controller::LoginScreen;

use strict;

use parent qw(SL::Controller::Base);

use SL::Dispatcher::AuthHandler::User;
use SL::User;

#
# actions
#

sub action_user_login {
  my ($self) = @_;

  $self->render('login_screen/user_login');
}

sub action_logout {
  my ($self) = @_;

  $::auth->destroy_session;
  $::auth->create_or_refresh_session;
  $self->render('login_screen/user_login', error => $::locale->text('You are logged out!'));
}

sub action_login {
  my ($self) = @_;

  %::myconfig      = $::form->{'{AUTH}login'} ? $::auth->read_user(login => $::form->{'{AUTH}login'}) : ();
  %::myconfig      = SL::Dispatcher::AuthHandler::User->new->handle(countrycode => $::myconfig{countrycode});
  $::form->{login} = $::myconfig{login};
  $::locale        = Locale->new($::myconfig{countrycode}) if $::myconfig{countrycode};
  my $user         = User->new(login => $::myconfig{login});

  # if we get an error back, bale out
  my $result = $user->login($::form);

  # Database update available?
  ::end_of_request() if -2 == $result;

  # Auth DB needs update? If so log the user out forcefully.
  if (-3 == $result) {
    $::auth->destroy_session;
    return $self->render('login_screen/auth_db_needs_update');
  }

  # Other login errors.
  if (0 > $result) {
    $::auth->punish_wrong_login;
    return $self->render('login_screen/user_login', error => $::locale->text('Incorrect username or password!'));
  }

  # Everything is fine.
  $::auth->set_cookie_environment_variable();

  return $self->redirect_to($::form->{callback}) if $::form->{callback};

  my %style_to_script_map = (
    v3  => 'v3',
    neu => 'new',
    v4  => 'v4',
  );

  my $menu_script = $style_to_script_map{$user->{menustyle}} || '';

  $self->redirect_to(controller => "menu${menu_script}.pl", action => 'display');
}

#
# settings
#
sub get_auth_level {
  return 'none';
}

sub keep_auth_vars_in_form {
  return 1;
}

1;
