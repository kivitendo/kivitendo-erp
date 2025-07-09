package SL::Controller::BankImport;

use strict;

use parent qw(SL::Controller::Base);

use List::MoreUtils qw(apply);
use List::Util qw(max min);

use SL::DB::BankAccount;
use SL::DB::BankTransaction;
use SL::DB::Default;
use SL::Helper::Flash;
use SL::MT940;
use SL::SessionFile::Random;

use Rose::Object::MakeMethods::Generic
(
  scalar                  => [ qw(file_name transactions statistics charset) ],
  'scalar --get_set_init' => [ qw(bank_accounts) ],
);

__PACKAGE__->run_before('check_auth');

sub action_upload_mt940 {
  my ($self, %params) = @_;

  $self->setup_upload_mt940_action_bar;
  $self->render('bank_import/upload_mt940', title => $::locale->text('MT940 import'));
}

sub action_import_mt940_preview {
  my ($self, %params) = @_;

  if (!$::form->{file}) {
    flash_later('error', $::locale->text('You have to upload an MT940 file to import.'));
    return $self->redirect_to(action => 'upload_mt940');
  }

  die "missing file for action import_mt940_preview" unless $::form->{file};

  my $file = SL::SessionFile::Random->new(mode => '>');
  $file->fh->print($::form->{file});
  $file->fh->close;

  $self->charset($::form->{charset});
  $self->file_name($file->file_name);
  $self->parse_and_analyze_transactions;

  $self->setup_upload_mt940_preview_action_bar;
  $self->render('bank_import/import_mt940', title => $::locale->text('MT940 import preview'), preview => 1);
}

sub action_import_mt940 {
  my ($self, %params) = @_;

  die "missing file for action import_mt940" unless $::form->{file_name};

  $self->file_name($::form->{file_name});
  $self->charset($::form->{charset});
  $self->parse_and_analyze_transactions;
  $self->import_transactions;

  $self->render('bank_import/import_mt940', title => $::locale->text('MT940 import result'));
}

sub parse_and_analyze_transactions {
  my ($self, %params) = @_;

  my $errors     = 0;
  my $duplicates = 0;
  my ($min_date, $max_date);

  my $currency_id = SL::DB::Default->get->currency_id;

  $self->transactions([ sort { $a->{transdate} cmp $b->{transdate} } SL::MT940->parse($self->file_name, charset => $self->charset) ]);

  foreach my $transaction (@{ $self->transactions }) {
    $transaction->{bank_account}   = $self->bank_accounts->{ make_bank_account_idx($transaction->{local_bank_code}, $transaction->{local_account_number}) };
    $transaction->{bank_account} //= $self->bank_accounts->{ make_bank_account_idx('IBAN',                          $transaction->{local_account_number}) };

    if (!$transaction->{bank_account}) {
      $transaction->{error} = $::locale->text('No bank account configured for bank code/BIC #1, account number/IBAN #2.', $transaction->{local_bank_code}, $transaction->{local_account_number});
      $errors++;
      next;
    }

    $transaction->{local_bank_account_id} = $transaction->{bank_account}->id;
    $transaction->{currency_id}           = $currency_id;

    $min_date = min($min_date // $transaction->{transdate}, $transaction->{transdate});
    $max_date = max($max_date // $transaction->{transdate}, $transaction->{transdate});
  }

  my %existing_bank_transactions;

  if ((scalar(@{ $self->transactions }) - $errors) > 0) {
    my @entries =
      @{ SL::DB::Manager::BankTransaction->get_all(
          where => [
            transdate => { ge => $min_date },
            transdate => { lt => $max_date->clone->add(days => 1) },
          ],
          inject_results => 1) };

    %existing_bank_transactions = map { (make_transaction_idx($_) => 1) } @entries;
  }

  foreach my $transaction (@{ $self->transactions }) {
    next if $transaction->{error};

    if ($existing_bank_transactions{make_transaction_idx($transaction)}) {
      $transaction->{duplicate} = 1;
      $duplicates++;
      next;
    }
  }

  $self->statistics({
    total      => scalar(@{ $self->transactions }),
    errors     => $errors,
    duplicates => $duplicates,
    to_import  => scalar(@{ $self->transactions }) - $errors - $duplicates,
  });
}

sub import_transactions {
  my ($self, %params) = @_;

  my $imported = 0;

  SL::DB::client->with_transaction(sub {
    # make Emacs happy
    1;

    foreach my $transaction (@{ $self->transactions }) {
      next if $transaction->{error} || $transaction->{duplicate};

      SL::DB::BankTransaction->new(
        map { ($_ => $transaction->{$_}) } qw(amount currency_id local_bank_account_id purpose remote_account_number remote_bank_code remote_name transaction_code transdate valutadate end_to_end_id)
      )->save;

      $imported++;
    }

    1;
  });

  $self->statistics->{imported} = $imported;
}

sub check_auth {
  $::auth->assert('bank_transaction');
}

sub make_bank_account_idx {
  return join '/', map { my $q = $_; $q =~ s{ +}{}g; $q } @_;
}

sub normalize_text {
  my ($text) = @_;

  $text = lc($text // '');
  $text =~ s{ }{}g;

  return $text;
}

sub make_transaction_idx {
  my ($transaction) = @_;

  if (ref($transaction) eq 'SL::DB::BankTransaction') {
    $transaction = { map { ($_ => $transaction->$_) } qw(local_bank_account_id remote_account_number transdate valutadate amount purpose end_to_end_id) };
  }

  my @other_fields =  $transaction->{end_to_end_id} && $::instance_conf->get_check_bt_duplicates_endtoend
                   ? qw(end_to_end_id remote_account_number) : qw(purpose);
  return normalize_text(join '/',
                        map { $_ // '' }
                        ($transaction->{local_bank_account_id},
                         $transaction->{transdate}->ymd,
                         $transaction->{valutadate}->ymd,
                         (apply { s{0+$}{} } $transaction->{amount} * 1),
                         map { $transaction->{$_} } @other_fields));
}

sub init_bank_accounts {
  my ($self) = @_;

  my %bank_accounts;

  foreach my $bank_account (@{ SL::DB::Manager::BankAccount->get_all }) {
    if ($bank_account->bank_code && $bank_account->account_number) {
      $bank_accounts{make_bank_account_idx($bank_account->bank_code, $bank_account->account_number)} = $bank_account;
    }
    if ($bank_account->iban) {
      $bank_accounts{make_bank_account_idx('IBAN', $bank_account->iban)} = $bank_account;
    }
  }

  return \%bank_accounts;
}

sub setup_upload_mt940_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        $::locale->text('Preview'),
        submit    => [ '#form', { action => 'BankImport/import_mt940_preview' } ],
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_upload_mt940_preview_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        $::locale->text('Import'),
        submit    => [ '#form', { action => 'BankImport/import_mt940' } ],
        accesskey => 'enter',
        disabled  => $self->statistics->{to_import} ? undef : $::locale->text('No entries can be imported.'),
      ],
    );
  }
}

1;
