package SL::SEPA;

use strict;

use POSIX qw(strftime);

use SL::DBUtils;

sub retrieve_open_invoices {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);
  my $arap     = $params{vc} eq 'customer' ? 'ar'       : 'ap';
  my $vc       = $params{vc} eq 'customer' ? 'customer' : 'vendor';

  my $query =
    qq|
       SELECT ${arap}.id, ${arap}.invnumber, ${arap}.${vc}_id as vc_id, ${arap}.amount AS invoice_amount, ${arap}.invoice,
         vc.name AS vcname, vc.language_id, ${arap}.duedate as duedate, ${arap}.direct_debit,

         COALESCE(vc.iban, '') <> '' AND COALESCE(vc.bic, '') <> '' AS vc_bank_info_ok,

         ${arap}.amount - ${arap}.paid - COALESCE(open_transfers.amount, 0) AS open_amount

       FROM ${arap}
       LEFT JOIN ${vc} vc ON (${arap}.${vc}_id = vc.id)
       LEFT JOIN (SELECT sei.ap_id, SUM(sei.amount) AS amount
                  FROM sepa_export_items sei
                  LEFT JOIN sepa_export se ON (sei.sepa_export_id = se.id)
                  WHERE NOT se.closed
                    AND (se.vc = '${vc}')
                  GROUP BY sei.ap_id)
         AS open_transfers ON (${arap}.id = open_transfers.ap_id)

       WHERE ${arap}.amount > (COALESCE(open_transfers.amount, 0) + ${arap}.paid)

       ORDER BY lower(vc.name) ASC, lower(${arap}.invnumber) ASC
|;

  my $results = selectall_hashref_query($form, $dbh, $query);

  $main::lxdebug->leave_sub();

  return $results;
}

sub create_export {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(employee bank_transfers vc));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;
  my $arap     = $params{vc} eq 'customer' ? 'ar'       : 'ap';
  my $vc       = $params{vc} eq 'customer' ? 'customer' : 'vendor';
  my $ARAP     = uc $arap;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my ($export_id) = selectfirst_array_query($form, $dbh, qq|SELECT nextval('sepa_export_id_seq')|);
  my $query       =
    qq|INSERT INTO sepa_export (id, employee_id, vc)
       VALUES (?, (SELECT id
                   FROM employee
                   WHERE login = ?), ?)|;
  do_query($form, $dbh, $query, $export_id, $params{employee}, $vc);

  my $q_item_id = qq|SELECT nextval('id')|;
  my $h_item_id = prepare_query($form, $dbh, $q_item_id);

  my $q_insert =
    qq|INSERT INTO sepa_export_items (id,          sepa_export_id,           ${arap}_id,  chart_id,
                                      amount,      requested_execution_date, reference,   end_to_end_id,
                                      our_iban,    our_bic,                  vc_iban,     vc_bic)
       VALUES                        (?,           ?,                        ?,           ?,
                                      ?,           ?,                        ?,           ?,
                                      ?,           ?,                        ?,           ?)|;
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

  my @now         = localtime;

  foreach my $transfer (@{ $params{bank_transfers} }) {
    if (!$transfer->{reference}) {
      do_statement($form, $h_reference, $q_reference, (conv_i($transfer->{"${arap}_id"})) x 3);

      my ($invnumber, $num_payments) = $h_reference->fetchrow_array();
      $num_payments++;

      $transfer->{reference} = "${invnumber}-${num_payments}";
    }

    $h_item_id->execute();
    my ($item_id)      = $h_item_id->fetchrow_array();

    my $end_to_end_id  = strftime "LXO%Y%m%d%H%M%S", localtime;
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

    do_statement($form, $h_insert, $q_insert, @values);
  }

  $h_insert->finish();
  $h_item_id->finish();

  $dbh->commit() unless ($params{dbh});

  $main::lxdebug->leave_sub();

  return $export_id;
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

  my ($joins, $columns);

  if ($params{details}) {
    $columns = ', arap.invoice';
    $joins   = "LEFT JOIN ${arap} arap ON (se.${arap}_id = arap.id)";
  }

  my $query =
    qq|SELECT se.*,
         CASE WHEN COALESCE(e.name, '') <> '' THEN e.name ELSE e.login END AS employee
       FROM sepa_export se
       LEFT JOIN employee e ON (se.employee_id = e.id)
       WHERE se.id = ?|;

  my $export = selectfirst_hashref_query($form, $dbh, $query, conv_i($params{id}));

  if ($export->{id}) {
    my ($columns, $joins);

    if ($params{details}) {
      $columns = qq|, arap.invnumber, arap.invoice, arap.transdate AS reference_date, vc.name AS vc_name, vc.${vc}number AS vc_number, c.accno AS chart_accno, c.description AS chart_description|;
      $joins   = qq|LEFT JOIN ${arap} arap ON (sei.${arap}_id = arap.id)
                    LEFT JOIN ${vc} vc     ON (arap.${vc}_id  = vc.id)
                    LEFT JOIN chart c      ON (sei.chart_id   = c.id)|;
    }

    $query = qq|SELECT sei.*
                  $columns
                FROM sepa_export_items sei
                $joins
                WHERE sei.sepa_export_id = ?|;

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

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my @ids          = ref $params{id} eq 'ARRAY' ? @{ $params{id} } : ($params{id});
  my $placeholders = join ', ', ('?') x scalar @ids;
  my $query        = qq|UPDATE sepa_export SET closed = TRUE WHERE id IN ($placeholders)|;

  do_query($form, $dbh, $query, map { conv_i($_) } @ids);

  $dbh->commit() unless ($params{dbh});

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
    push @values_sub, '%' . $filter->{invnumber} . '%';
    $joins_sub{$arap} = 1;
  }

  if ($filter->{vc}) {
    push @where_sub,  "vc.name ILIKE ?";
    push @values_sub, '%' . $filter->{vc} . '%';
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
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(items));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;
  my $vc       = $params{vc} eq 'customer' ? 'customer' : 'vendor';
  my $arap     = $params{vc} eq 'customer' ? 'ar'       : 'ap';
  my $mult     = $params{vc} eq 'customer' ? -1         : 1;
  my $ARAP     = uc $arap;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

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

    # Retrieve the invoice's AR/AP chart ID.
    do_statement($form, @{ $handles{get_arap} }, $orig_item->{"${arap}_id"});
    my ($arap_chart_id) = $handles{get_arap}->[0]->fetchrow_array();

    # Record the payment in acc_trans offsetting AR/AP.
    do_statement($form, @{ $handles{add_acc_trans} }, $orig_item->{"${arap}_id"}, $arap_chart_id,         -1 * $mult * $orig_item->{amount}, $item->{execution_date}, '', $arap_chart_id);
    do_statement($form, @{ $handles{add_acc_trans} }, $orig_item->{"${arap}_id"}, $orig_item->{chart_id},      $mult * $orig_item->{amount}, $item->{execution_date}, $orig_item->{reference},
                                                      $orig_item->{chart_id});

    # Update the invoice to reflect the new paid amount.
    do_statement($form, @{ $handles{update_arap} }, $orig_item->{amount}, $orig_item->{"${arap}_id"});

    # Update datepaid of invoice. set_datepaid (which has some extra logic)
    # finds the date from acc_trans, where the payment has already been
    # recorded above, so we don't need to explicitly pass
    # $item->{execution_date}
    IO->set_datepaid(table => "$arap", id => $orig_item->{"${arap}_id"}, dbh => $dbh);

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

  $dbh->commit() unless ($params{dbh});

  $main::lxdebug->leave_sub();
}

1;
