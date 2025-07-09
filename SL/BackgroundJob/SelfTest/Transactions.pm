package SL::BackgroundJob::SelfTest::Transactions;

use utf8;
use strict;
use parent qw(SL::BackgroundJob::SelfTest::Base);

use SL::DBUtils;

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(dbh fromdate todate) ],
);

sub run {
  my ($self) = @_;

  $self->_setup;

  $self->tester->plan(tests => 34);

  $self->check_konten_mit_saldo_nicht_in_guv;
  $self->check_bilanzkonten_mit_pos_eur;
  $self->check_balanced_individual_transactions;
  $self->check_verwaiste_acc_trans_eintraege;
  $self->check_verwaiste_invoice_eintraege;
  $self->check_ar_acc_trans_amount;
  $self->check_ap_acc_trans_amount;
  $self->check_netamount_laut_invoice_ar;
  $self->check_invnumbers_unique;
  $self->check_summe_stornobuchungen;
  $self->check_ar_paid;
  $self->check_ap_paid;
  $self->check_ar_overpayments;
  $self->check_ap_overpayments;
  $self->check_paid_stornos;
  $self->check_stornos_ohne_partner;
  $self->check_overpayments;
  $self->check_every_account_with_taxkey;
  $self->calc_saldenvortraege;
  $self->check_missing_tax_bookings;
  $self->check_bank_transactions_overpayments;
  $self->check_ar_paid_acc_trans;
  $self->check_ap_paid_acc_trans;
  $self->check_zero_amount_paid_but_datepaid_exists;
  $self->check_orphaned_reconciliated_links;
  $self->check_recommended_client_settings;
  $self->check_orphaned_bank_transaction_acc_trans_links;
  $self->check_consistent_itimes;
}

sub _setup {
  my ($self) = @_;

  # TODO FIXME calc dates better, unless this is wanted
  $self->fromdate(DateTime->new(day => 1, month => 1, year => DateTime->today->year));
  $self->todate($self->fromdate->clone->add(years => 1)->add(days => -1));
  $self->dbh($::form->get_standard_dbh);
}

sub check_konten_mit_saldo_nicht_in_guv {
  my ($self) = @_;

  my $query = qq|
    SELECT c.accno, c.description, c.category, SUM(a.amount) AS Saldo
    FROM chart c,
         acc_trans a
    WHERE c.id = a.chart_id
     and  (c.category like 'I' or c.category like 'E')
     and  amount != 0
     and  pos_eur is null
         and  a.transdate >= ? and a.transdate <= ?
    GROUP BY c.accno,c.description,c.category,c.pos_bilanz,c.pos_eur
    ORDER BY c.accno|;

  my $konten_nicht_in_guv =  selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  my $correct = 0 == scalar grep { $_->{Saldo} } @$konten_nicht_in_guv;

  $self->tester->ok($correct, "Erfolgskonten mit Saldo nicht in GuV (Saldenvortragskonten können ignoriert werden, sollten aber 0 sein)");
  if (!$correct) {
    for my $konto (@$konten_nicht_in_guv) {
      $self->tester->diag($konto);
    }
  }
}

sub check_bilanzkonten_mit_pos_eur {
  my ($self) = @_;

  my $query = qq|SELECT accno, description FROM chart WHERE (category = 'A' OR category = 'L' OR category = 'Q') AND (pos_eur IS NOT NULL OR pos_eur != 0)|;

  my $bilanzkonten_mit_pos_eur = selectall_hashref_query($::form, $self->dbh, $query);
  if (@$bilanzkonten_mit_pos_eur) {
     $self->tester->ok(0, "Es gibt Bilanzkonten die der GuV/EÜR zugeordnet sind)");
     $self->tester->diag("$_->{accno}  $_->{description}") for @$bilanzkonten_mit_pos_eur;
  } else {
     $self->tester->ok(1, "Keine Bilanzkonten in der GuV");
  }
}

sub check_balanced_individual_transactions {
  my ($self) = @_;

  my $query = qq|
    select sum(ac.amount) as amount,trans_id,ar.invnumber as ar,ap.invnumber as ap,gl.reference as gl
      from acc_trans ac
      left join ar on (ar.id = ac.trans_id)
      left join ap on (ap.id = ac.trans_id)
      left join gl on (gl.id = ac.trans_id)
    where ac.transdate >= ? AND ac.transdate <= ?
    group by trans_id,ar.invnumber,ap.invnumber,gl.reference
    having sum(ac.amount) != 0;|;

  my $acs = selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);
  if (@$acs) {
    $self->tester->ok(0, "Es gibt unausgeglichene acc_trans-Transaktionen:");
    for my $ac (@{ $acs }) {
      $self->tester->diag("trans_id: $ac->{trans_id},  amount = $ac->{amount}, ar: $ac->{ar} ap: $ac->{ap} gl: $ac->{gl}");
    }
  } else {
    $self->tester->ok(1, "Alle acc_trans Transaktionen ergeben in Summe 0, keine unausgeglichenen Transaktionen");
  }
}

