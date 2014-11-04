package SL::Controller::RequirementSpecPredefinedText;

use strict;

use parent qw(SL::Controller::Base);

use List::MoreUtils qw(none);

use SL::DB::RequirementSpecPredefinedText;
use SL::Helper::Flash;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(requirement_spec_predefined_text) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('setup');
__PACKAGE__->run_before('load_requirement_spec_predefined_text', only => [ qw(edit update destroy) ]);

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->render('requirement_spec_predefined_text/list',
                title                             => t8('Pre-defined Texts'),
                REQUIREMENT_SPEC_PREDEFINED_TEXTS => SL::DB::Manager::RequirementSpecPredefinedText->get_all_sorted);
}

sub action_new {
  my ($self) = @_;

  $self->{requirement_spec_predefined_text} = SL::DB::RequirementSpecPredefinedText->new(useable_for_text_blocks => 1);
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

sub setup {
  $::request->layout->use_javascript("${_}.js")  for qw(ckeditor/ckeditor ckeditor/adapters/jquery);
}

#
# helpers
#

sub create_or_update {
  my $self   = shift;
  my $is_new = !$self->{requirement_spec_predefined_text}->id;
  my $params = delete($::form->{requirement_spec_predefined_text}) || { };
  my $title  = $is_new ? t8('Create a new predefined text') : t8('Edit predefined text');

  # Force presence of booleans for the useable_* flags.
  my @useable_flags = qw(text_blocks sections);
  $params->{"useable_for_${_}"} = !!$params->{"useable_for_${_}"} for @useable_flags;

  # Force usage for text blocks if none of the check boxes are marked.
  $params->{useable_for_text_blocks} = 1 if none { $params->{"useable_for_${_}"} } @useable_flags;

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
