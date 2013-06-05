package SL::Controller::Admin;

use strict;

use parent qw(SL::Controller::Base);

use IO::File;

use SL::DB::AuthUser;
use SL::DB::AuthGroup;
use SL::Helper::Flash;
use SL::Locale::String qw(t8);

use Rose::Object::MakeMethods::Generic
(
  'scalar --get_set_init' => [ qw(client user nologin_file_name db_cfg) ],
);

__PACKAGE__->run_before(\&setup_layout);

sub get_auth_level { "admin" };
sub keep_auth_vars {
  my ($class, %params) = @_;
  return $params{action} eq 'login';
}

#
# actions
#

sub action_login {
  my ($self) = @_;

  return $self->login_form if !$::form->{do_login};
  return                   if !$self->authenticate_root;
  return                   if !$self->check_auth_db_and_tables;
  return                   if  $self->apply_dbupgrade_scripts;
  $self->redirect_to(action => 'list_clients_and_users');
}

sub action_logout {
  my ($self) = @_;
  $::auth->destroy_session;
  $self->redirect_to(action => 'login');
}

sub action_apply_dbupgrade_scripts {
  my ($self) = @_;

  return if $self->apply_dbupgrade_scripts;
  $self->action_list_clients_and_users;
}

sub action_create_auth_db {
  my ($self) = @_;

  $::auth->create_database(superuser          => $::form->{db_superuser},
                           superuser_password => $::form->{db_superuser_password},
                           template           => $::form->{db_template});
  $self->check_auth_db_and_tables;
}

sub action_create_auth_tables {
  my ($self) = @_;

  $::auth->create_tables;
  $::auth->set_session_value('admin_password', $::lx_office_conf{authentication}->{admin_password});
  $::auth->create_or_refresh_session;

  my $group = (SL::DB::Manager::AuthGroup->get_all(limit => 1))[0];
  if (!$group) {
    SL::DB::AuthGroup->new(
      name        => t8('Full Access'),
      description => t8('Full access to all functions'),
      rights      => [ map { SL::DB::AuthGroupRight->new(right => $_, granted => 1) } SL::Auth::all_rights() ],
    )->save;
  }

  if (!$self->apply_dbupgrade_scripts) {
    $self->action_login;
  }
}

sub action_list_clients_and_users {
  my ($self) = @_;

  $self->render(
    "admin/list_users",
    CLIENTS => SL::DB::Manager::AuthClient->get_all_sorted,
    USERS   => SL::DB::Manager::AuthUser->get_all_sorted,
    LOCKED  => (-e $self->nologin_file_name),
    title   => "kivitendo " . $::locale->text('Administration'),
  );
}

sub action_unlock_system {
  my ($self) = @_;
  unlink $self->nologin_file_name;
  flash_later('info', t8('Lockfile removed!'));
  $self->redirect_to(action => 'list_clients_and_users');
}

sub action_lock_system {
  my ($self) = @_;

  my $fh = IO::File->new($self->nologin_file_name, "w");
  if (!$fh) {
    $::form->error(t8('Cannot create Lock!'));

  } else {
    $fh->close;
    flash_later('info', t8('Lockfile created!'));
    $self->redirect_to(action => 'list_clients_and_users');
  }
}

#
# initializers
#

sub init_db_cfg            { $::lx_office_conf{'authentication/database'}               }
sub init_nologin_file_name { $::lx_office_conf{paths}->{userspath} . '/nologin';        }
sub init_client            { SL::DB::AuthClient->new(id => $::form->{client_id})->load; }
sub init_user              { SL::DB::AuthUser  ->new(id => $::form->{user_id}  )->load; }

#
# filters
#

sub setup_layout {
  my ($self, $action) = @_;

  $::request->layout(SL::Layout::Dispatcher->new(style => 'admin'));
  $::request->layout->use_stylesheet("lx-office-erp.css");
  $::form->{favicon} = "favicon.ico";
}

#
# helpers
#

sub login_form {
  my ($self, %params) = @_;
  $::request->layout->focus('#admin_password');
  $self->render('admin/adminlogin', title => t8('kivitendo v#1 administration', $::form->{version}), %params);
}

sub check_auth_db_and_tables {
  my ($self) = @_;

  if (!$::auth->check_database) {
    $self->render('admin/check_auth_database', title => t8('Authentification database creation'));
    return 0;
  }

  if (!$::auth->check_tables) {
    $self->render('admin/check_auth_tables', title => t8('Authentification tables creation'));
    return 0;
  }

  return 1;
}

sub apply_dbupgrade_scripts {
  return SL::DBUpgrade2->new(form => $::form, dbdriver => 'Pg', auth => 1)->apply_admin_dbupgrade_scripts(1);
}

sub authenticate_root {
  my ($self) = @_;

  return 1 if $::auth->authenticate_root($::form->{'{AUTH}admin_password'}) == $::auth->OK();

  $::auth->punish_wrong_login;
  $::auth->delete_session_value('admin_password');

  $self->login_form(error => t8('Incorrect Password!'));

  return undef;
}

1;