sub check_verwaiste_acc_trans_eintraege {
  my ($self) = @_;

  my $query = qq|
      select trans_id,amount,accno,description from acc_trans a
    left join chart c on (c.id = a.chart_id)
    where trans_id not in (select id from gl union select id from ar union select id from ap order by id)
      and a.transdate >= ? and a.transdate <= ? ;|;

  my $verwaiste_acs = selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);
  if (@$verwaiste_acs) {
     $self->tester->ok(0, "Es gibt verwaiste acc-trans Einträge! (wo ar/ap/gl-Eintrag fehlt)");
     $self->tester->diag($_) for @$verwaiste_acs;
  } else {
     $self->tester->ok(1, "Keine verwaisten acc-trans Einträge (wo ar/ap/gl-Eintrag fehlt)");
  }
}

sub check_verwaiste_invoice_eintraege {
  # this check is always run for all invoice entries in the entire database
  my ($self) = @_;
  my $query = qq|
     select * from invoice i
      where trans_id not in (select id from ar WHERE ar.transdate >=? AND ar.transdate <=?
                             UNION
                             select id from ap WHERE ap.transdate >= ? and ap.transdate <= ?)
      AND i.transdate >=? AND i.transdate <=?|;

  my $verwaiste_invoice = selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate,
                                                  $self->fromdate, $self->todate, $self->fromdate, $self->todate);


  if (@$verwaiste_invoice) {
     $self->tester->ok(0, "Es gibt verwaiste invoice Einträge! (wo ar/ap-Eintrag fehlt)");
     for my $invoice ( @{ $verwaiste_invoice }) {
        $self->tester->diag("invoice: id: $invoice->{id}  trans_id: $invoice->{trans_id}   description: $invoice->{description}  itime: $invoice->{itime}");
     };
  } else {
     $self->tester->ok(1, "Keine verwaisten invoice Einträge (wo ar/ap-Eintrag fehlt)");                                                                                       }
}

sub check_netamount_laut_invoice_ar {
  my ($self) = @_;
  my $query = qq|
    select sum(round(cast(i.qty* i.sellprice / COALESCE(price_factor, 1) as numeric), 2))
    from invoice i
    left join ar a on (a.id = i.trans_id)
    where a.transdate >= ? and a.transdate <= ?;|;
  my ($netamount_laut_invoice) =  selectfirst_array_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  $query = qq| select sum(netamount) from ar where transdate >= ? and transdate <= ? AND invoice; |;
  my ($netamount_laut_ar) =  selectfirst_array_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  # should be enough to get a diff below 1. We have currently the following issues:
  # verkaufsbericht berücksichtigt keinen rabatt
  # fxsellprice ist mit mwst-inklusive
  my $correct = abs($netamount_laut_invoice - $netamount_laut_ar) < 1;

  $self->tester->ok($correct, "Summe laut Verkaufsbericht sollte gleich Summe aus Verkauf -> Berichte -> Rechnungen sein");
  if (!$correct) {
    $self->tester->diag("Netto-Summe laut Verkaufsbericht (invoice): $netamount_laut_invoice");
    $self->tester->diag("Netto-Summe laut Verkauf -> Berichte -> Rechnungen: $netamount_laut_ar");
  }
}

sub check_invnumbers_unique {
  my ($self) = @_;

  my $query = qq| select  invnumber,count(invnumber) as count from ar
               where transdate >= ? and transdate <= ?
               group by invnumber
               having count(invnumber) > 1; |;
  my $non_unique_invnumbers =  selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  if (@$non_unique_invnumbers) {
    $self->tester->ok(0, "Es gibt doppelte Rechnungsnummern");
    for my $invnumber (@{ $non_unique_invnumbers }) {
      $self->tester->diag("invnumber: $invnumber->{invnumber}    $invnumber->{count}x");
    }
  } else {
    $self->tester->ok(1, "Alle Rechnungsnummern sind eindeutig");
  }
}

sub check_summe_stornobuchungen {
  my ($self) = @_;

  my %sums_canceled;
  my %sums_storno;
  foreach my $table (qw(ar ap)) {
    # check invoices canceled (stornoed) in consideration period (corresponding stornos do not have to be in this period)
    my $query = qq|
      SELECT sum(amount) FROM $table WHERE id IN (
        SELECT id FROM $table WHERE storno IS TRUE AND storno_id IS NULL AND transdate >= ? AND transdate <= ?
        UNION
        SELECT id FROM $table WHERE storno IS TRUE AND storno_id IS NOT NULL AND storno_id IN
          (SELECT id FROM $table WHERE storno IS TRUE AND storno_id IS NULL AND transdate >= ? AND transdate <= ?)
      )|;
    ($sums_canceled{$table}) = selectfirst_array_query($::form, $self->dbh, $query, $self->fromdate, $self->todate, $self->fromdate, $self->todate);

    # check storno invoices in consideration period (corresponding canceled (stornoed) invoices do not have to be in this period)
    $query = qq|
      SELECT sum(amount) FROM $table WHERE id IN (
        SELECT storno_id FROM $table WHERE storno IS TRUE AND storno_id IS NOT NULL AND transdate >= ? AND transdate <= ?
        UNION
        SELECT id FROM $table WHERE storno IS TRUE AND storno_id IS NOT NULL AND transdate >= ? AND transdate <= ?
      )|;
    ($sums_storno{$table}) = selectfirst_array_query($::form, $self->dbh, $query, $self->fromdate, $self->todate, $self->fromdate, $self->todate);

    my $text_rg = ($table eq 'ar') ? 'Verkaufsrechnungen' : 'Einkaufsrechnungen';

    $self->tester->ok($sums_canceled{$table} == 0, "Summe aller $text_rg (stornos + stornierte) soll 0 sein (für stornierte Rechnungen)");
    $self->tester->ok($sums_storno  {$table} == 0, "Summe aller $text_rg (stornos + stornierte) soll 0 sein (für Storno-Rechnungen)");
    $self->tester->diag("Summe $text_rg ($table) (für stornierte Rechnungen) : " . $sums_canceled{$table}) if $sums_canceled{$table} != 0;
    $self->tester->diag("Summe $text_rg ($table) (für Storno-Rechnungen)     : " . $sums_storno  {$table}) if $sums_storno  {$table} != 0;
  }
}

