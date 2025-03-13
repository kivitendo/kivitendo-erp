package SL::Controller::DeliveryTerm;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::Customer;
use SL::DB::DeliveryTerm;
use SL::DB::Language;
use SL::DB::Vendor;
use SL::Helper::Flash;
use SL::Locale::String qw(t8);

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

  $self->setup_list_action_bar;
  $self->render('delivery_term/list',
                title          => $::locale->text('Delivery terms'),
                DELIVERY_TERMS => SL::DB::Manager::DeliveryTerm->get_all_sorted);
}

sub action_new {
  my ($self) = @_;

  $self->{delivery_term} = SL::DB::DeliveryTerm->new;
  $self->setup_form_action_bar;
  $self->render('delivery_term/form', title => $::locale->text('Create a new delivery term'));
}

sub action_edit {
  my ($self) = @_;
  $self->setup_form_action_bar;
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
    flash('error', $_) for @errors;
    $self->render('delivery_term/form', title => $is_new ? $::locale->text('Create a new delivery term') : $::locale->text('Edit delivery term'));
    return;
  }

  $self->{delivery_term}->save;
  foreach my $language (@{ $self->{languages} }) {
    $self->{delivery_term}->save_attribute_translation('description_long', $language, $::form->{"translation_" . $language->id});
  }

  if ($::form->{remove_customer_vendor_delivery_terms}) {
    foreach my $class (qw(Customer Vendor)) {
      "SL::DB::Manager::${class}"->update_all(
        set   => { delivery_term_id => undef },
        where => [ delivery_term_id => $self->{delivery_term}->id ],
      );
    }
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

sub setup_list_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      link => [
        t8('Add'),
        link => $self->url_for(action => 'new'),
      ],
    );
  }
}

sub setup_form_action_bar {
  my ($self) = @_;

  my $is_new = !$self->delivery_term->id;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Save'),
        submit    => [ '#form', { action => 'DeliveryTerm/' . ($is_new ? 'create' : 'update') } ],
        checks    => [ 'kivi.validate_form' ],
        accesskey => 'enter',
      ],

      action => [
        t8('Delete'),
        submit   => [ '#form', { action => 'DeliveryTerm/destroy' } ],
        confirm  => t8('Do you really want to delete this object?'),
        disabled => $is_new ? t8('This object has not been saved yet.') : undef,
      ],

      'separator',

      link => [
        t8('Abort'),
        link => $self->url_for(action => 'list'),
      ],
    );
  }
  $::request->layout->add_javascripts('kivi.Validator.js');
}

1;
