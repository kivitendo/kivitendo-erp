package SL::Controller::RequirementSpecAcceptanceStatus;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::RequirementSpecAcceptanceStatus;
use SL::DB::Language;
use SL::Helper::Flash;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(requirement_spec_acceptance_status valid_names) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_requirement_spec_acceptance_status', only => [ qw(edit update destroy) ]);
__PACKAGE__->run_before(sub { $_[0]->valid_names(\@SL::DB::RequirementSpecAcceptanceStatus::valid_names) });

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->render('requirement_spec_acceptance_status/list',
                title                                => t8('Acceptance Statuses'),
                REQUIREMENT_SPEC_ACCEPTANCE_STATUSES => SL::DB::Manager::RequirementSpecAcceptanceStatus->get_all_sorted);
}

sub action_new {
  my ($self) = @_;

  $self->{requirement_spec_acceptance_status} = SL::DB::RequirementSpecAcceptanceStatus->new;
  $self->render('requirement_spec_acceptance_status/form', title => t8('Create a new acceptance status'));
}

sub action_edit {
  my ($self) = @_;
  $self->render('requirement_spec_acceptance_status/form', title => t8('Edit acceptance status'));
}

sub action_create {
  my ($self) = @_;

  $self->{requirement_spec_acceptance_status} = SL::DB::RequirementSpecAcceptanceStatus->new;
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

sub action_destroy {
  my ($self) = @_;

  if (eval { $self->{requirement_spec_acceptance_status}->delete; 1; }) {
    flash_later('info',  t8('The acceptance status has been deleted.'));
  } else {
    flash_later('error', t8('The acceptance status is in use and cannot be deleted.'));
  }

  $self->redirect_to(action => 'list');
}

sub action_reorder {
  my ($self) = @_;

  SL::DB::RequirementSpecAcceptanceStatus->reorder_list(@{ $::form->{requirement_spec_acceptance_status_id} || [] });

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
  my $is_new = !$self->{requirement_spec_acceptance_status}->id;
  my $params = delete($::form->{requirement_spec_acceptance_status}) || { };
  my $title  = $is_new ? t8('Create a new acceptance status') : t8('Edit acceptance status');

  $self->{requirement_spec_acceptance_status}->assign_attributes(%{ $params });

  my @errors = $self->{requirement_spec_acceptance_status}->validate;

  if (@errors) {
    flash('error', @errors);
    $self->render('requirement_spec_acceptance_status/form', title => $title);
    return;
  }

  $self->{requirement_spec_acceptance_status}->save;

  flash_later('info', $is_new ? t8('The acceptance status has been created.') : t8('The acceptance status has been saved.'));
  $self->redirect_to(action => 'list');
}

sub load_requirement_spec_acceptance_status {
  my ($self) = @_;
  $self->{requirement_spec_acceptance_status} = SL::DB::RequirementSpecAcceptanceStatus->new(id => $::form->{id})->load;
}

1;
