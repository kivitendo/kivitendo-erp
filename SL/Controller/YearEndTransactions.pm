package SL::Controller::YearEndTransactions;

use strict;

use parent qw(SL::Controller::Base);

use utf8; # Umlauts in hardcoded German default texts
use DateTime;
use SL::Locale::String qw(t8);
use SL::Helper::Flash;
use SL::DBUtils;
use Data::Dumper;
use List::Util qw(sum);
use SL::ClientJS;

use SL::DB::Chart;
use SL::DB::GLTransaction;
use SL::DB::AccTransaction;
use SL::DB::Employee;
use SL::DB::Helper::AccountingPeriod qw(get_balance_starting_date get_balance_startdate_method_options);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(cb_date cb_startdate ob_date) ],
);

__PACKAGE__->run_before('check_auth');

sub action_form {
  my ($self) = @_;

  $self->cb_startdate($::locale->parse_date_to_object($self->get_balance_starting_date($self->cb_date)));

  my $defaults         = SL::DB::Default->get;
  my $carry_over_chart = SL::DB::Manager::Chart->find_by( id => $defaults->carry_over_account_chart_id     );
  my $profit_chart     = SL::DB::Manager::Chart->find_by( id => $defaults->profit_carried_forward_chart_id );
  my $loss_chart       = SL::DB::Manager::Chart->find_by( id => $defaults->loss_carried_forward_chart_id   );

  $self->render('yearend/form',
                title                            => t8('Year-end closing'),
                carry_over_chart                 => $carry_over_chart,
                profit_chart                     => $profit_chart,
                loss_chart                       => $loss_chart,
                balance_startdate_method_options => get_balance_startdate_method_options(),
               );
};

sub action_year_end_bookings {
  my ($self) = @_;

  $self->_parse_form;


  eval {
    _year_end_bookings( start_date => $self->cb_startdate,
                        cb_date    => $self->cb_date,
                      );
    1;
  } or do {
    $self->js->flash('error', t8('Error while applying year-end bookings!') . ' ' . $@);
    return $self->js->render;
  };

  my ($report_data, $profit_loss_sum) = _report(
                                                cb_date    => $self->cb_date,
                                                start_date => $self->cb_startdate,
                                               );

  my $html = $self->render('yearend/_charts', { layout  => 0 , process => 1, output => 0 },
                 charts          => $report_data,
                 profit_loss_sum => $profit_loss_sum,
               );
  return $self->js->flash('info', t8('Year-end bookings were successfully completed!'))
               ->html('#charts', $html)
               ->render;
}

sub action_get_start_date {
  my ($self) = @_;

  my $cb_date = $self->cb_date; # parse from form via init
  unless ( $self->cb_date ) {
    return $self->hide('#apply_year_end_bookings_button')
                ->flash('error', t8('Year-end date missing'))
                ->render;
  }

  $self->cb_startdate($::locale->parse_date_to_object($self->get_balance_starting_date($self->cb_date, $::form->{'balance_startdate_method'})));

  # $main::lxdebug->message(0, "found start date: ", $self->cb_startdate->to_kivitendo);

  return $self->js->val('#cb_startdate', $self->cb_startdate->to_kivitendo)
              ->show('#apply_year_end_bookings_button')
              ->show('.startdate')
              ->render;
}

sub action_update_charts {
  my ($self) = @_;

  $self->_parse_form;

  my ($report_data, $profit_loss_sum) = _report(
                                                cb_date   => $self->cb_date,
                                                start_date => $self->cb_startdate,
                                               );

  $self->render('yearend/_charts', { layout  => 0 , process => 1 },
                 charts          => $report_data,
                 profit_loss_sum => $profit_loss_sum,
               );
}

#
# helpers
#

sub _parse_form {
  my ($self) = @_;

  # parse dates
  $self->cb_startdate($::locale->parse_date_to_object($self->get_balance_starting_date($self->cb_date)));

  die "cb_date must come after start_date" unless $self->cb_date > $self->cb_startdate;

}

