use strict;

use List::MoreUtils qw(any);
use POSIX qw(strftime);

use SL::BankAccount;
use SL::Chart;
use SL::Form;
use SL::ReportGenerator;

require "bin/mozilla/common.pl";
require "bin/mozilla/reportgenerator.pl";

sub bank_account_add {
  $main::lxdebug->enter_sub();

  bank_account_display_form('account' => {});

  $main::lxdebug->leave_sub();
}

sub bank_account_edit {
  $main::lxdebug->enter_sub();

  my %params  = @_;
  my $form    = $main::form;

  my $account = SL::BankAccount->retrieve('id' => $params{id} || $form->{id});

  bank_account_display_form('account' => $account);

  $main::lxdebug->leave_sub();
}

sub bank_account_delete {
  $::lxdebug->enter_sub();

  SL::BankAccount->delete(id => $::form->{account}{id});

  print $::form->redirect_header('bankaccounts.pl?action=bank_account_list');

  $::lxdebug->leave_sub();
}

sub bank_account_display_form {
  $main::lxdebug->enter_sub();

  my %params     = @_;
  my $account    = $params{account} || {};
  my $form       = $main::form;
  my $locale     = $main::locale;

  my $charts     = SL::Chart->list('link' => 'AP_paid');
  my $label_sub  = sub { join '--', map { $_[0]->{$_} } qw(accno description) };

  $form->{title} = $account->{id} ? $locale->text('Edit bank account') : $locale->text('Add bank account');

  $form->header();
  print $form->parse_html_template('bankaccounts/bank_account_display_form',
                                   { 'CHARTS'      => $charts,
                                     'account'     => $account,
                                     'chart_label' => $label_sub,
                                     'params'      => \%params });

  $main::lxdebug->leave_sub();
}

sub bank_account_save {
  $main::lxdebug->enter_sub();

  my $form    = $main::form;
  my $locale  = $main::locale;

  my $account = $form->{account} && (ref $form->{account} eq 'HASH') ? $form->{account} : { };

  if (any { !$account->{$_} } qw(account_number bank_code iban bic)) {
    bank_account_display_form('account' => $account,
                              'error'   => $locale->text('You have to fill in at least an account number, the bank code, the IBAN and the BIC.'));

    $main::lxdebug->leave_sub();
    return;
  }

  my $id = SL::BankAccount->save(%{ $account });

  if ($form->{callback}) {
    $form->redirect();

  } else {
    bank_account_edit('id' => $id);
  }

  $main::lxdebug->leave_sub();
}


sub bank_account_list {
  $main::lxdebug->enter_sub();

  my $form   = $main::form;
  my $locale = $main::locale;

  $form->{title}     = $locale->text('List of bank accounts');

  $form->{sort}    ||= 'account_number';
  $form->{sortdir}   = '1' if (!defined $form->{sortdir});

  $form->{callback}  = build_std_url('action=bank_account_list', 'sort', 'sortdir');

  my $accounts       = SL::BankAccount->list('sortorder' => $form->{sort},
                                             'sortdir'   => $form->{sortdir});

  my $report         = SL::ReportGenerator->new(\%main::myconfig, $form);

  my $href           = build_std_url('action=bank_account_list');

  my %column_defs = (
    'account_number' => { 'text' => $locale->text('Account number'), },
    'bank_code'      => { 'text' => $locale->text('Bank code'), },
    'bank'           => { 'text' => $locale->text('Bank'), },
    'bic'            => { 'text' => $locale->text('BIC'), },
    'iban'           => { 'text' => $locale->text('IBAN'), },
  );

  my @columns = qw(account_number bank bank_code bic iban);

  foreach my $name (@columns) {
    my $sortdir                 = $form->{sort} eq $name ? 1 - $form->{sortdir} : $form->{sortdir};
    $column_defs{$name}->{link} = $href . "&sort=$name&sortdir=$sortdir";
  }

  $report->set_options('raw_bottom_info_text'  => $form->parse_html_template('bankaccounts/bank_account_list_bottom'),
                       'std_column_visibility' => 1,
                       'output_format'         => 'HTML',
                       'title'                 => $form->{title},
                       'attachment_basename'   => $locale->text('bankaccounts') . strftime('_%Y%m%d', localtime time),
    );
  $report->set_options_from_form();
  $locale->set_numberformat_wo_thousands_separator(\%::myconfig) if lc($report->{options}->{output_format}) eq 'csv';

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options('bank_account_list');
  $report->set_sort_indicator($form->{sort}, $form->{sortdir});

  my $edit_url = build_std_url('action=bank_account_edit', 'callback');

  foreach my $account (@{ $accounts }) {
    my $row = { map { $_ => { 'data' => $account->{$_} } } keys %{ $account } };

    $row->{account_number}->{link} = $edit_url . '&id=' . E($account->{id});

    $report->add_data($row);
  }

  $report->generate_with_headers();

  $main::lxdebug->leave_sub();
}

sub dispatcher {
  my $form = $main::form;

  foreach my $action (qw(bank_account_save bank_account_delete)) {
    if ($form->{"action_${action}"}) {
      call_sub($action);
      return;
    }
  }

  $form->error($main::locale->text('No action defined.'));
}

1;
