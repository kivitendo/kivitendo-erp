package SL::SEPA;

use strict;

use IPC::Run qw();
use POSIX qw(strftime);

use Data::Dumper;
use SL::DBUtils;
use SL::DB::Invoice;
use SL::DB::SepaExportsAccTrans;
use SL::DB::PurchaseInvoice;
use SL::DB;
use SL::Locale::String qw(t8);
use DateTime;
use Carp;
use List::Util qw(sum);

sub retrieve_open_invoices {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);
  my $arap     = $params{vc} eq 'customer' ? 'ar'       : 'ap';
  my $vc       = $params{vc} eq 'customer' ? 'customer' : 'vendor';
  my $vc_vc_id = $params{vc} eq 'customer' ? 'c_vendor_id' : 'v_customer_id';

  my $mandate  = $params{vc} eq 'customer' ? " AND COALESCE(vc.mandator_id, '') <> '' AND vc.mandate_date_of_signature IS NOT NULL " : '';
  my $is_sepa_blocked = $params{vc} eq 'customer' ? 'FALSE' : "${arap}.is_sepa_blocked";
  my $only_approved   = $params{payment_approval} ? ' AND ap.id IN (SELECT ap_id from payment_approved) ' : undef;

  # has to be ON and don't edit payments manually (UNDO SEPA Export if needed at all)
  my $p_credit_notes  = $params{vc} eq 'vendor' && $::instance_conf->get_sepa_subtract_credit_notes
                                                && SL::DB::Default->get->payments_changeable == 0
                        ? " OR (${arap}.amount < 0 AND ${arap}.amount <> ${arap}.paid) " : undef;

  # open_amount is not the current open amount according to bookkeeping, but
  # the open amount minus the SEPA transfer amounts that haven't been closed yet
  my $query =
    qq|
       SELECT ${arap}.id, ${arap}.invnumber, ${arap}.transdate, ${arap}.${vc}_id as vc_id, ${arap}.amount AS invoice_amount, ${arap}.invoice,
         (${arap}.transdate + pt.terms_skonto) as skonto_date, (pt.percent_skonto * 100) as percent_skonto,
         (${arap}.amount - (${arap}.amount * pt.percent_skonto)) as amount_less_skonto,
         (${arap}.amount * pt.percent_skonto) as skonto_amount,
         vc.name AS vcname, vc.language_id, ${arap}.duedate as duedate, ${arap}.direct_debit,
         ${is_sepa_blocked} AS is_sepa_blocked,
         vc.${vc_vc_id} as vc_vc_id,

         COALESCE(vc.iban, '') <> '' AND COALESCE(vc.bic, '') <> '' ${mandate} AS vc_bank_info_ok,

         ${arap}.amount - ${arap}.paid - COALESCE(open_transfers.amount, 0) AS open_amount,
         COALESCE(open_transfers.amount, 0) AS transfer_amount,
         pt.description as pt_description,
         (current_date < (${arap}.transdate + pt.terms_skonto)) as within_skonto_period
       FROM ${arap}
       LEFT JOIN ${vc} vc ON (${arap}.${vc}_id = vc.id)
       LEFT JOIN (SELECT sei.${arap}_id, SUM(sei.amount) + SUM(COALESCE(sei.skonto_amount,0)) AS amount
                  FROM sepa_export_items sei
                  LEFT JOIN sepa_export se ON (sei.sepa_export_id = se.id)
                  WHERE NOT se.closed
                    AND (se.vc = '${vc}')
                  GROUP BY sei.${arap}_id)
         AS open_transfers ON (${arap}.id = open_transfers.${arap}_id)

       LEFT JOIN payment_terms pt ON (${arap}.payment_id = pt.id)

       WHERE (  (${arap}.amount - (COALESCE(open_transfers.amount, 0) + ${arap}.paid)) >= 0.01
                $p_credit_notes
             )
       $only_approved
       ORDER BY lower(vc.name) ASC, lower(${arap}.invnumber) ASC
|;
    #  $main::lxdebug->message(LXDebug->DEBUG2(),"sepa add query:".$query);

  my $results = selectall_hashref_query($form, $dbh, $query);

  # add some more data to $results:
  # create drop-down data for payment types and suggest amount to be paid according
  # to open amount or skonto
  # One minor fault: amount_less_skonto does not subtract the not yet booked sepa transfer amounts

  foreach my $result ( @$results ) {
    my   @options;
    push @options, { payment_type => 'without_skonto',  display => t8('without skonto') };
    push @options, { payment_type => 'with_skonto_pt',  display => t8('with skonto acc. to pt'), selected => 1 } if $result->{within_skonto_period};
    $result->{payment_select_options}  = \@options;
  }

  $main::lxdebug->leave_sub();

  return $results;
}