sub _year_end_bookings {
  my (%params) = @_;

  my $start_date = delete $params{start_date};
  my $cb_date    = delete $params{cb_date};

  my $defaults         = SL::DB::Default->get;
  my $carry_over_chart = SL::DB::Manager::Chart->find_by( id => $defaults->carry_over_account_chart_id     ) // die t8('No carry-over chart configured!');
  my $profit_chart     = SL::DB::Manager::Chart->find_by( id => $defaults->profit_carried_forward_chart_id ) // die t8('No profit carried forward chart configured!');
  my $loss_chart       = SL::DB::Manager::Chart->find_by( id => $defaults->loss_carried_forward_chart_id   ) // die t8('No profit and loss carried forward chart configured!');

  my ($report_data, $profit_loss_sum) = _report(
                                                start_date => $start_date,
                                                cb_date    => $cb_date,
                                               );

  my @asset_accounts       = grep { $_->{account_type} eq 'asset_account' }       @{ $report_data };
  my @profit_loss_accounts = grep { $_->{account_type} eq 'profit_loss_account' } @{ $report_data };

  my $ob_date = $cb_date->clone->add(days => 1);

  my ($credit_sum, $debit_sum) = (0,0);

  my $employee_id = SL::DB::Manager::Employee->current->id;

  # rather than having one gl transaction for each asset account, we group all
  # the debit sums and credit sums for cb and ob bookings, so we will have 4 gl
  # transactions:

  # * cb for credit
  # * cb for debit
  # * ob for credit
  # * ob for debit

  my $db = SL::DB->client;
  $db->with_transaction(sub {

    ######### asset accounts ########
    # need cb and ob transactions

    my $debit_balance  = 0;
    my $credit_balance = 0;

    my $asset_cb_debit_entry = SL::DB::GLTransaction->new(
      employee_id    => $employee_id,
      transdate      => $cb_date,
      reference      => 'SB ' . $cb_date->year,
      description    => 'Automatische SB-Buchungen Bestandskonten Soll für ' . $cb_date->year,
      ob_transaction => 0,
      cb_transaction => 1,
    );
    my $asset_ob_debit_entry = SL::DB::GLTransaction->new(
      employee_id    => $employee_id,
      transdate      => $ob_date,
      reference      => 'EB ' . $ob_date->year,
      description    => 'Automatische EB-Buchungen Bestandskonten Haben für ' . $ob_date->year,
      ob_transaction => 1,
      cb_transaction => 0,
    );
    my $asset_cb_credit_entry = SL::DB::GLTransaction->new(
      employee_id    => $employee_id,
      transdate      => $cb_date,
      reference      => 'SB ' . $cb_date->year,
      description    => 'Automatische SB-Buchungen Bestandskonten Haben für ' . $cb_date->year,
      ob_transaction => 0,
      cb_transaction => 1,
    );
    my $asset_ob_credit_entry = SL::DB::GLTransaction->new(
      employee_id    => $employee_id,
      transdate      => $ob_date,
      reference      => 'EB ' . $ob_date->year,
      description    => 'Automatische EB-Buchungen Bestandskonten Soll für ' . $ob_date->year,
      ob_transaction => 1,
      cb_transaction => 0,
    );
    $asset_cb_debit_entry->transactions([]);
    $asset_ob_debit_entry->transactions([]);
    $asset_cb_credit_entry->transactions([]);
    $asset_ob_credit_entry->transactions([]);

    foreach my $asset_account ( @asset_accounts ) {
      next if $asset_account->{amount_with_cb} == 0;

      # create cb and ob acc_trans entry here, but decide which gl entry to add it to later
      my $asset_cb_acc = SL::DB::AccTransaction->new(
        transdate      => $cb_date,
        ob_transaction => 0,
        cb_transaction => 1,
        chart_id       => $asset_account->{chart_id},
        chart_link     => $asset_account->{chart_link},
        tax_id         => 0,
        taxkey         => 0,
        amount         => - $asset_account->{amount_with_cb},
      );
      my $asset_ob_acc = SL::DB::AccTransaction->new(
        transdate      => $ob_date,
        ob_transaction => 1,
        cb_transaction => 0,
        chart_id       => $asset_account->{chart_id},
        chart_link     => $asset_account->{chart_link},
        tax_id         => 0,
        taxkey         => 0,
        amount         => $asset_account->{amount_with_cb},
      );

      if ( $asset_account->{amount_with_cb} < 0 ) {
        $debit_balance += $asset_account->{amount_with_cb};
        # $main::lxdebug->message(0, sprintf("adding accno %s with balance %s to debit", $asset_account->{accno}, $asset_account->{amount_with_cb}));

        $asset_cb_debit_entry->add_transactions($asset_cb_acc);
        $asset_ob_debit_entry->add_transactions($asset_ob_acc);
      } else {
        # $main::lxdebug->message(0, sprintf("adding accno %s with balance %s to credit", $asset_account->{accno}, $asset_account->{amount_with_cb}));
        $credit_balance += $asset_account->{amount_with_cb};
        $asset_cb_credit_entry->add_transactions($asset_cb_acc);
        $asset_ob_credit_entry->add_transactions($asset_ob_acc);
      };
    };

    my $debit_cb_acc = SL::DB::AccTransaction->new(
      transdate      => $cb_date,
      ob_transaction => 0,
      cb_transaction => 1,
      chart_id       => $carry_over_chart->id,
      chart_link     => $carry_over_chart->link, # maybe leave chart_link empty?
      tax_id         => 0,
      taxkey         => 0,
      amount         => $debit_balance,
    );
    my $debit_ob_acc = SL::DB::AccTransaction->new(
      transdate      => $ob_date,
      ob_transaction => 1,
      cb_transaction => 0,
      chart_id       => $carry_over_chart->id,
      chart_link     => $carry_over_chart->link,
      tax_id         => 0,
      taxkey         => 0,
      amount         => - $debit_balance,
    );
    my $credit_cb_acc = SL::DB::AccTransaction->new(
      transdate      => $cb_date,
      ob_transaction => 0,
      cb_transaction => 1,
      chart_id       => $carry_over_chart->id,
      chart_link     => $carry_over_chart->link, # maybe leave chart_link empty?
      tax_id         => 0,
      taxkey         => 0,
      amount         => $credit_balance,
    );
    my $credit_ob_acc = SL::DB::AccTransaction->new(
      transdate      => $ob_date,
      ob_transaction => 1,
      cb_transaction => 0,
      chart_id       => $carry_over_chart->id,
      chart_link     => $carry_over_chart->link,
      tax_id         => 0,
      taxkey         => 0,
      amount         => - $credit_balance,
    );
    $asset_cb_debit_entry->add_transactions($debit_cb_acc);
    $asset_ob_debit_entry->add_transactions($debit_ob_acc);
    $asset_cb_credit_entry->add_transactions($credit_cb_acc);
    $asset_ob_credit_entry->add_transactions($credit_ob_acc);

    $asset_cb_debit_entry->save if scalar @{ $asset_cb_debit_entry->transactions } > 1;
    $asset_ob_debit_entry->save if scalar @{ $asset_ob_debit_entry->transactions } > 1;
    $asset_cb_credit_entry->save if scalar @{ $asset_cb_credit_entry->transactions } > 1;
    $asset_ob_credit_entry->save if scalar @{ $asset_ob_credit_entry->transactions } > 1;

    #######  profit-loss accounts #######
    # these only have a closing balance, the balance is transferred to the profit-loss account

    # need to know if profit or loss first!
    # use amount_with_cb, so it can be run several times. So sum may be 0 the second time.
    my $profit_loss_sum = sum map { $_->{amount_with_cb} }
                              grep { $_->{account_type} eq 'profit_loss_account' }
                              @{$report_data};
    my $pl_chart;
    if ( $profit_loss_sum > 0 ) {
      $pl_chart = $profit_chart;
    } else {
      $pl_chart = $loss_chart;
    };

    my $pl_debit_balance  = 0;
    my $pl_credit_balance = 0;
    # soll = debit, haben = credit
    my $pl_cb_debit_entry = SL::DB::GLTransaction->new(
      employee_id    => $employee_id,
      transdate      => $cb_date,
      reference      => 'SB ' . $cb_date->year,
      description    => 'Automatische SB-Buchungen Erfolgskonten Soll für ' . $cb_date->year,
      ob_transaction => 0,
      cb_transaction => 1,
    );
    my $pl_cb_credit_entry = SL::DB::GLTransaction->new(
      employee_id    => $employee_id,
      transdate      => $cb_date,
      reference      => 'SB ' . $cb_date->year,
      description    => 'Automatische SB-Buchungen Erfolgskonten Haben für ' . $cb_date->year,
      ob_transaction => 0,
      cb_transaction => 1,
    );
    $pl_cb_debit_entry->transactions([]);
    $pl_cb_credit_entry->transactions([]);

    foreach my $profit_loss_account ( @profit_loss_accounts ) {
      # $main::lxdebug->message(0, sprintf("found chart %s with balance %s", $profit_loss_account->{accno}, $profit_loss_account->{amount_with_cb}));

      next if $profit_loss_account->{amount_with_cb} == 0;

      my $debit_cb_acc = SL::DB::AccTransaction->new(
        transdate      => $cb_date,
        ob_transaction => 0,
        cb_transaction => 1,
        chart_id       => $profit_loss_account->{chart_id},
        chart_link     => $profit_loss_account->{chart_link},
        tax_id         => 0,
        taxkey         => 0,
        amount         => - $profit_loss_account->{amount_with_cb},
      );
      my $credit_cb_acc = SL::DB::AccTransaction->new(
        transdate      => $cb_date,
        ob_transaction => 0,
        cb_transaction => 1,
        chart_id       => $profit_loss_account->{chart_id},
        chart_link     => $profit_loss_account->{chart_link},
        tax_id         => 0,
        taxkey         => 0,
        amount         => $profit_loss_account->{amount_with_cb},
      );
      if ( { $profit_loss_account->{amount_with_cb} < 0 } ) {
        $pl_debit_balance += $profit_loss_account->{amount_with_cb};
         $pl_cb_debit_entry->add_transactions($debit_cb_acc);
      } else {
        $pl_credit_balance += $profit_loss_account->{amount_with_cb};
         $pl_cb_credit_entry->add_transactions($credit_cb_acc);
      };
    };

    my $debit_cb_acc = SL::DB::AccTransaction->new(
      transdate      => $cb_date,
      ob_transaction => 0,
      cb_transaction => 1,
      chart_id       => $pl_chart->id,
      chart_link     => $pl_chart->link,
      tax_id         => 0,
      taxkey         => 0,
      amount         => $pl_debit_balance,
    );
    my $credit_cb_acc = SL::DB::AccTransaction->new(
      transdate      => $cb_date,
      ob_transaction => 0,
      cb_transaction => 1,
      chart_id       => $pl_chart->id,
      chart_link     => $pl_chart->link,
      tax_id         => 0,
      taxkey         => 0,
      amount         => - $pl_credit_balance,
    );
    $pl_cb_debit_entry->add_transactions($debit_cb_acc);
    $pl_cb_credit_entry->add_transactions($credit_cb_acc);

    $pl_cb_debit_entry->save  if scalar @{ $pl_cb_debit_entry->transactions }  > 1;
    $pl_cb_credit_entry->save if scalar @{ $pl_cb_credit_entry->transactions } > 1;

    ######### profit-loss transfer #########
    # and finally transfer the new balance of the profit-loss account via the carry-over account
    # we want to use profit_loss_sum with cb!

    my $carry_over_cb_entry = SL::DB::GLTransaction->new(
      employee_id    => $employee_id,
      transdate      => $cb_date,
      reference      => 'SB ' . $cb_date->year,
      description    => sprintf('Automatische SB-Buchung für %s %s',
                                $profit_loss_sum >= 0 ? 'Gewinnvortrag' : 'Verlustvortrag',
                                $cb_date->year,
                               ),
      ob_transaction => 0,
      cb_transaction => 1,
    );
    my $carry_over_ob_entry = SL::DB::GLTransaction->new(
      employee_id    => $employee_id,
      transdate      => $ob_date,
      reference      => 'EB ' . $ob_date->year,
      description    => sprintf('Automatische EB-Buchung für %s %s',
                                $profit_loss_sum >= 0 ? 'Gewinnvortrag' : 'Verlustvortrag',
                                $ob_date->year,
                               ),
      ob_transaction => 1,
      cb_transaction => 0,
    );
    $carry_over_cb_entry->transactions([]);
    $carry_over_ob_entry->transactions([]);

    my $carry_over_cb_acc_co = SL::DB::AccTransaction->new(
      transdate      => $cb_date,
      ob_transaction => 0,
      cb_transaction => 1,
      chart_id       => $carry_over_chart->id,
      chart_link     => $carry_over_chart->link,
      tax_id         => 0,
      taxkey         => 0,
      amount         => $profit_loss_sum,
    );
    my $carry_over_cb_acc_pl = SL::DB::AccTransaction->new(
      transdate      => $cb_date,
      ob_transaction => 0,
      cb_transaction => 1,
      chart_id       => $pl_chart->id,
      chart_link     => $pl_chart->link,
      tax_id         => 0,
      taxkey         => 0,
      amount         => - $profit_loss_sum,
    );

    $carry_over_cb_entry->add_transactions($carry_over_cb_acc_co);
    $carry_over_cb_entry->add_transactions($carry_over_cb_acc_pl);
    $carry_over_cb_entry->save if $profit_loss_sum != 0;

    my $carry_over_ob_acc_co = SL::DB::AccTransaction->new(
      transdate      => $ob_date,
      ob_transaction => 1,
      cb_transaction => 0,
      chart_id       => $pl_chart->id,
      chart_link     => $pl_chart->link,
      tax_id         => 0,
      taxkey         => 0,
      amount         => $profit_loss_sum,
    );
    my $carry_over_ob_acc_pl = SL::DB::AccTransaction->new(
      transdate      => $ob_date,
      ob_transaction => 1,
      cb_transaction => 0,
      chart_id       => $carry_over_chart->id,
      chart_link     => $carry_over_chart->link,
      tax_id         => 0,
      taxkey         => 0,
      amount         => - $profit_loss_sum,
    );

    $carry_over_ob_entry->add_transactions($carry_over_ob_acc_co);
    $carry_over_ob_entry->add_transactions($carry_over_ob_acc_pl);
    $carry_over_ob_entry->save if $profit_loss_sum != 0;

    my $consistency_query = <<SQL;
select sum(amount)
  from acc_trans
 where     (ob_transaction is true or cb_transaction is true)
       and (transdate = ? or transdate = ?)
SQL
     my ($sum) = my ($empty) = selectrow_query($::form, $db->dbh, $consistency_query,
                                               $cb_date,
                                               $ob_date
                                              );
     die "acc_trans transactions don't add up to zero" unless $sum == 0;

    1;
  }) or die $db->error;
}

