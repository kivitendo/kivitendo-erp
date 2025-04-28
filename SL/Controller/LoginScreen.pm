package SL::Controller::LoginScreen;

use strict;

use parent qw(SL::Controller::Base);

use List::Util qw(first);

use SL::Dispatcher::AuthHandler::User;
use SL::DB::AuthClient;
use SL::DB::AuthGroup;
use SL::DB::AuthUser;
use SL::DB::Employee;
use SL::Locale::String qw(t8);
use SL::User;
use SL::Version;

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
  $self->show_login_form(error_state($::form->{error}));
}

sub action_logout {
  my ($self) = @_;

  $::auth->destroy_session;
  $::auth->create_or_refresh_session;
  $self->show_login_form(info => $::locale->text('You are logged out!'));
}

sub action_login {
  my ($self) = @_;

  my $error = t8('Incorrect username or password or no access to selected client!');

  my $auth_result  = SL::Dispatcher::AuthHandler::User->new->handle(
    login     => delete $::form->{'{AUTH}login'},
    password  => delete $::form->{'{AUTH}password'},
    client_id => delete $::form->{'{AUTH}client_id'},
    callback  => $::form->{callback},
  );
  $::dispatcher->end_request unless $auth_result;

  $::request->layout(SL::Layout::Dispatcher->new(style => $::myconfig{menustyle}));

  # if we get an error back, bale out
  my $result = User->new(login => $::myconfig{login})->login($::form);

  # Auth DB needs update? If so log the user out forcefully.
  if (User::LOGIN_AUTH_DBUPDATE_AVAILABLE() == $result) {
    $::auth->destroy_session;
    # must be without layout because menu rights might not exist yet
    return $self->render('login_screen/auth_db_needs_update', { layout => 0 });
  }

  # Basic client tables available? If not tell the user to create them
  # and log the user out forcefully.
  if (User::LOGIN_BASIC_TABLES_MISSING() == $result) {
    $::auth->destroy_session;
    return $self->render('login_screen/basic_tables_missing');
  }

  # Database update available?
  $::dispatcher->end_request if User::LOGIN_DBUPDATE_AVAILABLE() == $result;

  # Other login errors.
  if (User::LOGIN_OK() != $result) {
    $::auth->punish_wrong_login;
    return $self->show_login_form(error => $error);
  }

  # Everything is fine.
  $::auth->set_cookie_environment_variable();

  $self->_redirect_to_main_script;
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
  my ($self) = @_;

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

  # Check if there's a client set in the session -- and whether or not
  # the user still has access to the client.
  my $client_id = $::auth->get_session_value('client_id');
  return if !$client_id;

  if (!$::auth->set_client($client_id)) {
    $::auth->punish_wrong_login;
    $::auth->destroy_session;
    $::auth->create_or_refresh_session;
    $self->show_login_form(error => t8('Incorrect username or password or no access to selected client!'));
    return 1;
  }

  # Check if the session is logged in correctly.
  return if SL::Auth::OK() != $::auth->authenticate($login, undef);

  $::auth->create_or_refresh_session;
  $::auth->delete_session_value('FLASH');

  $self->_redirect_to_main_script(\%user);

  return 1;
}

sub error_state {
  my %states = (
    session  => { warning => t8('The session has expired. Please log in again.')                   },
    password => { error   => t8('Incorrect username or password or no access to selected client!') },
    action   => { warning => t8('The action is missing or invalid.')                               },
  );

  return %{ $states{$_[0]} || {} };
}

sub set_layout {
  $::request->{layout} = $::request->is_mobile
    ? SL::Layout::Dispatcher->new(style => 'mobile_login')
    : SL::Layout::Dispatcher->new(style => 'login');
}

sub init_clients {
  return SL::DB::Manager::AuthClient->get_all_sorted;
}

sub init_default_client_id {
  my ($self)         = @_;
  my $default_client = first { $_->is_default } @{ $self->clients };
  return $default_client ? $default_client->id : undef;
}

sub show_login_form {
  my ($self, %params) = @_;

  $self->render('login_screen/user_login', %params, version => SL::Version->get_version, callback => $::form->{callback});
}

1;