sub create_export {
  my ($self, %params) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_create_export, $self, %params);

  $::lxdebug->leave_sub;
  return $rc;
}

sub _create_export {
  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(employee bank_transfers vc));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;
  my $arap     = $params{vc} eq 'customer' ? 'ar'       : 'ap';
  my $vc       = $params{vc} eq 'customer' ? 'customer' : 'vendor';
  my $ARAP     = uc $arap;

  my $dbh      = $params{dbh} || SL::DB->client->dbh;

  my ($export_id) = selectfirst_array_query($form, $dbh, qq|SELECT nextval('sepa_export_id_seq')|);
  my $query       =
    qq|INSERT INTO sepa_export (id, employee_id, vc)
       VALUES (?, (SELECT id
                   FROM employee
                   WHERE login = ?), ?)|;
  do_query($form, $dbh, $query, $export_id, $params{employee}, $vc);

  my $q_item_id = qq|SELECT nextval('id')|;
  my $h_item_id = prepare_query($form, $dbh, $q_item_id);
  my $c_mandate = $params{vc} eq 'customer' ? ', vc_mandator_id, vc_mandate_date_of_signature' : '';
  my $p_mandate = $params{vc} eq 'customer' ? ', ?, ?' : '';

  my $q_insert =
    qq|INSERT INTO sepa_export_items (id,          sepa_export_id,           ${arap}_id,  chart_id,
                                      amount,      requested_execution_date, reference,   end_to_end_id,
                                      our_iban,    our_bic,                  vc_iban,     vc_bic,
                                      skonto_amount, payment_type ${c_mandate},
                                      collected_payment, is_combined_payment, ${vc}_id                )
       VALUES                        (?,           ?,                        ?,           ?,
                                      ?,           ?,                        ?,           ?,
                                      ?,           ?,                        ?,           ?,
                                      ?,           ? ${p_mandate},
                                      ?,           ?,                        ?                        )|;
  my $h_insert = prepare_query($form, $dbh, $q_insert);

  my $q_reference =
    qq|SELECT arap.invnumber,
         (SELECT COUNT(at.*)
          FROM acc_trans at
          LEFT JOIN chart c ON (at.chart_id = c.id)
          WHERE (at.trans_id = ?)
            AND (c.link LIKE '%${ARAP}_paid%'))
         +
         (SELECT COUNT(sei.*)
          FROM sepa_export_items sei
          WHERE (sei.ap_id = ?))
         AS num_payments
       FROM ${arap} arap
       WHERE id = ?|;
  my $h_reference = prepare_query($form, $dbh, $q_reference);

  # toter code
  # my @now         = localtime;

  # if collective bank transfers, distinct end to end id for all transactions and no payment type
  # and no reference to an invoice, but to a vendor_id
  my %vc_id_end_to_end;
  foreach my $transfer (@{ $params{collective_bank_transfers} }) {

    die "Invalid state, need a valid combined payment reference" unless $transfer->{reference}; # catch for h_reference

    $vc_id_end_to_end{$transfer->{vc_id}} = strftime "KIVITENDOSUPERMONIKA%Y%m%d%H%M%S", localtime;
    $transfer->{is_combined_payment}      = 1;
    $transfer->{payment_type}             = 'without_skonto';
  }
  # sum all credit notes for vc_id for later subtraction
  my %vc_cn_amount;
  foreach my $transfer (@{ $params{bank_transfers} }) {
    next unless $transfer->{credit_note};
    $vc_cn_amount{$transfer->{vc_id}} += $transfer->{amount};
  }
  foreach my $transfer (@{ $params{bank_transfers} }, @{ $params{collective_bank_transfers} }) {

    # credit note amount is negative
    if ($transfer->{credit_note} || $vc_cn_amount{$transfer->{vc_id}} < 0) {
      my %params = (transfer => $transfer, sepa_export_id => $export_id);
      $self->_check_and_book_credit_note(transfer => $transfer, sepa_export_id => $export_id, current_credit_note_amount => $vc_cn_amount{$transfer->{vc_id}});
      $vc_cn_amount{$transfer->{vc_id}} += $transfer->{amount} unless $transfer->{credit_note};
      next;
    }
    if (!$transfer->{reference}) {
      do_statement($form, $h_reference, $q_reference, (conv_i($transfer->{"${arap}_id"})) x 3);

      my ($invnumber, $num_payments) = $h_reference->fetchrow_array();
      $num_payments++;

      $transfer->{reference} = "${invnumber}-${num_payments}";
    }

    $h_item_id->execute() || $::form->dberror($q_item_id);
    my ($item_id)      = $h_item_id->fetchrow_array();

    my $end_to_end_id  =  $transfer->{collected_payment} || $transfer->{is_combined_payment}
                         ? $vc_id_end_to_end{$transfer->{vc_id}}
                         : strftime "KIVITENDO%Y%m%d%H%M%S", localtime;
    my $item_id_len    = length "$item_id";
    my $num_zeroes     = 35 - $item_id_len - length $end_to_end_id;
    $end_to_end_id    .= '0' x $num_zeroes if (0 < $num_zeroes);
    $end_to_end_id    .= $item_id;
    $end_to_end_id     = substr $end_to_end_id, 0, 35;

    my @values = ($item_id,                          $export_id,
                  conv_i($transfer->{"${arap}_id"}), conv_i($transfer->{chart_id}),
                  $transfer->{amount},               conv_date($transfer->{requested_execution_date}),
                  $transfer->{reference},            $end_to_end_id,
                  map { my $pfx = $_; map { $transfer->{"${pfx}_${_}"} } qw(iban bic) } qw(our vc));
    # save value of skonto_amount and payment_type
    if ( $transfer->{payment_type} eq 'without_skonto' ) {
      push(@values, 0);
    } elsif ($transfer->{payment_type} eq 'difference_as_skonto' ) {
      push(@values, $transfer->{amount});
    } elsif ($transfer->{payment_type} eq 'with_skonto_pt' ) {
      push(@values, $transfer->{skonto_amount});
    } else {
      die "illegal payment_type: " . $transfer->{payment_type} . "\n";
    };
    push(@values, $transfer->{payment_type});

    push @values, $transfer->{vc_mandator_id}, conv_date($transfer->{vc_mandate_date_of_signature}) if $params{vc} eq 'customer';

    push @values, $transfer->{collected_payment}   ? 1 : 0;
    push @values, $transfer->{is_combined_payment} ? 1 : 0;
    push @values, $transfer->{vc_id};

    do_statement($form, $h_insert, $q_insert, @values);
  }

  $h_insert->finish();
  $h_item_id->finish();

  return $export_id;
}

