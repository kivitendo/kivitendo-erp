package SL::Controller::RequirementSpecPredefinedText;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::RequirementSpecPredefinedText;
use SL::DB::Language;
use SL::Helper::Flash;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(requirement_spec_predefined_text) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_requirement_spec_predefined_text', only => [ qw(edit update destroy) ]);

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->render('requirement_spec_predefined_text/list',
                title                             => t8('Predefined Texts'),
                REQUIREMENT_SPEC_PREDEFINED_TEXTS => SL::DB::Manager::RequirementSpecPredefinedText->get_all_sorted);
}

sub action_new {
  my ($self) = @_;

  $self->{requirement_spec_predefined_text} = SL::DB::RequirementSpecPredefinedText->new;
  $self->render('requirement_spec_predefined_text/form', title => t8('Create a new predefined text'));
}

sub action_edit {
  my ($self) = @_;
  $self->render('requirement_spec_predefined_text/form', title => t8('Edit predefined text'));
}

sub action_create {
  my ($self) = @_;

  $self->{requirement_spec_predefined_text} = SL::DB::RequirementSpecPredefinedText->new;
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

sub action_destroy {
  my ($self) = @_;

  if (eval { $self->{requirement_spec_predefined_text}->delete; 1; }) {
    flash_later('info',  t8('The predefined text has been deleted.'));
  } else {
    flash_later('error', t8('The predefined text is in use and cannot be deleted.'));
  }

  $self->redirect_to(action => 'list');
}

sub action_reorder {
  my ($self) = @_;

  SL::DB::RequirementSpecPredefinedText->reorder_list(@{ $::form->{requirement_spec_predefined_text_id} || [] });

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
  my $is_new = !$self->{requirement_spec_predefined_text}->id;
  my $params = delete($::form->{requirement_spec_predefined_text}) || { };
  my $title  = $is_new ? t8('Create a new predefined text') : t8('Edit predefined text');

  $self->{requirement_spec_predefined_text}->assign_attributes(%{ $params });

  my @errors = $self->{requirement_spec_predefined_text}->validate;

  if (@errors) {
    flash('error', @errors);
    $self->render('requirement_spec_predefined_text/form', title => $title);
    return;
  }

  $self->{requirement_spec_predefined_text}->save;

  flash_later('info', $is_new ? t8('The predefined text has been created.') : t8('The predefined text has been saved.'));
  $self->redirect_to(action => 'list');
}

sub load_requirement_spec_predefined_text {
  my ($self) = @_;
  $self->{requirement_spec_predefined_text} = SL::DB::RequirementSpecPredefinedText->new(id => $::form->{id})->load;
}

1;
