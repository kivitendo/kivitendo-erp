package SL::Controller::RequirementSpecType;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::RequirementSpecType;
use SL::Helper::Flash;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(requirement_spec_type) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_requirement_spec_type', only => [ qw(edit update destroy) ]);

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->render('requirement_spec_type/list',
                title                  => t8('Requirement Spec Types'),
                REQUIREMENT_SPEC_TYPES => SL::DB::Manager::RequirementSpecType->get_all_sorted);
}

sub action_new {
  my ($self) = @_;

  $self->{requirement_spec_type} = SL::DB::RequirementSpecType->new(template_file_name => 'requirement_spec');
  $self->render('requirement_spec_type/form', title => t8('Create a new requirement spec type'));
}

sub action_edit {
  my ($self) = @_;
  $self->render('requirement_spec_type/form', title => t8('Edit requirement spec type'));
}

sub action_create {
  my ($self) = @_;

  $self->{requirement_spec_type} = SL::DB::RequirementSpecType->new;
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

sub action_destroy {
  my ($self) = @_;

  if (eval { $self->{requirement_spec_type}->delete; 1; }) {
    flash_later('info',  t8('The requirement spec type has been deleted.'));
  } else {
    flash_later('error', t8('The requirement spec type is in use and cannot be deleted.'));
  }

  $self->redirect_to(action => 'list');
}

sub action_reorder {
  my ($self) = @_;

  SL::DB::RequirementSpecType->reorder_list(@{ $::form->{requirement_spec_type_id} || [] });

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
  my $is_new = !$self->{requirement_spec_type}->id;
  my $params = delete($::form->{requirement_spec_type}) || { };
  my $title  = $is_new ? t8('Create a new requirement spec type') : t8('Edit requirement spec type');

  $self->{requirement_spec_type}->assign_attributes(%{ $params });

  my @errors = $self->{requirement_spec_type}->validate;

  if (@errors) {
    flash('error', @errors);
    $self->render('requirement_spec_type/form', title => $title);
    return;
  }

  $self->{requirement_spec_type}->save;

  flash_later('info', $is_new ? t8('The requirement spec type has been created.') : t8('The requirement spec type has been saved.'));
  $self->redirect_to(action => 'list');
}

sub load_requirement_spec_type {
  my ($self) = @_;
  $self->{requirement_spec_type} = SL::DB::RequirementSpecType->new(id => $::form->{id})->load;
}

1;