# TODO allow credit_notes higher amount than invoice amount AND skonto bookings (see Payment-Helper _skonto..)
sub _check_and_book_credit_note {
  my $self     = shift;
  my %params   = @_;
  Common::check_params(\%params, qw(transfer sepa_export_id current_credit_note_amount));
  my $transfer = delete $params{transfer};
  my $current_credit_note_amount = $params{current_credit_note_amount};

  die "Need ap_id, amount from transfer" unless $transfer->{ap_id} && $transfer->{amount};

  my $amount         =  $transfer->{credit_note} ? $transfer->{amount}   # full amount for credit notes
                      : abs($current_credit_note_amount) <= $transfer->{amount} ? $current_credit_note_amount
                      : $transfer->{amount};

  $amount            = abs($amount);
  #my $mc = Math::Currency->new( $amount );
  my $transdate      = DateTime->now();
  my $sepa_export_id = $params{sepa_export_id};

  my $transit_chart = SL::DB::Manager::Chart->find_by(id => SL::DB::Default->get->transit_items_chart_id);
  my $invoice       = SL::DB::Manager::PurchaseInvoice->find_by(id => $transfer->{ap_id});

  # sanity checks
  die "Invalid state, expected a credit note" if $transfer->{credit_note} && $invoice->invoice_type !~ m/credit_note/;
  die "Not a valid Chart account"             unless ref $transit_chart eq 'SL::DB::Chart';

  # acc_trans logic chart_links
  #     credit_notes          | purchase_credit_note
  #  -1397.11000 | AR         |     504.74000 |  AP
  #   1397.11000 | AR_paid    |    -504.74000 |  AP_paid
  #   purchase_invoice        | sales_invoice
  #   -100       | AP         |   100         | AR
  #   100        | AP_paid    |  -100         | AR_paid

  my $mult = $invoice->is_sales ? -1 : 1; # multiplier for getting the sign right if no credit note is involved
  $mult =  1 if ( $invoice->is_sales && $invoice->type eq 'credit_note');
  $mult = -1 if (!$invoice->is_sales && $invoice->invoice_type eq 'purchase_credit_note');

  my $paid_sign  = $invoice->invoice_type =~ m/credit_note/ ? -1 :  1;  # arap.paid is always negative for credit_note
  my @new_acc_ids;
  # positive for purchase invoice and sales credit note
  my $new_acc_trans = SL::DB::AccTransaction->new(trans_id   => $invoice->id,
                                                  chart_id   => $transit_chart->id,
                                                  chart_link => $transit_chart->link,
                                                  amount     => abs($amount) * $mult,
                                                  transdate  => $transdate,
                                                  source     => $invoice->invnumber, # $is_credit_note ?  $invoice_no : $credit_note_no,
                                                  memo       => t8('Automatically assigned with SEPA Export: #1', $sepa_export_id),
                                                  taxkey     => 0,
                                                  tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 0)->id);
  # positive for purchase credit note and sales invoice
  my $arap_booking= SL::DB::AccTransaction->new(trans_id   => $invoice->id,
                                                chart_id   => $invoice->reference_account->id,
                                                chart_link => $invoice->reference_account->link,
                                                amount     => abs($amount) * $mult * -1,
                                                transdate  => $transdate,
                                                source     => '',
                                                taxkey     => 0,
                                                tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 0)->id);
  $new_acc_trans->save;
  $arap_booking->save;

  push @new_acc_ids, $new_acc_trans->acc_trans_id;
  push @new_acc_ids, $arap_booking->acc_trans_id;


  if ($transfer->{payment_type} ne 'without_skonto' && $transfer->{skonto_amount}) {
    my @skonto_bookings = $invoice->_skonto_charts_and_tax_correction(sepa_export_id => $sepa_export_id,
                                                                      amount         => abs($transfer->{skonto_amount}),
                                                                      transdate_obj  => $transdate);
    $amount += abs($transfer->{skonto_amount});
    # create an acc_trans entry for each result of $self->skonto_charts
    foreach my $skonto_booking ( @skonto_bookings ) {
      next unless $skonto_booking->{'chart_id'};
      next unless $skonto_booking->{'skonto_amount'} != 0;
      my $skonto_amount = $skonto_booking->{skonto_amount};
      $new_acc_trans = SL::DB::AccTransaction->new(trans_id   => $invoice->id,
                                                   chart_id   => $skonto_booking->{'chart_id'},
                                                   chart_link => SL::DB::Manager::Chart->find_by(id => $skonto_booking->{'chart_id'})->link,
                                                   amount     => $skonto_amount * $mult,
                                                   transdate  => $transdate,
                                                   source     => $params{source},
                                                   taxkey     => 0,
                                                   tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 0)->id);

      $new_acc_trans->save;
      push @new_acc_ids, $new_acc_trans->acc_trans_id;
      $arap_booking= SL::DB::AccTransaction->new(trans_id   => $invoice->id,
                                                 chart_id   => $invoice->reference_account->id,
                                                 chart_link => $invoice->reference_account->link,
                                                 amount     => $skonto_amount * $mult * -1,
                                                 transdate  => $transdate,
                                                 source     => '', #$params{source},
                                                 taxkey     => 0,
                                                 tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 0)->id);
      $arap_booking->save;
      push @new_acc_ids, $arap_booking->acc_trans_id;
    }
  }
  # only one time update paid amount + skonto_amount
  $invoice->update_attributes(paid => $invoice->paid + _round((abs($amount) * $paid_sign)), datepaid => $transdate);

  # link both acc_trans transactions and maybe skonto booking acc_trans_ids
  my $id_type = $invoice->is_sales ? 'ar_id' : 'ap_id';

  foreach my $acc_trans_id (@new_acc_ids) {
    my  %props_acc = (
                       acc_trans_id    => $acc_trans_id,
                       sepa_exports_id => $sepa_export_id,
                       $id_type        => $invoice->id,
                     );
    SL::DB::SepaExportsAccTrans->new(%props_acc)->save || die $@;
  }

  # Record a record link from the sepa export to the invoice
  my %props = (
      from_table => 'sepa_export',
      from_id    => $sepa_export_id,
      to_table   => $id_type,
      to_id      => $invoice->id,
  );
  SL::DB::RecordLink->new(%props)->save;

  return;
}

