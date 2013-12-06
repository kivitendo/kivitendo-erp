package SL::Controller::DeliveryTerm;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::DeliveryTerm;
use SL::DB::Language;
use SL::Helper::Flash;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(delivery_term languages) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_delivery_term', only => [ qw(edit update destroy) ]);
__PACKAGE__->run_before('load_languages',     only => [ qw(new list edit create update) ]);


#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->render('delivery_term/list',
                title          => $::locale->text('Delivery terms'),
                DELIVERY_TERMS => SL::DB::Manager::DeliveryTerm->get_all_sorted);
}

sub action_new {
  my ($self) = @_;

  $self->{delivery_term} = SL::DB::DeliveryTerm->new;
  $self->render('delivery_term/form', title => $::locale->text('Create a new delivery term'));
}

sub action_edit {
  my ($self) = @_;
  $self->render('delivery_term/form', title => $::locale->text('Edit delivery term'));
}

sub action_create {
  my ($self) = @_;

  $self->{delivery_term} = SL::DB::DeliveryTerm->new;
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

sub action_destroy {
  my ($self) = @_;

  if (eval { $self->{delivery_term}->delete; 1; }) {
    flash_later('info',  $::locale->text('The delivery term has been deleted.'));
  } else {
    flash_later('error', $::locale->text('The delivery term is in use and cannot be deleted.'));
  }

  $self->redirect_to(action => 'list');
}

sub action_reorder {
  my ($self) = @_;

  SL::DB::DeliveryTerm->reorder_list(@{ $::form->{delivery_term_id} || [] });

  $self->render(\'', { type => 'json' });     # ' make Emacs happy
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
  my $is_new = !$self->{delivery_term}->id;
  my $params = delete($::form->{delivery_term}) || { };

  $self->{delivery_term}->assign_attributes(%{ $params });

  my @errors = $self->{delivery_term}->validate;

  if (@errors) {
    flash('error', @errors);
    $self->render('delivery_term/form', title => $is_new ? $::locale->text('Create a new delivery term') : $::locale->text('Edit delivery term'));
    return;
  }

  $self->{delivery_term}->save;
  foreach my $language (@{ $self->{languages} }) {
    $self->{delivery_term}->save_attribute_translation('description_long', $language, $::form->{"translation_" . $language->id});
  }

  flash_later('info', $is_new ? $::locale->text('The delivery term has been created.') : $::locale->text('The delivery term has been saved.'));
  $self->redirect_to(action => 'list');
}

sub load_delivery_term {
  my ($self) = @_;
  $self->{delivery_term} = SL::DB::DeliveryTerm->new(id => $::form->{id})->load;
}

sub load_languages {
  my ($self) = @_;
  $self->{languages} = SL::DB::Manager::Language->get_all_sorted;
}

1;
