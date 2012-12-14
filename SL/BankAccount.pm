package SL::BankAccount;

use strict;

use SL::DBUtils;

sub save {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  if (!$params{id}) {
    ($params{id}) = selectfirst_array_query($form, $dbh, qq|SELECT nextval('id')|);
    do_query($form, $dbh, qq|INSERT INTO bank_accounts (id, chart_id)
                             VALUES (?, (SELECT id FROM chart LIMIT 1))|, conv_i($params{id}));
  }

  my $query =
    qq|UPDATE bank_accounts
       SET account_number = ?, bank_code = ?, bank = ?, iban = ?, bic = ?, chart_id = ?
       WHERE id = ?|;
  my @values = (@params{qw(account_number bank_code bank iban bic)}, conv_i($params{chart_id}), conv_i($params{id}));

  do_query($form, $dbh, $query, @values);

  $dbh->commit() unless ($params{dbh});

  $main::lxdebug->leave_sub();

  return $params{id};
}

sub retrieve {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(id));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my $query    = qq|SELECT * FROM bank_accounts WHERE id = ?|;
  my $account  = selectfirst_hashref_query($form, $dbh, $query, conv_i($params{id}));

  $main::lxdebug->leave_sub();

  return $account;
}

sub delete {
  $::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(id));

  my $dbh = $params{dbh} || $::form->get_standard_dbh(%::myconfig);

  my $query = '
    DELETE
    FROM bank_accounts
    WHERE id = ?';

  do_query($::form, $dbh, $query, conv_i($params{id}));

  $dbh->commit();

  $::lxdebug->leave_sub();
}

sub list {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my %sort_columns = (
    'account_number'    => [ 'ba.account_number', ],
    'bank_code'         => [ 'ba.bank_code', 'ba.account_number', ],
    'bank'              => [ 'ba.bank',      'ba.account_number', ],
    'iban'              => [ 'ba.iban',      'ba.account_number', ],
    'bic'               => [ 'ba.bic',       'ba.account_number', ],
    'chart_accno'       => [ 'c.accno', ],
    'chart_description' => [ 'c.description', ],
    );

  my %sort_spec = create_sort_spec('defs' => \%sort_columns, 'default' => 'bank', 'column' => $params{sortorder}, 'dir' => $params{sortdir});

  my $query =
    qq|SELECT ba.id, ba.account_number, ba.bank_code, ba.bank, ba.iban, ba.bic, ba.chart_id,
         c.accno AS chart_accno, c.description AS chart_description
       FROM bank_accounts ba
       LEFT JOIN chart c ON (ba.chart_id = c.id)
       ORDER BY $sort_spec{sql}|;

  my $results = selectall_hashref_query($form, $dbh, $query);

  $main::lxdebug->leave_sub();

  return $results;
}


1;
