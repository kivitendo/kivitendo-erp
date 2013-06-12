package SL::Controller::Admin;

use strict;

use parent qw(SL::Controller::Base);

use IO::File;
use List::Util qw(first);

use SL::DB::AuthUser;
use SL::DB::AuthGroup;
use SL::DB::Printer;
use SL::Helper::Flash;
use SL::Locale::String qw(t8);
use SL::User;

use Rose::Object::MakeMethods::Generic
(
  'scalar --get_set_init' => [ qw(client user group printer nologin_file_name db_cfg is_locked
                                  all_dateformats all_numberformats all_countrycodes all_stylesheets all_menustyles all_clients all_groups all_users all_rights all_printers) ],
);

__PACKAGE__->run_before(\&setup_layout);
__PACKAGE__->run_before(\&setup_client, only => [ qw(list_printers new_printer edit_printer save_printer delete_printer) ]);

sub get_auth_level { "admin" };
sub keep_auth_vars {
  my ($class, %params) = @_;
  return $params{action} eq 'login';
}

#
# actions: login, logout
#

sub action_login {
  my ($self) = @_;

  return $self->login_form if !$::form->{do_login};
  return                   if !$self->authenticate_root;
  return                   if !$self->check_auth_db_and_tables;
  return                   if  $self->apply_dbupgrade_scripts;
  $self->redirect_to(action => 'show');
}

sub action_logout {
  my ($self) = @_;
  $::auth->destroy_session;
  $self->redirect_to(action => 'login');
}

#
# actions: creating the authentication database & tables, applying database ugprades
#