sub retrieve_export {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(id vc));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;
  my $vc       = $params{vc} eq 'customer' ? 'customer' : 'vendor';
  my $arap     = $params{vc} eq 'customer' ? 'ar'       : 'ap';

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  # TOTER Code?
  #my ($joins, $columns);

  #if ($params{details}) {
  #  $columns = ', arap.invoice';
  #  $joins   = "LEFT JOIN ${arap} arap ON (se.${arap}_id = arap.id)";
  #}

  my $query =
    qq|SELECT se.*,
         CASE WHEN COALESCE(e.name, '') <> '' THEN e.name ELSE e.login END AS employee
       FROM sepa_export se
       LEFT JOIN employee e ON (se.employee_id = e.id)
       WHERE se.id = ?|;

  my $export = selectfirst_hashref_query($form, $dbh, $query, conv_i($params{id}));

  if ($export->{id}) {
    my ($columns, $joins);

    my $mandator_id = $params{vc} eq 'customer' ? ', mandator_id, mandate_date_of_signature' : '';

    if ($params{details}) {
      $columns = qq|, arap.invnumber, arap.invoice, arap.transdate AS reference_date, vc.name AS vc_name, vc.${vc}number AS vc_number, c.accno AS chart_accno, c.description AS chart_description ${mandator_id}|;
      $joins   = qq|LEFT JOIN ${arap} arap ON (sei.${arap}_id = arap.id)
                    LEFT JOIN ${vc} vc     ON (sei.${vc}_id   = vc.id)
                    LEFT JOIN chart c      ON (sei.chart_id   = c.id)|;
    }

    $query = qq|SELECT sei.*
                  $columns
                FROM sepa_export_items sei
                $joins
                WHERE sei.sepa_export_id = ?
                ORDER BY sei.id|;

    $export->{items} = selectall_hashref_query($form, $dbh, $query, conv_i($params{id}));

  } else {
    $export->{items} = [];
  }

  $main::lxdebug->leave_sub();

  return $export;
}

