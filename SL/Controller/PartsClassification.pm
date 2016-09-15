package SL::Controller::PartsClassification;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::PartsClassification;
use SL::Helper::Flash;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(parts_classification) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_parts_classification', only => [ qw(edit update destroy) ]);

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->render('parts_classification/list',
                title         => $::locale->text('Parts Classifications'),
                PARTS_CLASSIFICATIONS => SL::DB::Manager::PartsClassification->get_all_sorted);
}

sub action_new {
  my ($self) = @_;

  $self->{parts_classification} = SL::DB::PartsClassification->new;
  $self->render('parts_classification/form', title => $::locale->text('Create a new parts classification'));
}

sub action_edit {
  my ($self) = @_;
  $self->render('parts_classification/form', title => $::locale->text('Edit parts classification'));
}

sub action_create {
  my ($self) = @_;

  $self->{parts_classification} = SL::DB::PartsClassification->new;
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

sub action_destroy {
  my ($self) = @_;

  if ( $self->{parts_classification}->id < 5 ) {
    flash_later('error', $::locale->text('The basic parts classification cannot be deleted.'));
  }
  elsif (eval { $self->{parts_classification}->delete; 1; }) {
    flash_later('info',  $::locale->text('The parts classification has been deleted.'));
  } else {
    flash_later('error', $::locale->text('The parts classification is in use and cannot be deleted.'));
  }

  $self->redirect_to(action => 'list');
}

sub action_reorder {
  my ($self) = @_;

  SL::DB::PartsClassification->reorder_list(@{ $::form->{parts_classification_id} || [] });

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
  my $is_new = !$self->{parts_classification}->id;
  my $params = delete($::form->{parts_classification}) || { };

  $self->{parts_classification}->assign_attributes(%{ $params });

  my @errors = $self->{parts_classification}->validate;

  if (@errors) {
    flash('error', @errors);
    $self->render('parts_classification/form', title => $is_new ? $::locale->text('Create a new parts classification') : $::locale->text('Edit parts classification'));
    return;
  }

  $self->{parts_classification}->save;

  flash_later('info', $is_new ? $::locale->text('The parts classification has been created.') : $::locale->text('The parts classification has been saved.'));
  $self->redirect_to(action => 'list');
}

sub load_parts_classification {
  my ($self) = @_;
  $self->{parts_classification} = SL::DB::PartsClassification->new(id => $::form->{id})->load;
}

1;