sub _report {
  my (%params) = @_;

  my $start_date = delete $params{start_date};
  my $cb_date    = delete $params{cb_date};

  my $defaults = SL::DB::Default->get;
  die "no carry over account defined"
    unless defined $defaults->carry_over_account_chart_id
           and $defaults->carry_over_account_chart_id > 0;

  my $salden_query = <<SQL;
select c.id as chart_id,
       c.accno,
       c.description,
       c.link as chart_link,
       c.category,
       sum(a.amount) filter (where cb_transaction is false and ob_transaction is false) as amount,
       sum(a.amount) filter (where ob_transaction is true                             ) as ob_amount,
       sum(a.amount) filter (where cb_transaction is false                            ) as amount_without_cb,
       sum(a.amount) filter (where cb_transaction is true                             ) as cb_amount,
       sum(a.amount)                                                                    as amount_with_cb,
       case when c.category = ANY( '{I,E}'     ) then 'profit_loss_account'
            when c.category = ANY( '{A,C,L,Q}' ) then 'asset_account'
                                                 else null
            end                                                                         as account_type
  from acc_trans a
       inner join chart c on (c.id = a.chart_id)
 where     a.transdate >= ?
       and a.transdate <= ?
       and a.chart_id != ?
 group by c.id, c.accno, c.category
 order by account_type, c.accno
SQL

  my $dbh = SL::DB->client->dbh;
  my $report = selectall_hashref_query($::form, $dbh, $salden_query,
                                       $start_date,
                                       $cb_date,
                                       $defaults->carry_over_account_chart_id,
                                      );
  # profit_loss_sum is the actual profit/loss for the year, without cb, use "amount_without_cb")
  my $profit_loss_sum = sum map { $_->{amount_without_cb} }
                            grep { $_->{account_type} eq 'profit_loss_account' }
                            @{$report};

  return ($report, $profit_loss_sum);
}

#
# auth
#

sub check_auth {
  $::auth->assert('general_ledger');
}


#
# inits
#

sub init_ob_date        { $::locale->parse_date_to_object($::form->{ob_date})      }
sub init_cb_startdate   { $::locale->parse_date_to_object($::form->{cb_startdate}) }
sub init_cb_date        { $::locale->parse_date_to_object($::form->{cb_date})      }

1;