sub close_export {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(id));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  SL::DB->client->with_transaction(sub {
    my $dbh      = $params{dbh} || SL::DB->client->dbh;

    my @ids          = ref $params{id} eq 'ARRAY' ? @{ $params{id} } : ($params{id});
    my $placeholders = join ', ', ('?') x scalar @ids;
    my $query        = qq|UPDATE sepa_export SET closed = TRUE WHERE id IN ($placeholders)|;

    do_query($form, $dbh, $query, map { conv_i($_) } @ids);
    1;
  }) or do { die SL::DB->client->error };

  $main::lxdebug->leave_sub();
}

sub undo_export {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(id));

  my $sepa_export = SL::DB::Manager::SepaExport->find_by(id => $params{id});

  croak "Not a valid SEPA Export id: $params{id}" unless $sepa_export;
  croak "Cannot undo closed exports."             if $sepa_export->closed;
  croak "Cannot undo executed exports."           if $sepa_export->executed;
  # everything in one transaction
  my $rez = $sepa_export->db->with_transaction(sub {

    # check if we have combined sepa exports
    my %trans_ids;
    foreach my $sepa_acc_trans (@{ $sepa_export->find_sepa_exports_acc_trans }) {
      # save trans_id and type
      die "no type" unless ($sepa_acc_trans->ar_id || $sepa_acc_trans->ap_id || $sepa_acc_trans->gl_id);
      my $acc_trans = SL::DB::Manager::AccTransaction->get_all(where => [acc_trans_id => $sepa_acc_trans->acc_trans_id]);
      $trans_ids{$sepa_acc_trans->ar_id} = 'ar' if $sepa_acc_trans->ar_id;
      $trans_ids{$sepa_acc_trans->ap_id} = 'ap' if $sepa_acc_trans->ap_id;
      $trans_ids{$sepa_acc_trans->gl_id} = 'gl' if $sepa_acc_trans->gl_id;
      # 2. all good -> ready to delete acc_trans and connection table
      $sepa_acc_trans->delete;
      $_->delete for @{ $acc_trans };
    }
    # 3. update arap.paid (may not be 0, yet)
    #    or in case of gl, delete whole entry
    while (my ($trans_id, $type) = each %trans_ids) {
      if ($type eq 'gl') {
        SL::DB::Manager::GLTransaction->delete_all(where => [ id => $trans_id ]);
        next;
      }
      die ("invalid type") unless $type =~ m/^(ar|ap)$/;

      # recalc and set paid via database query
      my $query = qq|UPDATE $type SET paid =
                      (SELECT COALESCE(abs(sum(amount)),0) FROM acc_trans
                       WHERE trans_id = ?
                       AND (chart_link ilike '%paid%'
                            OR chart_id IN (SELECT fxgain_accno_id from defaults)
                            OR chart_id IN (SELECT fxloss_accno_id from defaults)
                           )
                      )
                      WHERE id = ?|;

      die if (do_query($::form, $sepa_export->db->dbh, $query, $trans_id, $trans_id) == -1);

      # undo datepaid if no payment exists
      $query = qq|UPDATE $type SET datepaid = null WHERE ID = ? AND paid = 0|;
      die if (do_query($::form, $sepa_export->db->dbh, $query, $trans_id) == -1);
    }
    # 4. and delete all (if any) record links
    my $rl = SL::DB::Manager::RecordLink->delete_all(where => [ from_id => $sepa_export->id, from_table => 'sepa_export' ]);

    # 5. finally reset  this sepa export
    die "Could not undo $sepa_export->id" if !$sepa_export->delete();
    # 6. and add a log entry in history_erp
    SL::DB::History->new(
      trans_id    => $params{id},
      snumbers    => 'sepa_export_unlink_' . $params{id},
      employee_id => SL::DB::Manager::Employee->current->id,
      what_done   => 'sepa_export',
      addition    => 'UNLINKED',
    )->save();

    1;

  }) || die t8('error while unlinking sepa export #1 : ', $sepa_export->id) . $sepa_export->db->error . "\n";


  $main::lxdebug->leave_sub();
}

