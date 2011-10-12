package SL::Controller::Department;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::Department;
use SL::Helper::Flash;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(department) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_department', only => [ qw(edit update destroy) ]);

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->render('department/list',
                title       => $::locale->text('Departments'),
                DEPARTMENTS => SL::DB::Manager::Department->get_all_sorted);
}

sub action_new {
  my ($self) = @_;

  $self->render('department/form', title => $::locale->text('Create a new department'));
}

sub action_edit {
  my ($self) = @_;
  $self->render('department/form', title => $::locale->text('Edit department'));
}

sub action_create {
  my ($self) = @_;

  $self->{department} = SL::DB::Department->new;
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

sub action_destroy {
  my ($self) = @_;

  if (eval { $self->{department}->delete; 1; }) {
    flash_later('info',  $::locale->text('The department has been deleted.'));
  } else {
    flash_later('error', $::locale->text('The department is in use and cannot be deleted.'));
  }

  $self->redirect_to(action => 'list');
}

#
# filters
#

sub check_auth {
  $::auth->assert('config');
}

#
# helpers
#

sub create_or_update {
  my $self   = shift;
  my $is_new = !$self->{department}->id;
  my $params = delete($::form->{department}) || { };

  $self->{department}->assign_attributes(%{ $params });

  my @errors = $self->{department}->validate;

  if (@errors) {
    flash('error', @errors);
    $self->render('department/form', title => $is_new ? $::locale->text('Create a new department') : $::locale->text('Edit department'));
    return;
  }
  $self->{department}->save;

  flash_later('info', $is_new ? $::locale->text('The department has been created.') : $::locale->text('The department has been saved.'));
  $self->redirect_to(action => 'list');
}

sub load_department {
  my ($self) = @_;
  $self->{department} = SL::DB::Department->new(id => $::form->{id})->load;
}

1;