sub check_ar_paid {
  my ($self) = @_;

  my $query = qq|
      select invnumber,paid,
           (select sum(amount) from acc_trans a left join chart c on (c.id = a.chart_id) where trans_id = ar.id and c.link like '%AR_paid%') as accpaid ,
           paid+(select sum(amount) from acc_trans a left join chart c on (c.id = a.chart_id) where trans_id = ar.id and c.link like '%AR_paid%') as diff
    from ar
    where
          (select sum(amount) from acc_trans a left join chart c on (c.id = a.chart_id) where trans_id = ar.id and c.link like '%AR_paid%') is not null
            AND storno is false
      AND ar.id in (SELECT id from ar where transdate >= ? and transdate <= ?)
    order by diff |;

  my $paid_diffs_ar = selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  my $errors = scalar grep { $_->{diff} != 0 } @$paid_diffs_ar;

  $self->tester->ok(!$errors, "Vergleich ar paid mit acc_trans AR_paid");

  for my $paid_diff_ar (@{ $paid_diffs_ar }) {
    next if $paid_diff_ar->{diff} == 0;
    $self->tester->diag("ar invnumber: $paid_diff_ar->{invnumber} : paid: $paid_diff_ar->{paid}    acc_paid= $paid_diff_ar->{accpaid}    diff: $paid_diff_ar->{diff}");
  }
}

sub check_ap_paid {
  my ($self) = @_;

  my $query = qq|
      select invnumber,paid,id,
            (select sum(amount) from acc_trans a left join chart c on (c.id = a.chart_id) where trans_id = ap.id and c.link like '%AP_paid%') as accpaid ,
            paid-(select sum(amount) from acc_trans a left join chart c on (c.id = a.chart_id) where trans_id = ap.id and c.link like '%AP_paid%') as diff
     from ap
     where
           (select sum(amount) from acc_trans a left join chart c on (c.id = a.chart_id) where trans_id = ap.id and c.link like '%AP_paid%') is not null
      AND ap.id in (SELECT id from ap where transdate >= ? and transdate <= ?)
     order by diff |;

  my $paid_diffs_ap = selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  my $errors = scalar grep { $_->{diff} != 0 } @$paid_diffs_ap;

  $self->tester->ok(!$errors, "Vergleich ap paid mit acc_trans AP_paid");
  for my $paid_diff_ap (@{ $paid_diffs_ap }) {
     next if $paid_diff_ap->{diff} == 0;
     $self->tester->diag("ap invnumber: $paid_diff_ap->{invnumber} : ID :: ID :  $paid_diff_ap->{id}  : paid: $paid_diff_ap->{paid}    acc_paid= $paid_diff_ap->{accpaid}    diff: $paid_diff_ap->{diff}");
  }
}

sub check_ar_overpayments {
  my ($self) = @_;

  my $query = qq|
       select invnumber,paid,amount,transdate,c.customernumber,c.name from ar left join customer c on (ar.customer_id = c.id)
       where abs(paid) > abs(amount)
       AND transdate >= ? and transdate <= ?
       order by invnumber;|;

  my $overpaids_ar =  selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  my $correct = 0 == @$overpaids_ar;

  $self->tester->ok($correct, "Keine Überzahlungen laut ar.paid");
  for my $overpaid_ar (@{ $overpaids_ar }) {
    $self->tester->diag("ar invnumber: $overpaid_ar->{invnumber} : paid: $overpaid_ar->{paid}    amount= $overpaid_ar->{amount}  transdate = $overpaid_ar->{transdate}");
  }
}

sub check_ap_overpayments {
  my ($self) = @_;

  my $query = qq|
      select invnumber,paid,amount,transdate,vc.vendornumber,vc.name from ap left join vendor vc on (ap.vendor_id = vc.id)
      where abs(paid) > abs(amount)
      AND transdate >= ? and transdate <= ?
      order by invnumber;|;

  my $overpaids_ap =  selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  my $correct = 0 == @$overpaids_ap;

  $self->tester->ok($correct, "Überzahlungen laut ap.paid:");
  for my $overpaid_ap (@{ $overpaids_ap }) {
    $self->tester->diag("ap invnumber: $overpaid_ap->{invnumber} : paid: $overpaid_ap->{paid}    amount= $overpaid_ap->{amount}  transdate = $overpaid_ap->{transdate}");
  }
}