sub action_apply_dbupgrade_scripts {
  my ($self) = @_;

  return if $self->apply_dbupgrade_scripts;
  $self->action_show;
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

#
# actions: users
#

sub action_show {
  my ($self) = @_;

  $self->render(
    "admin/show",
    title => "kivitendo " . t8('Administration'),
  );
}

sub action_new_user {
  my ($self) = @_;

  $self->user(SL::DB::AuthUser->new(
    config_values => {
      vclimit      => 200,
      countrycode  => "de",
      numberformat => "1.000,00",
      dateformat   => "dd.mm.yy",
      stylesheet   => "kivitendo.css",
      menustyle    => "neu",
    },
  ));

  $self->edit_user_form(title => t8('Create a new user'));
}

sub action_edit_user {
  my ($self) = @_;
  $self->edit_user_form(title => t8('Edit User'));
}

sub action_save_user {
  my ($self) = @_;
  my $params = delete($::form->{user})          || { };
  my $props  = delete($params->{config_values}) || { };
  my $is_new = !$params->{id};

  $self->user($is_new ? SL::DB::AuthUser->new : SL::DB::AuthUser->new(id => $params->{id})->load)
    ->assign_attributes(%{ $params })
    ->config_values({ %{ $self->user->config_values }, %{ $props } });

  my @errors = $self->user->validate;

  if (@errors) {
    flash('error', @errors);
    $self->edit_user_form(title => $is_new ? t8('Create a new user') : t8('Edit User'));
    return;
  }

  $self->user->save;

  if ($::auth->can_change_password && $::form->{new_password}) {
    $::auth->change_password($self->user->login, $::form->{new_password});
  }

  flash_later('info', $is_new ? t8('The user has been created.') : t8('The user has been saved.'));
  $self->redirect_to(action => 'show');
}

sub action_delete_user {
  my ($self) = @_;

  if (!$self->user->delete) {
    flash('error', t8('The user could not be deleted.'));
    $self->edit_user_form(title => t8('Edit User'));
    return;
  }

  flash_later('info', t8('The user has been deleted.'));
  $self->redirect_to(action => 'show');
}

#
# actions: clients
#

sub action_new_client {
  my ($self) = @_;

  $self->client(SL::DB::AuthClient->new(
    dbhost   => $::auth->{DB_config}->{host},
    dbport   => $::auth->{DB_config}->{port},
    dbuser   => $::auth->{DB_config}->{user},
    dbpasswd => $::auth->{DB_config}->{password},
  ));

  $self->edit_client_form(title => t8('Create a new client'));
}

sub action_edit_client {
  my ($self) = @_;
  $self->edit_client_form(title => t8('Edit Client'));
}

sub action_save_client {
  my ($self) = @_;
  my $params = delete($::form->{client}) || { };
  my $is_new = !$params->{id};

  $self->client($is_new ? SL::DB::AuthClient->new : SL::DB::AuthClient->new(id => $params->{id})->load)->assign_attributes(%{ $params });

  my @errors = $self->client->validate;

  if (@errors) {
    flash('error', @errors);
    $self->edit_client_form(title => $is_new ? t8('Create a new client') : t8('Edit Client'));
    return;
  }

  $self->client->save;
  if ($self->client->is_default) {
    SL::DB::Manager::AuthClient->update_all(set => { is_default => 0 }, where => [ '!id' => $self->client->id ]);
  }

  flash_later('info', $is_new ? t8('The client has been created.') : t8('The client has been saved.'));
  $self->redirect_to(action => 'show');
}

sub action_delete_client {
  my ($self) = @_;

  if (!$self->client->delete) {
    flash('error', t8('The client could not be deleted.'));
    $self->edit_client_form(title => t8('Edit Client'));
    return;
  }

  flash_later('info', t8('The client has been deleted.'));
  $self->redirect_to(action => 'show');
}

sub action_test_database_connectivity {
  my ($self)    = @_;

  my %cfg       = %{ $::form->{client} || {} };
  my $dbconnect = 'dbi:Pg:dbname=' . $cfg{dbname} . ';host=' . $cfg{dbhost} . ';port=' . $cfg{dbport};
  my $dbh       = DBI->connect($dbconnect, $cfg{dbuser}, $cfg{dbpasswd});

  my $ok        = !!$dbh;
  my $error     = $DBI::errstr;

  $dbh->disconnect if $dbh;

  $self->render('admin/test_db_connection',
                title => t8('Database Connection Test'),
                ok    => $ok,
                error => $error);
}

#
# actions: groups
#

sub action_new_group {
  my ($self) = @_;

  $self->group(SL::DB::AuthGroup->new);
  $self->edit_group_form(title => t8('Create a new group'));
}

sub action_edit_group {
  my ($self) = @_;
  $self->edit_group_form(title => t8('Edit User Group'));
}

sub action_save_group {
  my ($self) = @_;

  my $params = delete($::form->{group}) || { };
  my $is_new = !$params->{id};

  $self->group($is_new ? SL::DB::AuthGroup->new : SL::DB::AuthGroup->new(id => $params->{id})->load)->assign_attributes(%{ $params });

  my @errors = $self->group->validate;

  if (@errors) {
    flash('error', @errors);
    $self->edit_group_form(title => $is_new ? t8('Create a new user group') : t8('Edit User Group'));
    return;
  }

  $self->group->save;

  flash_later('info', $is_new ? t8('The user group has been created.') : t8('The user group has been saved.'));
  $self->redirect_to(action => 'show');
}

sub action_delete_group {
  my ($self) = @_;

  if (!$self->group->delete) {
    flash('error', t8('The user group could not be deleted.'));
    $self->edit_group_form(title => t8('Edit User Group'));
    return;
  }

  flash_later('info', t8('The user group has been deleted.'));
  $self->redirect_to(action => 'show');
}

#
# actions: printers
#

sub action_list_printers {
  my ($self) = @_;
  $self->render('admin/list_printers', title => t8('Printer management'));
}

sub action_new_printer {
  my ($self) = @_;

  $self->printer(SL::DB::Printer->new);
  $self->edit_printer_form(title => t8('Create a new printer'));
}

sub action_edit_printer {
  my ($self) = @_;
  $self->edit_printer_form(title => t8('Edit Printer'));
}

sub action_save_printer {
  my ($self) = @_;
  my $params = delete($::form->{printer}) || { };
  my $is_new = !$params->{id};

  $self->printer($is_new ? SL::DB::Printer->new : SL::DB::Printer->new(id => $params->{id})->load)->assign_attributes(%{ $params });

  my @errors = $self->printer->validate;

  if (@errors) {
    flash('error', @errors);
    $self->edit_printer_form(title => $is_new ? t8('Create a new printer') : t8('Edit Printer'));
    return;
  }

  $self->printer->save;

  flash_later('info', $is_new ? t8('The printer has been created.') : t8('The printer has been saved.'));
  $self->redirect_to(action => 'list_printers', 'client.id' => $self->client->id);
}

sub action_delete_printer {
  my ($self) = @_;

  if (!$self->printer->delete) {
    flash('error', t8('The printer could not be deleted.'));
    $self->edit_printer_form(title => t8('Edit Printer'));
    return;
  }

  flash_later('info', t8('The printer has been deleted.'));
  $self->redirect_to(action => 'list_printers', 'client.id' => $self->client->id);
}

#
# actions: locking, unlocking
#

sub action_unlock_system {
  my ($self) = @_;
  unlink $self->nologin_file_name;
  flash_later('info', t8('Lockfile removed!'));
  $self->redirect_to(action => 'show');
}

sub action_lock_system {
  my ($self) = @_;

  my $fh = IO::File->new($self->nologin_file_name, "w");
  if (!$fh) {
    $::form->error(t8('Cannot create Lock!'));

  } else {
    $fh->close;
    flash_later('info', t8('Lockfile created!'));
    $self->redirect_to(action => 'show');
  }
}

#
# initializers
#

sub init_db_cfg            { $::lx_office_conf{'authentication/database'}                                                    }
sub init_nologin_file_name { $::lx_office_conf{paths}->{userspath} . '/nologin';                                             }
sub init_is_locked         { -e $_[0]->nologin_file_name                                                                     }
sub init_client            { SL::DB::Manager::AuthClient->find_by(id => ($::form->{id} || ($::form->{client}  || {})->{id})) }
sub init_user              { SL::DB::AuthUser  ->new(id => ($::form->{id} || ($::form->{user}    || {})->{id}))->load        }
sub init_group             { SL::DB::AuthGroup ->new(id => ($::form->{id} || ($::form->{group}   || {})->{id}))->load        }
sub init_printer           { SL::DB::Printer   ->new(id => ($::form->{id} || ($::form->{printer} || {})->{id}))->load        }
sub init_all_clients       { SL::DB::Manager::AuthClient->get_all_sorted                                                     }
sub init_all_users         { SL::DB::Manager::AuthUser  ->get_all_sorted                                                     }
sub init_all_groups        { SL::DB::Manager::AuthGroup ->get_all_sorted                                                     }
sub init_all_printers      { SL::DB::Manager::Printer   ->get_all_sorted                                                     }
sub init_all_dateformats   { [ qw(mm/dd/yy dd/mm/yy dd.mm.yy yyyy-mm-dd)      ]                                              }
sub init_all_numberformats { [ qw(1,000.00 1000.00 1.000,00 1000,00)          ]                                              }
sub init_all_stylesheets   { [ qw(lx-office-erp.css Mobile.css kivitendo.css) ]                                              }
sub init_all_menustyles    {
  return [
    { id => 'old', title => $::locale->text('Old (on the side)') },
    { id => 'v3',  title => $::locale->text('Top (CSS)') },
    { id => 'neu', title => $::locale->text('Top (Javascript)') },
  ];
}

sub init_all_rights {
  my (@sections, $current_section);

  foreach my $entry ($::auth->all_rights_full) {
    if ($entry->[0] =~ m/^--/) {
      push @sections, { description => $entry->[1], rights => [] };

    } elsif (@sections) {
      push @{ $sections[-1]->{rights} }, {
        name        => $entry->[0],
        description => $entry->[1],
      };

    } else {
      die "Right without sections: " . join('::', @{ $entry });
    }
  }

  return \@sections;
}

sub init_all_countrycodes {
  my %cc = User->country_codes;
  return [ map { id => $_, title => $cc{$_} }, sort { $cc{$a} cmp $cc{$b} } keys %cc ];
}

#
# filters
#

sub setup_layout {
  my ($self, $action) = @_;

  $::request->layout(SL::Layout::Dispatcher->new(style => 'admin'));
  $::request->layout->use_stylesheet("lx-office-erp.css");
  $::form->{favicon} = "favicon.ico";
}

sub setup_client {
  my ($self) = @_;

  $self->client((first { $_->is_default } @{ $self->all_clients }) || $self->all_clients->[0]) if !$self->client;
  $::auth->set_client($self->client->id);
}


#
# displaying forms
#

sub use_multiselect_js {
  my ($self) = @_;

  $::request->layout->use_javascript("${_}.js") for qw(jquery.selectboxes jquery.multiselect2side);
  return $self;
}

sub login_form {
  my ($self, %params) = @_;
  $::request->layout->focus('#admin_password');
  $self->render('admin/adminlogin', title => t8('kivitendo v#1 administration', $::form->{version}), %params);
}

sub edit_user_form {
  my ($self, %params) = @_;
  $self->use_multiselect_js->render('admin/edit_user', %params);
}

sub edit_client_form {
  my ($self, %params) = @_;
  $self->use_multiselect_js->render('admin/edit_client', %params);
}

sub edit_group_form {
  my ($self, %params) = @_;
  $self->use_multiselect_js->render('admin/edit_group', %params);
}

sub edit_printer_form {
  my ($self, %params) = @_;
  $self->render('admin/edit_printer', %params);
}

#
# helpers
#

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
  return SL::DBUpgrade2->new(form => $::form, auth => 1)->apply_admin_dbupgrade_scripts(1);
}

sub authenticate_root {
  my ($self) = @_;

  return 1 if $::auth->authenticate_root($::form->{'{AUTH}admin_password'}) == $::auth->OK();

  $::auth->punish_wrong_login;
  $::auth->delete_session_value('admin_password');

  $self->login_form(error => t8('Incorrect password!'));

  return undef;
}

1;
