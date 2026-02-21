package SL::Controller::BankImport;

use strict;

use parent qw(SL::Controller::Base);

use Carp;
use List::MoreUtils qw(apply);
use List::Util qw(max min sum);

use SL::DB::BankAccount;
use SL::DB::BankTransaction;
use SL::DB::BankTransactionAccTrans;
use SL::DB::Default;
use SL::DB::Manager::RecordTemplate;
use SL::Helper::Flash;
use SL::Locale::String qw(t8);
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
  my $sepa       = 0;
  my $gl_bookings = 0;
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

  my $templates_gl = SL::DB::Manager::RecordTemplate->get_all(
    query        => [ template_type => 'gl_transaction',
                      chart_id      => SL::DB::Manager::BankAccount->find_by(id => $self->transactions->[0]->{local_bank_account_id})->chart_id,
                      bank_import_template => 1,
                    ],
    with_objects => [ qw(employee record_template_items) ],
  );

  foreach my $transaction (@{ $self->transactions }) {
    next if $transaction->{error};

    if ($existing_bank_transactions{make_transaction_idx($transaction)}) {
      $transaction->{duplicate} = 1;
      $duplicates++;
      next;
    }
    # check if endtoend id exists and matches one in kivi
    if ($transaction->{end_to_end_id} && $transaction->{end_to_end_id} =~ m/^KIVITENDO/) {
      $transaction->{sei} = $self->_check_sepa_automatic(transaction => $transaction);
      $sepa++ if ref $transaction->{sei} eq 'SL::DB::SepaExportItem';
    }
    # check if template_gl description matches purpose
    my $direct_gl = [ grep { $_->description && index($transaction->{purpose}, $_->description) != -1 } @{ $templates_gl } ];
    if (scalar @{ $direct_gl} == 1) {
      $transaction->{direct_gl} = $direct_gl->[0];
      $gl_bookings++;
    }
  }

  $self->statistics({
    total      => scalar(@{ $self->transactions }),
    errors     => $errors,
    duplicates => $duplicates,
    sepa       => $sepa,
    gl_bookings => $gl_bookings,
    to_import  => scalar(@{ $self->transactions }) - $errors - $duplicates,
  });
}

sub import_transactions {
  my ($self, %params) = @_;

  my $imported = 0;
  my $sepa     = 0;
  my $gl_bookings = 0;

  my $db = SL::DB::client;
  $db->with_transaction(sub {
    # make Emacs happy
    1;

    foreach my $transaction (@{ $self->transactions }) {
      next if $transaction->{error} || $transaction->{duplicate};

      my $current_bt = SL::DB::BankTransaction->new(
        map { ($_ => $transaction->{$_}) } qw(amount currency_id local_bank_account_id purpose remote_account_number remote_bank_code remote_name transaction_code transdate valutadate end_to_end_id)
      )->save;

      $imported++;

      if ($transaction->{sei} && !$::form->{"no_automatic_" . $transaction->{sei}->id}) {
        $self->_book_sepa(bt => $current_bt, sei => $transaction->{sei});
        $sepa++;
        $transaction->{sei_ok} = 1;
      }
      if ($transaction->{direct_gl} && !$::form->{"no_automatic_" . $transaction->{direct_gl}->id}) {
        $transaction->{direct_gl_id} = $self->_book_gl_template(bt => $current_bt, direct_gl_template_id => $transaction->{direct_gl}->id);
        $gl_bookings++;
      }
    }

    1;
  }) || die t8('db error while importing MT940: #1 ', $db->error);

  $self->statistics->{imported} = $imported;
  $self->statistics->{sepa}     = $sepa;
  $self->statistics->{gl_bookings} = $gl_bookings;
}