sub check_paid_stornos {
  my ($self) = @_;

  my $query = qq|
    SELECT ar.invnumber,sum(amount - COALESCE((SELECT sum(amount)*-1
                            FROM acc_trans LEFT JOIN chart ON (acc_trans.chart_id=chart.id)
                            WHERE link ilike '%paid%' AND acc_trans.trans_id=ar.id ),0)) as "open"
    FROM ar, customer
    WHERE paid != amount
      AND ar.storno
      AND (ar.customer_id = customer.id)
      AND ar.transdate >= ? and ar.transdate <= ?
    GROUP BY ar.invnumber|;
  my $paid_stornos = selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  $self->tester->ok(0 == @$paid_stornos, "Keine bezahlten Stornos");
  for my $paid_storno (@{ $paid_stornos }) {
    $self->tester->diag("invnumber: $paid_storno->{invnumber}   offen: $paid_storno->{open}");
  }
}

sub check_stornos_ohne_partner {
  my ($self) = @_;

  my $query = qq|
    SELECT (SELECT cast ('ar' as text)) as invoice ,ar.id,invnumber,storno,amount,transdate,type,customernumber as cv_number
    FROM ar
    LEFT JOIN customer c on (c.id = ar.customer_id)
    WHERE storno_id is null AND storno is true AND ar.id not in (SELECT storno_id FROM ar WHERE storno_id is not null AND storno is true)
    AND ar.transdate >= ? and ar.transdate <= ?
    UNION
    SELECT (SELECT cast ('ap' as text)) as invoice,ap.id,invnumber,storno,amount,transdate,type,vendornumber as cv_number
    FROM ap
    LEFT JOIN vendor v on (v.id = ap.vendor_id)
    WHERE storno_id is null AND storno is true AND ap.id not in (SELECT storno_id FROM ap WHERE storno_id is not null AND storno is true)
    AND ap.transdate >= ? and ap.transdate <= ?|;

  my $stornos_ohne_partner =  selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate,
                                                                                   $self->fromdate, $self->todate);

  $self->tester->ok(@$stornos_ohne_partner == 0, 'Es sollte keine Stornos ohne Partner geben');
  if (@$stornos_ohne_partner) {
    $self->tester->diag("Stornos ohne Partner, oder Storno über Jahreswechsel hinaus");
  }
  my $stornoheader = 0;
  for my $storno (@{ $stornos_ohne_partner }) {
    if (!$stornoheader++) {
      $self->tester->diag(join "\t", keys %$storno);
    }
    $self->tester->diag(join "\t", map { $storno->{$_} } keys %$storno);
  }
}

sub check_overpayments {
  my ($self) = @_;

  # Vergleich ar.paid und das was laut acc_trans bezahlt wurde
  # "als bezahlt markieren" ohne sauberes Ausbuchen führt zu Differenzen bei offenen Forderungen
  # Berücksichtigt Zahlungseingänge im Untersuchungszeitraums und
  # prüft weitere Zahlungen und Buchungen über trans_id (kein Zeitfilter)

  my $query = qq|
    SELECT
    invnumber,customernumber,name,ar.transdate,ar.datepaid,
    amount,
    amount-paid as "open via ar",
    paid as "paid via ar",
    coalesce((SELECT sum(amount)*-1 FROM acc_trans
      WHERE chart_link ilike '%paid%' AND acc_trans.trans_id=ar.id),0) as "paid via acc_trans"
    FROM ar left join customer c on (c.id = ar.customer_id)
    WHERE
     ar.storno IS FALSE
     AND ar.id in (SELECT trans_id from acc_trans where transdate >= ? AND transdate <= ? AND chart_link ilike '%paid%')|;

  my $invoices = selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  my $count_overpayments = scalar grep {
       $_->{"paid via ar"} != $_->{"paid via acc_trans"}
    || (    $_->{"amount"} - $_->{"paid via acc_trans"} != $_->{"open via ar"}
         && $_->{"paid via ar"} != $_->{"paid via acc_trans"} )
  } @$invoices;

  $self->tester->ok($count_overpayments == 0, 'Vergleich ar.paid und das was laut acc_trans bezahlt wurde');

  if ($count_overpayments) {
    for my $invoice (@{ $invoices }) {
      if ($invoice->{"paid via ar"} != $invoice->{"paid via acc_trans"}) {
        $self->tester->diag("Rechnung: $invoice->{invnumber}, Kunde $invoice->{name}  Nebenbuch-Bezahlwert: (@{[ $invoice->{'paid via ar'} * 1 ]}) !=   Hauptbuch-Bezahlwert:  (@{[ $invoice->{'paid via acc_trans'} * 1 ]}) (at least until transdate!)");
        if (defined $invoice->{datepaid}) {
          $self->tester->diag("datepaid = $invoice->{datepaid})");
        }
        $self->tester->diag("Überzahlung bei Rechnung: $invoice->{invnumber}") if $invoice->{"paid via acc_trans"} > $invoice->{amount};
      } elsif ( $invoice->{"amount"} - $invoice->{"paid via acc_trans"} != $invoice->{"open via ar"} && $invoice->{"paid via ar"} != $invoice->{"paid via acc_trans"}) {
        $self->tester->diag("amount - paid_via_acc_trans !=  open_via_ar");
        $self->tester->diag("Überzahlung bei Rechnung: $invoice->{invnumber}") if $invoice->{"paid via acc_trans"} > $invoice->{amount};
      } else {
        # nothing wrong
      }
    }
  }
}

