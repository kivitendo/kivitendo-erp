package SL::Controller::RequirementSpecStatus;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::RequirementSpecStatus;
use SL::DB::Language;
use SL::Helper::Flash;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(requirement_spec_status valid_names) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_requirement_spec_status', only => [ qw(edit update destroy) ]);
__PACKAGE__->run_before(sub { $_[0]->valid_names(\@SL::DB::RequirementSpecStatus::valid_names) });

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->render('requirement_spec_status/list',
                title                     => t8('Requirement Spec Statuses'),
                REQUIREMENT_SPEC_STATUSES => SL::DB::Manager::RequirementSpecStatus->get_all_sorted);
}

sub action_new {
  my ($self) = @_;

  $self->{requirement_spec_status} = SL::DB::RequirementSpecStatus->new;
  $self->render('requirement_spec_status/form', title => t8('Create a new requirement spec status'));
}

sub action_edit {
  my ($self) = @_;
  $self->render('requirement_spec_status/form', title => t8('Edit requirement spec status'));
}

sub action_create {
  my ($self) = @_;

  $self->{requirement_spec_status} = SL::DB::RequirementSpecStatus->new;
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

sub action_destroy {
  my ($self) = @_;

  if (eval { $self->{requirement_spec_status}->delete; 1; }) {
    flash_later('info',  t8('The requirement spec status has been deleted.'));
  } else {
    flash_later('error', t8('The requirement spec status is in use and cannot be deleted.'));
  }

  $self->redirect_to(action => 'list');
}

sub action_reorder {
  my ($self) = @_;

  SL::DB::RequirementSpecStatus->reorder_list(@{ $::form->{requirement_spec_status_id} || [] });

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
  my $is_new = !$self->{requirement_spec_status}->id;
  my $params = delete($::form->{requirement_spec_status}) || { };
  my $title  = $is_new ? t8('Create a new requirement spec status') : t8('Edit requirement spec status');

  $self->{requirement_spec_status}->assign_attributes(%{ $params });

  my @errors = $self->{requirement_spec_status}->validate;

  if (@errors) {
    flash('error', @errors);
    $self->render('requirement_spec_status/form', title => $title);
    return;
  }

  $self->{requirement_spec_status}->save;

  flash_later('info', $is_new ? t8('The requirement spec status has been created.') : t8('The requirement spec status has been saved.'));
  $self->redirect_to(action => 'list');
}

sub load_requirement_spec_status {
  my ($self) = @_;
  $self->{requirement_spec_status} = SL::DB::RequirementSpecStatus->new(id => $::form->{id})->load;
}

1;