sub _book_sepa {
  my ($self, %params) = @_;
  die "Need a bankt transaction" unless ref $params{bt}  eq 'SL::DB::BankTransaction';
  die "Need a SEPA Export Item"  unless ref $params{sei} eq 'SL::DB::SepaExportItem';

  my $bt  = delete $params{bt};
  my $sei = delete $params{sei};

  $bt->load;

  my @seis;

  if ($sei->is_combined_payment) {
    $sei->set_executed;
    @seis = grep { $_->collected_payment && $sei->end_to_end_id eq $_->end_to_end_id }
                @{ $sei->sepa_export->find_sepa_export_item };
  } else {
    push @seis, $sei;
  }

  foreach my $sepa_export_item (@seis) {
    my $invoice;
    if ( $sepa_export_item->ar_id ) {
      $invoice = SL::DB::Manager::Invoice->find_by(id => $sepa_export_item->ar_id);
    } elsif ( $sepa_export_item->ap_id ) {
      $invoice = SL::DB::Manager::PurchaseInvoice->find_by(id => $sepa_export_item->ap_id);
    } else {
      die "sepa_export_item needs either ar_id or ap_id\n";
    }
    $sepa_export_item->set_executed;

    # only real open invoices need payments
    my $invoice_open_amount =     $sepa_export_item->payment_type eq 'with_skonto_pt'
                              && ! abs($sepa_export_item->invoice_booked_skonto_amount) > 0.001
                              ? $sepa_export_item->invoice_open_amount_less_skonto
                              : $sepa_export_item->invoice_open_amount;

    next if abs($invoice_open_amount) < 0.001;

    my @acc_ids = $invoice->pay_invoice(amount       => $invoice_open_amount * -1,
                                        chart_id     => $bt->local_bank_account->chart_id,
                                        source       => $sepa_export_item->reference,
                                        transdate    => $bt->valutadate->to_kivitendo,
                                        bt_id        => $bt->id,
                                        # if foreign currency, just send record exchange rate
                                        (currency_id  => $invoice->currency_id)     x!! $invoice->forex,
                                        (exchangerate => $invoice->get_exchangerate)x!! $invoice->forex,
                                        # if no skonto booking yet but skonto_pt, just book skonto
                                        (payment_type  => 'with_skonto_pt')         x!!(    $sepa_export_item->payment_type eq 'with_skonto_pt'
                                                                                        && !$sepa_export_item->invoice_booked_skonto_amount    ),
                                       );
    # First element is the booked amount for accno bank
    my $bank_amount = shift @acc_ids;
    die "Invalid calc: $bank_amount->{return_bank_amount} " . $bt->amount unless ( $bank_amount->{return_bank_amount} < 0 && $bt->amount < 0
                                                                                || $bank_amount->{return_bank_amount} > 0 && $bt->amount > 0 );
    $bt->invoice_amount($bt->invoice_amount + $bank_amount->{return_bank_amount});
    foreach my $acc_trans_id (@acc_ids) {
        my $id_type = $invoice->is_sales ? 'ar' : 'ap';
        my  %props_acc = (
          acc_trans_id        => $acc_trans_id,
          bank_transaction_id => $bt->id,
          $id_type            => $invoice->id,
        );
        SL::DB::BankTransactionAccTrans->new(%props_acc)->save;
    }
    # Record a record link from the bank transaction to the invoice
    my %props = (
      from_table => 'bank_transactions',
      from_id    => $bt->id,
      to_table   => $invoice->is_sales ? 'ar' : 'ap',
      to_id      => $invoice->id,
    );
    SL::DB::RecordLink->new(%props)->save;
  }
  $bt->save;
  return undef;
}
sub _book_gl_template {
  my ($self, %params) = @_;
  die "Need a bankt transaction" unless ref $params{bt} eq 'SL::DB::BankTransaction';

  my $gl_template = SL::DB::Manager::RecordTemplate->find_by(id => $params{direct_gl_template_id});
  die "Need a template GL" unless ref $gl_template eq 'SL::DB::RecordTemplate';

  my $bt = delete $params{bt};

  die "Need exactly two valid GL entries" unless     scalar @{ $gl_template->record_template_items } == 2
                                                 || (scalar @{ $gl_template->record_template_items } == 3
                                                     && $gl_template->record_template_items->[2]->amount1 == 0
                                                     && $gl_template->record_template_items->[2]->amount2 == 0);
  my ($credit, $debit, $credit_tax_id, $debit_tax_id);

  foreach my $acc_trans (@{ $gl_template->items }) {
    if ($acc_trans->amount1 > 0) {
      $credit = SL::DB::Chart->load_cached($acc_trans->chart_id);
      $credit_tax_id = $acc_trans->tax_id;
    } elsif ($acc_trans->amount2 > 0) {
      $debit  = SL::DB::Chart->load_cached($acc_trans->chart_id);
      $debit_tax_id = $acc_trans->tax_id;
    }
  }
  croak("Missing chart")  unless ref $credit eq 'SL::DB::Chart' && ref $debit eq 'SL::DB::Chart';

  $bt->load;

  $gl_template->substitute_variables($bt->valutadate);

  my $current_transaction = SL::DB::GLTransaction->new(
         transdate      => $bt->valutadate,
         description    => $bt->purpose,
         reference      => $gl_template->reference,
         taxincluded    => $gl_template->taxincluded,
         department_id  => $gl_template->department_id,
         imported       => 0, # not imported
         transaction_description   => $gl_template->transaction_description,
    )->add_chart_booking(
         chart  => $debit,
         debit  => abs($bt->amount),
         source => t8('Automatic GL Template Booking'),
         tax_id => $debit_tax_id,
    )->add_chart_booking(
         chart  => $credit,
         credit => abs($bt->amount),
         source => t8('Automatic GL Template Booking'),
         tax_id => $credit_tax_id,
    )->post;

  # add a stable link acc_trans_id to bank_transactions.id
  foreach my $transaction (@{ $current_transaction->transactions }) {
    my %props_acc = (
         acc_trans_id        => $transaction->acc_trans_id,
         bank_transaction_id => $bt->id,
         gl                  => $current_transaction->id,
    );
    SL::DB::BankTransactionAccTrans->new(%props_acc)->save;
  }

  $bt->invoice_amount($bt->amount);
  $bt->save;

  # Record a record link from banktransactions to gl
  my %props_rl = (
       from_table => 'bank_transactions',
       from_id    => $bt->id,
       to_table   => 'gl',
       to_id      => $current_transaction->id,
  );
  SL::DB::RecordLink->new(%props_rl)->save;


  return $current_transaction->id;
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

sub _check_sepa_automatic {
  my ($self, %params) = @_;
  die "Need a transaction" unless ref $params{transaction} eq 'HASH';

  my $transaction = delete $params{transaction};

  die "Invalid transaction, need amount and SEPA EndToEnd Id"
                                   unless $transaction->{end_to_end_id} && $transaction->{amount};
  die "Invalid kivi end_to_end_id" unless $transaction->{end_to_end_id} =~ m/^KIVITENDO/;
  my $sei = SL::DB::Manager::SepaExportItem->find_by(end_to_end_id     => $transaction->{end_to_end_id},
                                                     executed          => 0,
                                                     collected_payment => 0);

  return undef unless ref $sei eq 'SL::DB::SepaExportItem';

  my $invoice_open_amount =  # combined total (open) amount should equal bank import amount
                            $sei->is_combined_payment
                            ? sum map  {   $_->payment_type eq 'with_skonto_pt' && ! abs($_->invoice_booked_skonto_amount) > 0.001
                                         ? $_->invoice_open_amount_less_skonto
                                         : $_->invoice_open_amount }
                                  grep {$_->collected_payment && $_->end_to_end_id eq $sei->end_to_end_id} @{ $sei->sepa_export->sepa_export_item }
                            # single sepa item with or without skonto
                            : $sei->payment_type eq 'with_skonto_pt' && ! abs ($sei->invoice_booked_skonto_amount) > 0.001
                            ? $sei->invoice_open_amount_less_skonto
                            : $sei->invoice_open_amount;

  return (abs ($transaction->{amount} - $invoice_open_amount) < 0.01 && abs( abs ($invoice_open_amount) - $sei->amount < 0.01 )) ? $sei : undef;

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