sub calc_saldenvortraege {
  my ($self) = @_;

  my $saldenvortragskonto = '9000';

  # Saldo Saldenvortragskonto 9000 am Jahresanfang
  my $query = qq|
      select sum(amount) from acc_trans where chart_id = (select id from chart where accno = ?) and transdate <= ?|;
  my ($saldo_9000_jahresanfang) = selectfirst_array_query($::form, $self->dbh, $query, $saldenvortragskonto, DateTime->new(day => 1, month => 1, year => DateTime->today->year));
  $self->tester->diag("Saldo 9000 am 01.01.@{[DateTime->today->year]}: @{[ $saldo_9000_jahresanfang * 1 ]}    (sollte 0 sein)");

    # Saldo Saldenvortragskonto 9000 am Jahresende
  $query = qq|
      select sum(amount) from acc_trans where chart_id = (select id from chart where accno = ?) and transdate <= ?|;
  my ($saldo_9000_jahresende) = selectfirst_array_query($::form, $self->dbh, $query, $saldenvortragskonto, DateTime->new(day => 31, month => 12, year => DateTime->today->year));
  $self->tester->diag("Saldo $saldenvortragskonto am 31.12.@{[DateTime->today->year]}: @{[ $saldo_9000_jahresende * 1 ]}    (sollte 0 sein)");
}

sub check_every_account_with_taxkey {
  my ($self) = @_;

  my $query = qq|SELECT accno, description FROM chart WHERE id NOT IN (select chart_id from taxkeys)|;
  my $accounts_without_tk = selectall_hashref_query($::form, $self->dbh, $query);

  if ( scalar @{ $accounts_without_tk } > 0 ){
    $self->tester->ok(0, "Folgende Konten haben keinen gültigen Steuerschlüssel:");

    for my $account_without_tk (@{ $accounts_without_tk } ) {
      $self->tester->diag("Kontonummer: $account_without_tk->{accno} Beschreibung: $account_without_tk->{description}");
    }
  } else {
    $self->tester->ok(1, "Jedes Konto hat einen gültigen Steuerschlüssel!");
  }
}

