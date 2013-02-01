package SL::Controller::ProjectType;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::ProjectType;
use SL::Helper::Flash;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(project_type) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_project_type', only => [ qw(edit update destroy) ]);

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->render('project_type/list',
                title         => $::locale->text('Project Types'),
                PROJECT_TYPES => SL::DB::Manager::ProjectType->get_all_sorted);
}

sub action_new {
  my ($self) = @_;

  $self->{project_type} = SL::DB::ProjectType->new;
  $self->render('project_type/form', title => $::locale->text('Create a new project type'));
}

sub action_edit {
  my ($self) = @_;
  $self->render('project_type/form', title => $::locale->text('Edit project type'));
}

sub action_create {
  my ($self) = @_;

  $self->{project_type} = SL::DB::ProjectType->new;
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

sub action_destroy {
  my ($self) = @_;

  if (eval { $self->{project_type}->delete; 1; }) {
    flash_later('info',  $::locale->text('The project type has been deleted.'));
  } else {
    flash_later('error', $::locale->text('The project type is in use and cannot be deleted.'));
  }

  $self->redirect_to(action => 'list');
}

sub action_reorder {
  my ($self) = @_;

  SL::DB::ProjectType->reorder_list(@{ $::form->{project_type_id} || [] });

  $self->render(\'', { type => 'json' });
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
  my $is_new = !$self->{project_type}->id;
  my $params = delete($::form->{project_type}) || { };

  $self->{project_type}->assign_attributes(%{ $params });

  my @errors = $self->{project_type}->validate;

  if (@errors) {
    flash('error', @errors);
    $self->render('project_type/form', title => $is_new ? $::locale->text('Create a new project type') : $::locale->text('Edit project type'));
    return;
  }

  $self->{project_type}->save;

  flash_later('info', $is_new ? $::locale->text('The project type has been created.') : $::locale->text('The project type has been saved.'));
  $self->redirect_to(action => 'list');
}

sub load_project_type {
  my ($self) = @_;
  $self->{project_type} = SL::DB::ProjectType->new(id => $::form->{id})->load;
}

1;
