package SL::Controller::LoginScreen;

use strict;

use parent qw(SL::Controller::Base);

use List::Util qw(first);

use SL::Dispatcher::AuthHandler::User;
use SL::DB::AuthClient;
use SL::DB::AuthGroup;
use SL::DB::AuthUser;
use SL::User;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(clients default_client_id) ],
);

__PACKAGE__->run_before('set_layout');

#
# actions
#

sub action_user_login {
  my ($self) = @_;

  # If the user is already logged in then redirect to the proper menu
  # script.
  return if $self->_redirect_to_main_script_if_already_logged_in;

  # Otherwise show the login form.
  $self->render('login_screen/user_login', error => error_state($::form->{error}));
}

sub action_logout {
  my ($self) = @_;

  $::auth->destroy_session;
  $::auth->create_or_refresh_session;
  $self->render('login_screen/user_login', error => $::locale->text('You are logged out!'));
}

sub action_login {
  my ($self) = @_;

  my $login        = $::form->{'{AUTH}login'} || $::auth->get_session_value('login');
  %::myconfig      = $login ? $::auth->read_user(login => $login) : ();
  SL::Dispatcher::AuthHandler::User->new->handle(countrycode => $::myconfig{countrycode});
  $::form->{login} = $::myconfig{login};
  $::locale        = Locale->new($::myconfig{countrycode}) if $::myconfig{countrycode};
  my $user         = User->new(login => $::myconfig{login});
  $::request->{layout} = SL::Layout::Dispatcher->new(style => $user->{menustyle});

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

  $self->_redirect_to_main_script($user);
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

#
# private methods
#

sub _redirect_to_main_script {
  my ($self, $user) = @_;

  return $self->redirect_to($::form->{callback}) if $::form->{callback};

  $self->redirect_to(controller => "login.pl", action => 'company_logo');
}

sub _redirect_to_main_script_if_already_logged_in {
  my ($self) = @_;

  # Get 'login' from valid session.
  my $login = $::auth->get_session_value('login');
  return unless $login;

  # See whether or not the user exists in the database.
  my %user = $::auth->read_user(login => $login);
  return if ($user{login} || '') ne $login;

  # Check if the session is logged in correctly.
  return if SL::Auth::OK() != $::auth->authenticate($login, undef);

  $::auth->create_or_refresh_session;
  $::auth->delete_session_value('FLASH');

  $self->_redirect_to_main_script(\%user);

  return 1;
}

sub error_state {
  return {
    session  => $::locale->text('The session is invalid or has expired.'),
    password => $::locale->text('Incorrect password!'),
  }->{$_[0]};
}

sub set_layout {
  $::request->{layout} = SL::Layout::Dispatcher->new(style => 'login');
}

sub init_clients {
  return SL::DB::Manager::AuthClient->get_all_sorted;
}

sub init_default_client_id {
  my ($self)         = @_;
  my $default_client = first { $_->is_default } @{ $self->clients };
  return $default_client ? $default_client->id : undef;
}

1;