sub check_ar_acc_trans_amount {
  my ($self) = @_;

  my $query = qq|
          select sum(ac.amount) as amount, ar.invnumber,ar.netamount
          from acc_trans ac left join ar on (ac.trans_id = ar.id)
          WHERE ac.chart_link like 'AR_amount%'
          AND ac.transdate >= ? AND ac.transdate <= ?
          AND ar.type       = 'invoice'
          group by invnumber,netamount having sum(ac.amount) <> ar.netamount|;

  my $ar_amount_not_ac_amount = selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  if ( scalar @{ $ar_amount_not_ac_amount } > 0 ) {
    $self->tester->ok(0, "Folgende Ausgangsrechnungen haben einen falschen Netto-Wert im Nebenbuch:");

    for my $ar_ac_amount_nok (@{ $ar_amount_not_ac_amount } ) {
      $self->tester->diag("Rechnungsnummer: $ar_ac_amount_nok->{invnumber} Hauptbuch-Wert: $ar_ac_amount_nok->{amount}
                            Nebenbuch-Wert: $ar_ac_amount_nok->{netamount}");
    }
  } else {
    $self->tester->ok(1, "Hauptbuch-Nettowert und Debitoren-Nebenbuch-Nettowert  stimmen überein.");
  }

}

sub check_ap_acc_trans_amount {
  my ($self) = @_;

  my $query = qq|
          select sum(ac.amount) as amount, ap.invnumber,ap.netamount
          from acc_trans ac left join ap on (ac.trans_id = ap.id)
          WHERE (ac.chart_link like '%AP_amount%' OR ac.chart_link like '%IC_cogs%')
          AND ac.transdate >= ? AND ac.transdate <= ?
          group by invnumber,trans_id,netamount having sum(ac.amount) <> ap.netamount*-1|;

  my $ap_amount_not_ac_amount = selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  if ( scalar @{ $ap_amount_not_ac_amount } > 0 ) {
    $self->tester->ok(0, "Folgende Eingangsrechnungen haben einen falschen Netto-Wert im Nebenbuch:");

    for my $ap_ac_amount_nok (@{ $ap_amount_not_ac_amount } ) {
      $self->tester->diag("Rechnungsnummer: $ap_ac_amount_nok->{invnumber} Hauptbuch-Wert: $ap_ac_amount_nok->{amount}
                            Nebenbuch-Wert: $ap_ac_amount_nok->{netamount}");
    }
  } else {
    $self->tester->ok(1, "Hauptbuch-Nettowert und Kreditoren-Nebenbuch-Nettowert stimmen überein.");
  }

}


sub check_missing_tax_bookings {

  my ($self) = @_;

  # check tax bookings. all taxkey <> 0 should have tax bookings in acc_trans

  my $query = qq| select trans_id, chart.accno,transdate from acc_trans left join chart on (chart.id = acc_trans.chart_id)
                    WHERE taxkey NOT IN (SELECT taxkey from tax where rate=0 OR reverse_charge_chart_id is not null) AND trans_id NOT IN
                    (select trans_id from acc_trans where chart_link ilike '%tax%' and trans_id IN
                    (SELECT trans_id from acc_trans where taxkey NOT IN (SELECT taxkey from tax where rate=0)))
                    AND transdate >= ? AND transdate <= ?|;

  my $missing_tax_bookings = selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  if ( scalar @{ $missing_tax_bookings } > 0 ) {
    $self->tester->ok(0, "Folgende Konten weisen Buchungen ohne Steuerverknüpfung auf:");

    for my $acc_trans_nok (@{ $missing_tax_bookings } ) {
      $self->tester->diag("Kontonummer: $acc_trans_nok->{accno} Belegdatum: $acc_trans_nok->{transdate} Trans-ID: $acc_trans_nok->{trans_id}.
                           Kann über System -> Korrekturen im Hauptbuch bereinigt werden. Falls es ein Zahlungskonto ist, wurde
                           ggf. ein Brutto-Skonto-Konto mit einer Netto-Rechnung verknüpft. Kann nur per SQL geändert werden.");
    }
  } else {
    $self->tester->ok(1, "Hauptbuch-Nettowert und Nebenbuch-Nettowert stimmen überein.");
  }
}

sub check_bank_transactions_overpayments {
  my ($self) = @_;

  my $query = qq|
       select id,amount,invoice_amount, purpose,transdate from bank_transactions where abs(invoice_amount) > abs(amount)
         AND transdate >= ? AND transdate <= ? order by transdate|;

  my $overpaids_bank_transactions =  selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  my $correct = 0 == @$overpaids_bank_transactions;

  $self->tester->ok($correct, "Keine überbuchte Banktransaktion (der zugeordnete Betrag ist nicht höher, als der Überweisungsbetrag).");
  for my $overpaid_bank_transaction (@{ $overpaids_bank_transactions }) {
    $self->tester->diag("Überbuchte Bankbewegung!
                         Verwendungszweck: $overpaid_bank_transaction->{purpose}
                         Transaktionsdatum: $overpaid_bank_transaction->{transdate}
                         Betrag= $overpaid_bank_transaction->{amount}  Zugeordneter Betrag = $overpaid_bank_transaction->{invoice_amount}
                         Bitte kontaktieren Sie Ihren kivitendo-DB-Admin, der die Überweisung wieder zurücksetzt (Table: bank_transactions Column: invoice_amount).");
  }
}

sub check_ar_paid_acc_trans {
  my ($self) = @_;

  my $query = qq|
          select sum(ac.amount) as paid_amount, ar.invnumber,ar.paid
          from acc_trans ac left join ar on (ac.trans_id = ar.id)
          WHERE (ac.chart_link like '%AR_paid%' OR ac.fx_transaction)
          AND ac.trans_id in (SELECT trans_id from acc_trans ac where ac.transdate >= ? AND ac.transdate <= ?)
          group by invnumber, paid having sum(ac.amount) <> ar.paid*-1|;

  my $ar_amount_not_ac_amount = selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  if ( scalar @{ $ar_amount_not_ac_amount } > 0 ) {
    $self->tester->ok(0, "Folgende Ausgangsrechnungen haben einen falschen Bezahl-Wert im Nebenbuch:");

    for my $ar_ac_amount_nok (@{ $ar_amount_not_ac_amount } ) {
      $self->tester->diag("Rechnungsnummer: $ar_ac_amount_nok->{invnumber} Hauptbuch-Wert: $ar_ac_amount_nok->{paid_amount}
                            Nebenbuch-Wert: $ar_ac_amount_nok->{paid}");
    }
  } else {
    $self->tester->ok(1, "Hauptbuch-Bezahlwert und Debitoren-Nebenbuch-Bezahlwert stimmen überein.");
  }
}

sub check_ap_paid_acc_trans {
  my ($self) = @_;

  my $query = qq|
          select sum(ac.amount) as paid_amount, ap.invnumber,ap.paid
          from acc_trans ac left join ap on (ac.trans_id = ap.id)
          WHERE ac.chart_link like '%AP_paid%'
          AND ac.trans_id in (SELECT trans_id from acc_trans ac where ac.transdate >= ? AND ac.transdate <= ?)
          group by trans_id,invnumber,paid having sum(ac.amount) <> ap.paid|;

  my $ap_amount_not_ac_amount = selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  if ( scalar @{ $ap_amount_not_ac_amount } > 0 ) {
    $self->tester->ok(0, "Folgende Eingangsrechnungen haben einen falschen Bezahl-Wert im Nebenbuch:");

    for my $ap_ac_amount_nok (@{ $ap_amount_not_ac_amount } ) {
      $self->tester->diag("Rechnungsnummer: $ap_ac_amount_nok->{invnumber} Hauptbuch-Wert: $ap_ac_amount_nok->{paid_amount}
                            Nebenbuch-Wert: $ap_ac_amount_nok->{paid}");
    }
  } else {
    $self->tester->ok(1, "Hauptbuch Bezahl-Wert und Kreditoren-Nebenbuch-Bezahlwert stimmen überein.");
  }
}

sub check_zero_amount_paid_but_datepaid_exists {
  my ($self) = @_;

  my $query = qq|(SELECT invnumber,datepaid from ar where datepaid is NOT NULL AND paid = 0
                    AND id not IN (select trans_id from acc_trans WHERE chart_link like '%paid%' AND acc_trans.trans_id = ar.id)
                    AND datepaid >= ? AND datepaid <= ?)
                  UNION
                 (SELECT invnumber,datepaid from ap where datepaid is NOT NULL AND paid = 0
                    AND id not IN (select trans_id from acc_trans WHERE chart_link like '%paid%' AND acc_trans.trans_id = ap.id)
                    AND datepaid >= ? AND datepaid <= ?)|;

  my $datepaid_should_be_null = selectall_hashref_query($::form, $self->dbh, $query,
                                                         $self->fromdate, $self->todate,
                                                         $self->fromdate, $self->todate);

  if ( scalar @{ $datepaid_should_be_null } > 0 ) {
    $self->tester->ok(0, "Folgende Rechnungen haben ein Bezahl-Datum, aber keinen Bezahl-Wert im Nebenbuch:");

    for my $datepaid_should_be_null_nok (@{ $datepaid_should_be_null } ) {
      $self->tester->diag("Rechnungsnummer: $datepaid_should_be_null_nok->{invnumber}
                           Bezahl-Datum: $datepaid_should_be_null_nok->{datepaid}");
    }
  } else {
    $self->tester->ok(1, "Kein Bezahl-Datum ohne Bezahl-Wert und ohne wirkliche Zahlungen gefunden (arap.datepaid, arap.paid konsistent).");
  }
}

sub check_orphaned_reconciliated_links {
  my ($self) = @_;

  my $query = qq|
          SELECT id, purpose from bank_transactions
          WHERE cleared is true
          AND NOT EXISTS (SELECT bank_transaction_id from reconciliation_links WHERE bank_transaction_id = bank_transactions.id)
          AND transdate >= ? AND transdate <= ?|;

  my $bt_cleared_no_link = selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  if ( scalar @{ $bt_cleared_no_link } > 0 ) {
    $self->tester->ok(0, "Verwaiste abgeglichene Bankbewegungen gefunden. Bei folgenden Bankbewegungen ist die abgleichende Verknüpfung gelöscht worden:");

    for my $bt_orphaned (@{ $bt_cleared_no_link }) {
      $self->tester->diag("ID: $bt_orphaned->{id} Verwendungszweck: $bt_orphaned->{purpose}");
    }
  } else {
    $self->tester->ok(1, "Keine verwaisten Einträge in abgeglichenen Bankbewegungen.");
  }
}

sub check_recommended_client_settings {
  my ($self) = @_;

  my $all_ok = 1;

  # expand: check datev && check mark_as_paid
  my %settings_values_nok = (
                              SL::DB::Default->get->is_changeable => 1,
                              SL::DB::Default->get->ar_changeable => 1,
                              SL::DB::Default->get->ap_changeable => 1,
                              SL::DB::Default->get->ir_changeable => 1,
                              SL::DB::Default->get->gl_changeable => 1,
                             );

  foreach (keys %settings_values_nok) {
    if ($_ == $settings_values_nok{$_}) {
      $self->tester->ok(0, "Buchungskonfiguration: Mindestens ein Belegtyp ist immer änderbar.");
      undef $all_ok;
    }
  }

  # payments more strict (avoid losing payments acc_trans_ids)
  my $payments_ok = SL::DB::Default->get->payments_changeable == 0 ? 1 : 0;
  $self->tester->ok(0, "Manuelle Zahlungen sind zu lange änderbar (Empfehlung: niemals).") unless $payments_ok;

  $self->tester->ok(1, "Mandantenkonfiguration optimal eingestellt.") if ($payments_ok && $all_ok);
}

sub check_orphaned_bank_transaction_acc_trans_links {
  my ($self) = @_;

  my $query = qq|
          SELECT id, purpose from bank_transactions
          WHERE invoice_amount <> 0
          AND NOT EXISTS (SELECT bank_transaction_id FROM bank_transaction_acc_trans WHERE bank_transaction_id = bank_transactions.id)
          AND itime > (SELECT min(itime) from bank_transaction_acc_trans)
          AND transdate >= ? AND transdate <= ?|;

  my $bt_assigned_no_link = selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  if ( scalar @{ $bt_assigned_no_link } > 0 ) {
    $self->tester->ok(0, "Verwaiste Verknüpfungen zu Bankbewegungen gefunden. Bei folgenden Bankbewegungen ist eine interne Verknüpfung gelöscht worden:");

    for my $bt_orphaned (@{ $bt_assigned_no_link }) {
      $self->tester->diag("ID: $bt_orphaned->{id} Verwendungszweck: $bt_orphaned->{purpose}");
    }
  } else {
    $self->tester->ok(1, "Keine verwaisten Einträge in verknüpften Bankbewegungen (Richtung Bank).");
  }
  # check for deleted acc_trans_ids
  $query = qq|
          SELECT purpose from bank_transactions
          WHERE id in
          (SELECT bank_transaction_id from bank_transaction_acc_trans
           WHERE NOT EXISTS (SELECT acc_trans.acc_trans_id FROM acc_trans WHERE acc_trans.acc_trans_id = bank_transaction_acc_trans.acc_trans_id)
           AND transdate >= ? AND transdate <= ?)|;

  my $bt_assigned_no_acc_trans = selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  if ( scalar @{ $bt_assigned_no_acc_trans } > 0 ) {
    $self->tester->ok(0, "Verwaiste Verknüpfungen zu Bankbewegungen gefunden. Bei folgenden Bankbewegungen ist eine interne Verknüpfung gelöscht worden:");

    for my $bt_orphaned (@{ $bt_assigned_no_acc_trans }) {
      $self->tester->diag("Verwendungszweck: $bt_orphaned->{purpose}");
    }
  } else {
    $self->tester->ok(1, "Keine verwaisten Einträge in verknüpften Bankbewegungen (Richtung Buchung (Richtung Buchung)).");
  }
}

sub check_consistent_itimes {
  my ($self) = @_;
  my $query;

  $query = qq|
    SELECT mtime, itime,gldate, acc_trans_id, trans_id
    FROM  acc_trans a
    WHERE itime::date <> gldate::date
    AND a.transdate >= ? and a.transdate <= ?|;

  my $itimes_ac = selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  if ( scalar @{ $itimes_ac } > 0 ) {
    $self->tester->ok(0, "Inkonsistente Zeitstempel in der acc_trans gefunden. Bei folgenden ids:");
    for my $bogus_time (@{ $itimes_ac }) {
      $self->tester->diag("ID: $bogus_time->{trans_id} acc_trans_id: $bogus_time->{acc_trans_id} ");
    }
  } else {
    $self->tester->ok(1, "Keine inkonsistenten Zeitstempel in der acc_trans.");
  }
  $query = qq|
    SELECT amount, itime, gldate, id
    FROM ap a
    WHERE itime::date <> gldate::date
    AND a.transdate >= ? and a.transdate <= ?|;

  my $itimes_ap = selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  if ( scalar @{ $itimes_ap } > 0 ) {
    $self->tester->ok(0, "Inkonsistente Zeitstempel in ap gefunden. Bei folgenden ids:");
    for my $bogus_time (@{ $itimes_ap }) {
      $self->tester->diag("ID: $bogus_time->{id} itime: $bogus_time->{itime} mtime: $bogus_time->{mtime} ");
    }
  } else {
    $self->tester->ok(1, "Keine inkonsistenten Zeitstempel in ap.");
  }
  $query = qq|
    SELECT amount, itime, gldate, id
    FROM ar a
    WHERE itime::date <> gldate::date
    AND a.transdate >= ? and a.transdate <= ?|;

  my $itimes_ar = selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  if ( scalar @{ $itimes_ap } > 0 ) {
    $self->tester->ok(0, "Inkonsistente Zeitstempel in ar gefunden. Bei folgenden ids:");
    for my $bogus_time (@{ $itimes_ar }) {
      $self->tester->diag("ID: $bogus_time->{id} itime: $bogus_time->{itime} mtime: $bogus_time->{mtime} ");
    }
  } else {
    $self->tester->ok(1, "Keine inkonsistenten Zeitstempel in ar.");
  }
  $query = qq|
    SELECT itime, gldate, id, mtime
    FROM gl a
    WHERE itime::date <> gldate::date
    AND a.transdate >= ? and a.transdate <= ?|;

  my $itimes_gl = selectall_hashref_query($::form, $self->dbh, $query, $self->fromdate, $self->todate);

  if ( scalar @{ $itimes_gl } > 0 ) {
    $self->tester->ok(0, "Inkonsistente Zeitstempel in gl gefunden. Bei folgenden ids:");
    for my $bogus_time (@{ $itimes_ar }) {
      $self->tester->diag("ID: $bogus_time->{id} itime: $bogus_time->{itime} mtime: $bogus_time->{mtime} ");
    }
  } else {
    $self->tester->ok(1, "Keine inkonsistenten Zeitstempel in gl.");
  }
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::BackgroundJob::SelfTest::Transactions - base tests

=head1 DESCRIPTION

Several tests for data integrity.

=head1 AUTHOR

G. Richardson E<lt>information@richardson-bueren.deE<gt>
Jan Büren E<lt>information@richardson-bueren.deE<gt>
Sven Schoeling E<lt>s.schoeling@linet-services.deE<gt>

=cut
