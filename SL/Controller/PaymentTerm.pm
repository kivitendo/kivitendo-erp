package SL::Controller::PaymentTerm;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::PaymentTerm;
use SL::DB::Language;
use SL::Helper::Flash;
use SL::Locale::String qw(t8);

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(payment_term languages) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_payment_term', only => [ qw(         edit        update destroy) ]);
__PACKAGE__->run_before('load_languages',    only => [ qw(new list edit create update) ]);
__PACKAGE__->run_before('setup',             only => [ qw(new      edit) ]);

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->setup_list_action_bar;
  $self->render('payment_term/list',
                title         => $::locale->text('Payment terms'),
                PAYMENT_TERMS => SL::DB::Manager::PaymentTerm->get_all_sorted);
}

sub action_new {
  my ($self) = @_;

  $self->{payment_term} = SL::DB::PaymentTerm->new(auto_calculation => 1);
  $self->setup_form_action_bar;
  $self->render('payment_term/form', title => $::locale->text('Create a new payment term'));
}

sub action_edit {
  my ($self) = @_;

  $self->setup_form_action_bar;
  $self->render('payment_term/form', title => $::locale->text('Edit payment term'));
}

sub action_create {
  my ($self) = @_;

  $self->{payment_term} = SL::DB::PaymentTerm->new;
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

sub action_destroy {
  my ($self) = @_;

  if (eval { $self->{payment_term}->delete; 1; }) {
    flash_later('info',  $::locale->text('The payment term has been deleted.'));
  } else {
    flash_later('error', $::locale->text('The payment term is in use and cannot be deleted.'));
  }

  $self->redirect_to(action => 'list');
}

sub action_reorder {
  my ($self) = @_;

  SL::DB::PaymentTerm->reorder_list(@{ $::form->{payment_term_id} || [] });

  $self->render(\'', { type => 'json' });
}

#
# filters
#

sub check_auth {
  $::auth->assert('config');
}

sub setup {
  $::request->layout->use_javascript("kivi.PaymentTerm.js");
}

#
# helpers
#

sub create_or_update {
  my $self   = shift;
  my $is_new = !$self->{payment_term}->id;
  my $params = delete($::form->{payment_term}) || { };

  $self->{payment_term}->assign_attributes(%{ $params });
  $self->{payment_term}->terms_netto(0) if !$self->{payment_term}->auto_calculation;

  my @errors = $self->{payment_term}->validate;

  if (@errors) {
    flash('error', $_) for @errors;
    $self->render('payment_term/form', title => $is_new ? $::locale->text('Create a new payment term') : $::locale->text('Edit payment term'));
    return;
  }

  $self->{payment_term}->save;
  foreach my $language (@{ $self->{languages} }) {
    $self->{payment_term}->save_attribute_translation('description_long', $language, $::form->{"translation_" . $language->id});
    $self->{payment_term}->save_attribute_translation('description_long_invoice', $language, $::form->{"translation_invoice_" . $language->id});
  }

  flash_later('info', $is_new ? $::locale->text('The payment term has been created.') : $::locale->text('The payment term has been saved.'));
  $self->redirect_to(action => 'list');
}

sub load_payment_term {
  my ($self) = @_;
  $self->{payment_term} = SL::DB::PaymentTerm->new(id => $::form->{id})->load;
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

  my $is_new = !$self->payment_term->id;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Save'),
        submit    => [ '#form', { action => 'PaymentTerm/' . ($is_new ? 'create' : 'update') } ],
        checks    => [ 'kivi.validate_form' ],
        accesskey => 'enter',
      ],

      action => [
        t8('Delete'),
        submit   => [ '#form', { action => 'PaymentTerm/destroy' } ],
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
