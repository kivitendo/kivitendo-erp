package SL::SEPA;

use strict;

use IPC::Run qw();
use POSIX qw(strftime);

use Data::Dumper;
use SL::DBUtils;
use SL::DB::Invoice;
use SL::DB::PurchaseInvoice;
use SL::DB;
use SL::Helper::ISO4217;
use SL::Locale::String qw(t8);
use DateTime;
use Carp;

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

  # open_amount is not the current open amount according to bookkeeping, but
  # the open amount minus the SEPA transfer amounts that haven't been closed yet
  my $query =
    qq|
       SELECT ${arap}.id, ${arap}.invnumber, ${arap}.transdate, ${arap}.${vc}_id as vc_id, ${arap}.amount AS invoice_amount, ${arap}.invoice,
         ${arap}.currency_id,
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

       WHERE (${arap}.amount - (COALESCE(open_transfers.amount, 0) + ${arap}.paid)) >= 0.01

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

    # add the original record's currency
    $result->{currency}         = SL::DB::Currency->load_cached($result->{currency_id})->name;
    $result->{currency_not_eur} = 'EUR' ne SL::Helper::ISO4217::map_currency_name_to_code($result->{currency});
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
                                      skonto_amount, payment_type ${c_mandate})
       VALUES                        (?,           ?,                        ?,           ?,
                                      ?,           ?,                        ?,           ?,
                                      ?,           ?,                        ?,           ?,
                                      ?,           ? ${p_mandate})|;
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

    $h_item_id->execute() || $::form->dberror($q_item_id);
    my ($item_id)      = $h_item_id->fetchrow_array();

    my $end_to_end_id  = strftime "KIVITENDO%Y%m%d%H%M%S", localtime;
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

    do_statement($form, $h_insert, $q_insert, @values);
  }

  $h_insert->finish();
  $h_item_id->finish();

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

    my $mandator_id = $params{vc} eq 'customer' ? ', mandator_id, mandate_date_of_signature' : '';

    if ($params{details}) {
      $columns = qq|, arap.invnumber, arap.invoice, arap.transdate AS reference_date, vc.name AS vc_name, vc.${vc}number AS vc_number, c.accno AS chart_accno, c.description AS chart_description ${mandator_id}|;
      $joins   = qq|LEFT JOIN ${arap} arap ON (sei.${arap}_id = arap.id)
                    LEFT JOIN ${vc} vc     ON (arap.${vc}_id  = vc.id)
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

  die "Could not undo $sepa_export->id" if !$sepa_export->delete();

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
