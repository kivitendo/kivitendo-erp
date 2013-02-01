package SL::Controller::RequirementSpecRisk;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::RequirementSpecRisk;
use SL::DB::Language;
use SL::Helper::Flash;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(requirement_spec_risk) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_requirement_spec_risk', only => [ qw(edit update destroy) ]);

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->render('requirement_spec_risk/list',
                title                  => t8('Risk levels'),
                REQUIREMENT_SPEC_RISKS => SL::DB::Manager::RequirementSpecRisk->get_all_sorted);
}

sub action_new {
  my ($self) = @_;

  $self->{requirement_spec_risk} = SL::DB::RequirementSpecRisk->new;
  $self->render('requirement_spec_risk/form', title => t8('Create a new risk level'));
}

sub action_edit {
  my ($self) = @_;
  $self->render('requirement_spec_risk/form', title => t8('Edit risk level'));
}

sub action_create {
  my ($self) = @_;

  $self->{requirement_spec_risk} = SL::DB::RequirementSpecRisk->new;
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

sub action_destroy {
  my ($self) = @_;

  if (eval { $self->{requirement_spec_risk}->delete; 1; }) {
    flash_later('info',  t8('The risk level has been deleted.'));
  } else {
    flash_later('error', t8('The risk level is in use and cannot be deleted.'));
  }

  $self->redirect_to(action => 'list');
}

sub action_reorder {
  my ($self) = @_;

  SL::DB::RequirementSpecRisk->reorder_list(@{ $::form->{requirement_spec_risk_id} || [] });

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
  my $is_new = !$self->{requirement_spec_risk}->id;
  my $params = delete($::form->{requirement_spec_risk}) || { };
  my $title  = $is_new ? t8('Create a new risk level') : t8('Edit risk level');

  $self->{requirement_spec_risk}->assign_attributes(%{ $params });

  my @errors = $self->{requirement_spec_risk}->validate;

  if (@errors) {
    flash('error', @errors);
    $self->render('requirement_spec_risk/form', title => $title);
    return;
  }

  $self->{requirement_spec_risk}->save;

  flash_later('info', $is_new ? t8('The risk level has been created.') : t8('The risk level has been saved.'));
  $self->redirect_to(action => 'list');
}

sub load_requirement_spec_risk {
  my ($self) = @_;
  $self->{requirement_spec_risk} = SL::DB::RequirementSpecRisk->new(id => $::form->{id})->load;
}

1;
