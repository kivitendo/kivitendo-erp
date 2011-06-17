package SL::Controller::Business;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::Business;
use SL::Helper::Flash;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(business) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_business', only => [ qw(edit update destroy) ]);

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->render('business/list',
                title       => $::locale->text('Businesses'),
                BUSINESSS => SL::DB::Manager::Business->get_all_sorted);
}

sub action_new {
  my ($self) = @_;

  $self->{business} = SL::DB::Business->new;
  $self->render('business/form', title => $::locale->text('Create a new business'));
}

sub action_edit {
  my ($self) = @_;
  $self->render('business/form', title => $::locale->text('Edit business'));
}

sub action_create {
  my ($self) = @_;

  $self->{business} = SL::DB::Business->new;
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

sub action_destroy {
  my ($self) = @_;

  if (eval { $self->{business}->delete; 1; }) {
    flash_later('info',  $::locale->text('The business has been deleted.'));
  } else {
    flash_later('error', $::locale->text('The business is in use and cannot be deleted.'));
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
  my $is_new = !$self->{business}->id;
  my $params = delete($::form->{business}) || { };

  $self->{business}->assign_attributes(%{ $params });

  my @errors = $self->{business}->validate;

  if (@errors) {
    flash('error', @errors);
    $self->render('business/form', title => $is_new ? $::locale->text('Create a new business') : $::locale->text('Edit business'));
    return;
  }

  $self->{business}->save;

  flash_later('info', $is_new ? $::locale->text('The business has been created.') : $::locale->text('The business has been saved.'));
  $self->redirect_to(action => 'list');
}

sub load_business {
  my ($self) = @_;
  $self->{business} = SL::DB::Business->new(id => $::form->{id})->load;
}

1;