sub list_exports {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;
  my $vc       = $params{vc} eq 'customer' ? 'customer' : 'vendor';
  my $arap     = $params{vc} eq 'customer' ? 'ar'       : 'ap';

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my %sort_columns = (
    'id'          => [ 'se.id',                ],
    'export_date' => [ 'se.itime',             ],
    'employee'    => [ 'e.name',      'se.id', ],
    'executed'    => [ 'se.executed', 'se.id', ],
    'closed'      => [ 'se.closed',   'se.id', ],
    );

  my %sort_spec = create_sort_spec('defs' => \%sort_columns, 'default' => 'id', 'column' => $params{sortorder}, 'dir' => $params{sortdir});

  my (@where, @values, @where_sub, @values_sub, %joins_sub);

  my $filter = $params{filter} || { };

  foreach (qw(executed closed)) {
    push @where, $filter->{$_} ? "se.$_" : "NOT se.$_" if (exists $filter->{$_});
  }

  my %operators = ('from' => '>=',
                   'to'   => '<=');

  foreach my $dir (qw(from to)) {
    next unless ($filter->{"export_date_${dir}"});
    push @where,  "se.itime $operators{$dir} ?::date";
    push @values, $filter->{"export_date_${dir}"};
  }

  if ($filter->{invnumber}) {
    push @where_sub,  "arap.invnumber ILIKE ?";
    push @values_sub, like($filter->{invnumber});
    $joins_sub{$arap} = 1;
  }

  if ($filter->{message_id}) {
    push @values, like($filter->{message_id});
    push @where,  <<SQL;
      se.id IN (
        SELECT sepa_export_id
        FROM sepa_export_message_ids
        WHERE message_id ILIKE ?
      )
SQL
  }

  if ($filter->{vc}) {
    push @where_sub,  "vc.name ILIKE ?";
    push @values_sub, like($filter->{vc});
    $joins_sub{$arap} = 1;
    $joins_sub{vc}    = 1;
  }

  foreach my $type (qw(requested_execution execution)) {
    foreach my $dir (qw(from to)) {
      next unless ($filter->{"${type}_date_${dir}"});
      push @where_sub,  "(items.${type}_date IS NOT NULL) AND (items.${type}_date $operators{$dir} ?)";
      push @values_sub, $filter->{"${type}_date_${_}"};
    }
  }

  if (@where_sub) {
    my $joins_sub  = '';
    $joins_sub    .= " LEFT JOIN ${arap} arap ON (items.${arap}_id = arap.id)" if ($joins_sub{$arap});
    $joins_sub    .= " LEFT JOIN ${vc} vc      ON (arap.${vc}_id   = vc.id)"   if ($joins_sub{vc});

    my $where_sub  = join(' AND ', map { "(${_})" } @where_sub);

    my $query_sub  = qq|se.id IN (SELECT items.sepa_export_id
                                  FROM sepa_export_items items
                                  $joins_sub
                                  WHERE $where_sub)|;

    push @where,  $query_sub;
    push @values, @values_sub;
  }

  push @where,  'se.vc = ?';
  push @values, $vc;

  my $where = @where ? ' WHERE ' . join(' AND ', map { "(${_})" } @where) : '';

  my $query =
    qq|SELECT se.id, se.employee_id, se.executed, se.closed, itime::date AS export_date,
         (SELECT COUNT(*)
          FROM sepa_export_items sei
          WHERE (sei.sepa_export_id = se.id)) AS num_invoices,
         (SELECT SUM(sei.amount)
          FROM sepa_export_items sei
          WHERE (sei.sepa_export_id = se.id)) AS sum_amounts,
         (SELECT string_agg(semi.message_id, ', ')
          FROM sepa_export_message_ids semi
          WHERE semi.sepa_export_id = se.id) AS message_ids,
         e.name AS employee
       FROM sepa_export se
       LEFT JOIN (
         SELECT emp.id,
           CASE WHEN COALESCE(emp.name, '') <> '' THEN emp.name ELSE emp.login END AS name
         FROM employee emp
       ) AS e ON (se.employee_id = e.id)
       $where
       ORDER BY $sort_spec{sql}|;

  my $results = selectall_hashref_query($form, $dbh, $query, @values);

  $main::lxdebug->leave_sub();

  return $results;
}

