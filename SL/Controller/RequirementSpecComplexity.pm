package SL::Controller::RequirementSpecComplexity;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::RequirementSpecComplexity;
use SL::Helper::Flash;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(requirement_spec_complexity) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_requirement_spec_complexity', only => [ qw(edit update destroy) ]);

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->render('requirement_spec_complexity/list',
                title                         => t8('Complexities'),
                REQUIREMENT_SPEC_COMPLEXITIES => SL::DB::Manager::RequirementSpecComplexity->get_all_sorted);
}

sub action_new {
  my ($self) = @_;

  $self->{requirement_spec_complexity} = SL::DB::RequirementSpecComplexity->new;
  $self->render('requirement_spec_complexity/form', title => t8('Create a new complexity'));
}

sub action_edit {
  my ($self) = @_;
  $self->render('requirement_spec_complexity/form', title => t8('Edit complexity'));
}

sub action_create {
  my ($self) = @_;

  $self->{requirement_spec_complexity} = SL::DB::RequirementSpecComplexity->new;
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

sub action_destroy {
  my ($self) = @_;

  if (eval { $self->{requirement_spec_complexity}->delete; 1; }) {
    flash_later('info',  t8('The complexity has been deleted.'));
  } else {
    flash_later('error', t8('The complexity is in use and cannot be deleted.'));
  }

  $self->redirect_to(action => 'list');
}

sub action_reorder {
  my ($self) = @_;

  SL::DB::RequirementSpecComplexity->reorder_list(@{ $::form->{requirement_spec_complexity_id} || [] });

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
  my $is_new = !$self->{requirement_spec_complexity}->id;
  my $params = delete($::form->{requirement_spec_complexity}) || { };
  my $title  = $is_new ? t8('Create a new complexity') : t8('Edit complexity');

  $self->{requirement_spec_complexity}->assign_attributes(%{ $params });

  my @errors = $self->{requirement_spec_complexity}->validate;

  if (@errors) {
    flash('error', @errors);
    $self->render('requirement_spec_complexity/form', title => $title);
    return;
  }

  $self->{requirement_spec_complexity}->save;

  flash_later('info', $is_new ? t8('The complexity has been created.') : t8('The complexity has been saved.'));
  $self->redirect_to(action => 'list');
}

sub load_requirement_spec_complexity {
  my ($self) = @_;
  $self->{requirement_spec_complexity} = SL::DB::RequirementSpecComplexity->new(id => $::form->{id})->load;
}

1;
