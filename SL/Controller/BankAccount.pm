 SL::Controller::BankAccount;

use strict;

use parent qw(SL::Controller::Base);

use SL::Helper::Flash;
use SL::Locale::String;
use SL::DB::Default;
use SL::DB::Manager::BankAccount;
use SL::DB::Manager::BankTransaction;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(bank_account) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_bank_account', only => [ qw(edit update delete) ]);

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->render('bankaccounts/list',
                title           => t8('Bank accounts'),
                BANKACCOUNTS    => SL::DB::Manager::BankAccount->get_all_sorted,
               );
}

sub action_new {
  my ($self) = @_;

  $self->{bank_account} = SL::DB::BankAccount->new;
  $self->render('bankaccounts/form',
                 title => t8('Add bank account'));
}

sub action_edit {
  my ($self) = @_;

  $self->render('bankaccounts/form', title => t8('Edit bank account'));
}

sub action_create {
  my ($self) = @_;

  $self->{bank_account} = SL::DB::BankAccount->new;
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

sub action_delete {
  my ($self) = @_;

  if ( $self->{bank_account}->{number_of_bank_transactions} > 0 ) {
    flash_later('error', $::locale->text('The bank account has been used and cannot be deleted.'));
  } elsif ( eval { $self->{bank_account}->delete; 1; } ) {
    flash_later('info',  $::locale->text('The bank account has been deleted.'));
  } else {
    flash_later('error', $::locale->text('The bank account has been used and cannot be deleted.'));
  };
  $self->redirect_to(action => 'list');

}

sub action_reorder {
  my ($self) = @_;

  SL::DB::BankAccount->reorder_list(@{ $::form->{account_id} || [] });
  $self->render(\'', { type => 'json' });
}

#
# filters
#

sub check_auth {
  $::auth->assert('config');
}

sub load_bank_account {
  my ($self) = @_;

  $self->{bank_account} = SL::DB::BankAccount->new(id => $::form->{id})->load;
  $self->{bank_account}->{number_of_bank_transactions} = SL::DB::Manager::BankTransaction->get_all_count( query => [ local_bank_account_id => $self->{bank_account}->{id} ] );
}

#
# helpers
#

sub create_or_update {
  my ($self) = @_;
  my $is_new = !$self->{bank_account}->id;

  my $params = delete($::form->{bank_account}) || { };

  $self->{bank_account}->assign_attributes(%{ $params });

  my @errors = $self->{bank_account}->validate;

  if (@errors) {
    flash('error', @errors);
    $self->render('bankaccounts/form',
                   title => $is_new ? t8('Add bank account') : t8('Edit bank account'));
    return;
  }

  $self->{bank_account}->save;

  flash_later('info', $is_new ? t8('The bank account has been created.') : t8('The bank account has been saved.'));
  $self->redirect_to(action => 'list');
}

1;