sub post_payment {
  my ($self, %params) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_post_payment, $self, %params);

  $::lxdebug->leave_sub;
  return $rc;
}

sub _post_payment {
  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(items));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;
  my $vc       = $params{vc} eq 'customer' ? 'customer' : 'vendor';
  my $arap     = $params{vc} eq 'customer' ? 'ar'       : 'ap';
  my $mult     = $params{vc} eq 'customer' ? -1         : 1;
  my $ARAP     = uc $arap;

  my $dbh      = $params{dbh} || SL::DB->client->dbh;

  my @items    = ref $params{items} eq 'ARRAY' ? @{ $params{items} } : ($params{items});

  my %handles  = (
    'get_item'       => [ qq|SELECT sei.*
                             FROM sepa_export_items sei
                             WHERE sei.id = ?| ],

    'get_arap'       => [ qq|SELECT at.chart_id
                             FROM acc_trans at
                             LEFT JOIN chart c ON (at.chart_id = c.id)
                             WHERE (trans_id = ?)
                               AND ((c.link LIKE '%:${ARAP}') OR (c.link LIKE '${ARAP}:%') OR (c.link = '${ARAP}'))
                             LIMIT 1| ],

    'add_acc_trans'  => [ qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, gldate,       source, memo, taxkey, tax_id ,                                     chart_link)
                             VALUES                (?,        ?,        ?,      ?,         current_date, ?,      '',   0,      (SELECT id FROM tax WHERE taxkey=0 LIMIT 1), (SELECT link FROM chart WHERE id=?))| ],

    'update_arap'    => [ qq|UPDATE ${arap}
                             SET paid = paid + ?
                             WHERE id = ?| ],

    'finish_item'    => [ qq|UPDATE sepa_export_items
                             SET execution_date = ?, executed = TRUE
                             WHERE id = ?| ],

    'has_unexecuted' => [ qq|SELECT sei1.id
                             FROM sepa_export_items sei1
                             WHERE (sei1.sepa_export_id = (SELECT sei2.sepa_export_id
                                                           FROM sepa_export_items sei2
                                                           WHERE sei2.id = ?))
                               AND NOT COALESCE(sei1.executed, FALSE)
                             LIMIT 1| ],

    'do_close'       => [ qq|UPDATE sepa_export
                             SET executed = TRUE, closed = TRUE
                             WHERE (id = ?)| ],
    );

  map { unshift @{ $_ }, prepare_query($form, $dbh, $_->[0]) } values %handles;

  foreach my $item (@items) {

    my $item_id = conv_i($item->{id});

    # Retrieve the item data belonging to the ID.
    do_statement($form, @{ $handles{get_item} }, $item_id);
    my $orig_item = $handles{get_item}->[0]->fetchrow_hashref();

    next if (!$orig_item);

    # fetch item_id via Rose (same id as orig_item)
    my $sepa_export_item = SL::DB::Manager::SepaExportItem->find_by( id => $item_id);

    my $invoice;

    if ( $sepa_export_item->ar_id ) {
      $invoice = SL::DB::Manager::Invoice->find_by( id => $sepa_export_item->ar_id);
    } elsif ( $sepa_export_item->ap_id ) {
      $invoice = SL::DB::Manager::PurchaseInvoice->find_by( id => $sepa_export_item->ap_id);
    } else {
      die "sepa_export_item needs either ar_id or ap_id\n";
    };

    $invoice->pay_invoice(amount       => $sepa_export_item->amount,
                          payment_type => $sepa_export_item->payment_type,
                          chart_id     => $sepa_export_item->chart_id,
                          source       => $sepa_export_item->reference,
                          transdate    => $item->{execution_date},  # value from user form
                         );

    # Update the item to reflect that it has been posted.
    do_statement($form, @{ $handles{finish_item} }, $item->{execution_date}, $item_id);

    # Check whether or not we can close the export itself if there are no unexecuted items left.
    do_statement($form, @{ $handles{has_unexecuted} }, $item_id);
    my ($has_unexecuted) = $handles{has_unexecuted}->[0]->fetchrow_array();

    if (!$has_unexecuted) {
      do_statement($form, @{ $handles{do_close} }, $orig_item->{sepa_export_id});
    }
  }

  map { $_->[0]->finish() } values %handles;

  return 1;
}

