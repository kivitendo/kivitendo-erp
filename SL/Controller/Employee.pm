package SL::Controller::Employee;

use strict;
use parent qw(SL::Controller::Base);

use SL::DB::Employee;
use SL::Helper::Flash;
use SL::Locale::String qw(t8);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_all');
__PACKAGE__->run_before('load_from_form');
__PACKAGE__->run_before('assign_from_form');

our @updatable_columns = qw(deleted);

sub action_list {
  my ($self, %params) = @_;

  $self->render('employee/list', title => $::locale->text('Employees'));
}

sub action_edit {
  my ($self, %params) = @_;

  if ($self->{employee}) {
    $self->setup_edit_action_bar;
    $self->render('employee/edit', title => $::locale->text('Edit Employee #1', $self->{employee}->safe_name));
  } else {
    flash_later('error', $::locale->text('Could not load employee'));
    $self->redirect_to(action => 'list');
  }
}

sub action_save {
  my ($self, %params) = @_;

  SL::DB->client->with_transaction(sub {
    1;

    $self->{employee}->save;

    if ($self->{employee}->deleted) {
      my $auth_user = SL::DB::Manager::AuthUser->get_first(login => $self->{employee}->login);
      if ($auth_user) {
        SL::DB::Manager::AuthClientUser->delete_all(
          where => [
            client_id => $::auth->client->{id},
            user_id   => $auth_user->id,
          ]);
      }
    }

    1;
  });

  flash('info', $::locale->text('Employee #1 saved!', $self->{employee}->safe_name));

  $self->redirect_to(action => 'edit', 'employee.id' => $self->{employee}->id);
}

#################### private stuff ##########################

sub check_auth {
  $::auth->assert('admin');
}

sub load_all {
  $_[0]{employees} = SL::DB::Manager::Employee->get_all;
}

sub load_from_form {
  $_[0]{employee} = SL::DB::Manager::Employee->find_by(id => delete $::form->{employee}{id});
}

sub assign_from_form {
  my %data = %{ $::form->{employee} || {} };

  return 1 unless keys %data;

  $_[0]{employee}->assign_attributes(map { $_ => $data{$_} } @updatable_columns);
  return 1;
}

sub setup_edit_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Save'),
        submit    => [ '#form', { action => 'Employee/save' } ],
        accesskey => 'enter',
      ],

      'separator',

      link => [
        t8('Abort'),
        link => $self->url_for(action => 'list'),
      ],
    );
  }
}

######################## behaviour ##########################

sub delay_flash_on_redirect { 1 }

1;