sub send_concatinated_sepa_pdfs {
  $main::lxdebug->enter_sub();

  my ($items, $download_filename) = @_;

  my @files;
  foreach my $item (@{$items}) {

    # check if there is already a file for the invoice
    # File::get_all and converting to scalar is a tiny bit stupid, see Form.pm,
    # but there is no get_latest_version (but sorts objects by itime!)
    # check if already resynced
    my ( $file_object ) = SL::File->get_all(object_id   => $item->{ap_id} ? $item->{ap_id} : $item->{ar_id},
                                            object_type => $item->{ap_id} ? 'purchase_invoice' : 'invoice',
                                            file_type   => 'document',
                                           );
    next if     (ref $file_object ne 'SL::File::Object');
    next unless $file_object->mime_type eq 'application/pdf';

    my $file = $file_object->get_file;
    die "No file" unless -e $file;
    push @files, $file;
  }

  my @cmd = (
    $::lx_office_conf{applications}->{ghostscript},
    qw(-dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile=-),
    @files
  );
  my ($out, $err);
  IPC::Run::run \@cmd, \undef, \$out, \$err;

  $::form->error($main::locale->text('Could not spawn ghostscript.') . ' ' . $err) if $err;

  print $::form->create_http_response(content_type        => 'Application/PDF',
                                      content_disposition => 'attachment; filename="'. $download_filename . '"');

  $::locale->with_raw_io(\*STDOUT, sub { print $out });

  $main::lxdebug->leave_sub();
}

sub _round {
  my $value = shift;
  my $num_dec = 2;
  return $::form->round_amount($value, 2);
}

1;


__END__

=head1 NAME

SL::SEPA - Base class for SEPA objects

=head1 SYNOPSIS

 # get all open invoices we like to pay via SEPA
 my $invoices = SL::SEPA->retrieve_open_invoices(vc => 'vendor');

 # add some IBAN and purposes for open transaction
 # and assign this to a SEPA export
 my $id = SL::SEPA->create_export('employee'       => $::myconfig{login},
                                 'bank_transfers' => \@bank_transfers,
                                 'vc'             => 'vendor');

=head1 DESCRIPTIONS

This is the base class for SEPA. SEPA and the underlying directories
(SEPA::XML etc) are used to genereate valid XML files for the SEPA
(Single European Payment Area) specification and offers this structure
as a download via a xml file.

An export can have one or more transaction which have to
comply to the specification (IBAN, BIC, amount, purpose, etc).

Furthermore kivitendo sepa exports have two
valid states: Open or closed and executed or not executed.

The state closed can be set via a user interface and the
state executed is automatically assigned if the action payment
is triggered.

=head1 FUNCTIONS

=head2 C<undo_export> $sepa_export_id

Needs a valid sepa_export id and deletes the sepa export if
the state of the export is neither executed nor closed.
Returns undef if the deletion was successfully.
Otherwise the function just dies with a short notice of the id.

=head2 C<send_concatinated_sepa_pdfs> \@items $download_filename

This function is called from bin/mozialla/sepa.pl. It retrieves PDFs
documents for all elements of @items, concatinates them and sends the
resulting PDF back to the client.

=cut
