package SL::Controller::CustomerVendorTurnover;
use strict;
use parent qw(SL::Controller::Base);
use SL::DBUtils;
use SL::DB::AccTransaction;
use SL::DB::Invoice;
use SL::DB::Order;
use SL::DB::EmailJournal;
use SL::DB::Letter;
use SL::DB;

__PACKAGE__->run_before('check_auth');

sub action_list_turnover {
  my ($self) = @_;

  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{id};

  my $cv = $::form->{id};
  my $open_invoices;
  if ( $::form->{db} eq 'customer' ) {
    $open_invoices = SL::DB::Manager::Invoice->get_all(
      query        => [
                        customer_id => $cv,
                        or          => [
                                         amount => { gt => \'paid'},
                                         amount => { lt => \'paid'},
                                       ],
                      ],
      sort_by      => 'transdate DESC',
      with_objects => [ 'dunnings' ],
    );
  } else {
    $open_invoices = SL::DB::Manager::PurchaseInvoice->get_all(
      query   => [
                   vendor_id => $cv,
                   or        => [
                                  amount => { gt => \'paid'},
                                  amount => { lt => \'paid'},
                                ],
                 ],
      sort_by => 'transdate DESC',
    );
  }
  my $open_items;
  if (@{$open_invoices}) {
    $open_items = $self->_list_open_items($open_invoices);
  }
  my $open_orders = $self->_get_open_orders;
  return $self->render('customer_vendor_turnover/turnover', { header => 0 },
                       open_orders => $open_orders,
                       open_items  => $open_items,
                       id          => $cv,
                      );
}

sub _list_open_items {
  my ($self, $open_items) = @_;

  return $self->render('customer_vendor_turnover/_list_open_items', { output => 0 },
                        OPEN_ITEMS => $open_items,
                        title      => $::locale->text('Open Items'),
                      );
}

sub action_count_open_items_by_year {
  my ($self) = @_;

  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{id};
  my $dbh = SL::DB->client->dbh;

  my $cv = $::form->{id};

  my $query = <<SQL;
   SELECT EXTRACT (YEAR FROM d.transdate),
          count(d.id),
          max(d.dunning_level)
     FROM dunning d
LEFT JOIN ar a ON a.id = d.trans_id
LEFT JOIN customer c ON a.customer_id = c.id
    WHERE c.id = ?
 GROUP BY EXTRACT (YEAR FROM d.transdate), c.id
 ORDER BY date_part DESC
SQL

  $self->{dun_statistic} = selectall_hashref_query($::form, $dbh, $query, $cv);
  $self->render('customer_vendor_turnover/count_open_items_by_year', { layout => 0 });
}

sub action_count_open_items_by_month {

  my ($self) = @_;

  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{id};
  my $dbh = SL::DB->client->dbh;

  my $cv = $::form->{id};

  my $query = <<SQL;
   SELECT CONCAT(EXTRACT (MONTH FROM d.transdate),'/',EXTRACT (YEAR FROM d.transdate)) AS date_part,
          count(d.id),
          max(d.dunning_level)
     FROM dunning d
LEFT JOIN ar a ON a.id = d.trans_id
LEFT JOIN customer c ON a.customer_id = c.id
    WHERE c.id = ?
 GROUP BY EXTRACT (YEAR FROM d.transdate), EXTRACT (MONTH FROM d.transdate), c.id
 ORDER BY EXTRACT (YEAR FROM d.transdate) DESC
SQL

   $self->{dun_statistic} = selectall_hashref_query($::form, $dbh, $query, $cv);
   $self->render('customer_vendor_turnover/count_open_items_by_year', { layout => 0 });
}

sub action_turnover_by_month {

  my ($self) = @_;

  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{id};

  my $dbh = SL::DB->client->dbh;
  my $cv = $::form->{id};
  my ($db, $cv_type);
  if ($::form->{db} eq 'customer') {
    $db      = "ar";
    $cv_type = "customer_id";
  } else {
    $db      = "ap";
    $cv_type = "vendor_id";
  }
  my $query = <<SQL;
  SELECT CONCAT(EXTRACT (MONTH FROM transdate),'/',EXTRACT (YEAR FROM transdate)) as date_part,
         count(id)                                                                as count,
         sum(amount)                                                              as amount,
         sum(netamount)                                                           as netamount,
         sum(paid)                                                                as paid
    FROM $db WHERE $cv_type = ?
GROUP BY EXTRACT (YEAR FROM transdate), EXTRACT (MONTH FROM transdate)
ORDER BY EXTRACT (YEAR FROM transdate) DESC, EXTRACT (MONTH FROM transdate) DESC
SQL
   $self->{turnover_statistic} = selectall_hashref_query($::form, $dbh, $query, $cv);
   $self->render('customer_vendor_turnover/count_turnover', { layout => 0 });
}

sub action_turnover_by_year {
  my ($self) = @_;

  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{id};

  my $dbh = SL::DB->client->dbh;
  my $cv = $::form->{id};
  my ($db, $cv_type);
  if ($::form->{db} eq 'customer') {
    $db      = "ar";
    $cv_type = "customer_id";
  } else {
    $db      = "ap";
    $cv_type = "vendor_id";
  }
  my $query = <<SQL;
  SELECT EXTRACT (YEAR FROM transdate) as date_part,
         count(id)                     as count,
         sum(amount)                   as amount,
         sum(netamount)                as netamount,
         sum(paid)                     as paid
    FROM $db WHERE $cv_type = ?
GROUP BY date_part
ORDER BY date_part DESC
SQL
   $self->{turnover_statistic} = selectall_hashref_query($::form, $dbh, $query, $cv);
   $self->render('customer_vendor_turnover/count_turnover', { layout => 0 });
}

sub action_get_invoices {
  my ($self) = @_;

  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{id};

  my $cv = $::form->{id};
  my $invoices;
  if ( $::form->{db} eq 'customer' ) {
    $invoices = SL::DB::Manager::Invoice->get_all(
      query   => [ customer_id => $cv, ],
      sort_by => 'transdate DESC',
    );
  } else {
    $invoices = SL::DB::Manager::PurchaseInvoice->get_all(
      query   => [ vendor_id => $cv, ],
      sort_by => 'transdate DESC',
    );
  }
  $self->render('customer_vendor_turnover/invoices_statistic', { layout => 0 }, invoices => $invoices);
}

sub action_get_orders {
  my ($self) = @_;

  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{id};

  my $cv = $::form->{id};
  my $orders;
  my $type = $::form->{type};
  if ( $::form->{db} eq 'customer' ) {
    $orders = SL::DB::Manager::Order->get_all(
      query   => [
                   customer_id => $cv,
                   quotation   => ($type eq 'quotation' ? 'T' : 'F')
                 ],
      sort_by => 'transdate DESC',
    );
  } else {
    $orders = SL::DB::Manager::Order->get_all(
      query   => [
                   vendor_id => $cv,
                   quotation => ($type eq 'quotation' ? 'T' : 'F')
                 ],
      sort_by => 'transdate DESC',
    );
  }
  if ( $type eq 'order') {
    $self->render('customer_vendor_turnover/order_statistic', { layout => 0 }, orders => $orders);
  } else {
    $self->render('customer_vendor_turnover/quotation_statistic', { layout => 0 }, orders => $orders);
  }
}

sub _get_open_orders {
  my ( $self ) = @_;

  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{id};
  my $open_orders;
  my $cv = $::form->{id};

  if ( $::form->{db} eq 'customer' ) {
    $open_orders = SL::DB::Manager::Order->get_all(
      query   => [
                   customer_id => $cv,
                   closed      => 'F',
                 ],
      sort_by => 'transdate DESC',
    );
  } else {
    $open_orders = SL::DB::Manager::Order->get_all(
      query   => [
                   vendor_id => $cv,
                   closed    => 'F',
                 ],
      sort_by => 'transdate DESC',
    );
  }

  return 0 unless scalar @{$open_orders};
  return $self->render('customer_vendor_turnover/_list_open_orders', { output => 0 },
                        orders => $open_orders,
                        title  => $::locale->text('Open Orders'),
                      );
}

sub action_get_mails {
  my ( $self ) = @_;

  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{id};
  my $dbh = SL::DB->client->dbh;
  my $query;
  my $cv = $::form->{id};

  if ( $::form->{db} eq 'customer') {
    $query = <<SQL;
WITH
oe_emails_customer
       AS (SELECT rc.to_id, rc.from_id, oe.quotation, oe.quonumber, oe.ordnumber, c.id
     FROM record_links rc
LEFT JOIN oe oe      ON rc.from_id = oe.id
LEFT JOIN customer c ON oe.customer_id = c.id
    WHERE rc.to_table = 'email_journal'
      AND rc.from_table ='oe'),

do_emails_customer
       AS (SELECT rc.to_id, rc.from_id, o.donumber, c.id
     FROM record_links rc
LEFT JOIN delivery_orders o ON rc.from_id = o.id
LEFT JOIN customer c ON o.customer_id = c.id
    WHERE rc.to_table = 'email_journal'
      AND rc.from_table = 'delivery_orders'),

inv_emails_customer
       AS (SELECT rc.to_id, rc.from_id, inv.type, inv.invnumber, c.id
     FROM record_links rc
LEFT JOIN ar inv ON rc.from_id = inv.id
LEFT JOIN customer c ON inv.customer_id = c.id
    WHERE rc.to_table = 'email_journal'
      AND rc.from_table = 'ar'),

letter_emails_customer
       AS (SELECT rc.to_id, rc.from_id, l.letternumber, c.id
     FROM record_links rc
LEFT JOIN letter l ON rc.from_id = l.id
LEFT JOIN customer c ON l.customer_id = c.id
    WHERE rc.to_table = 'email_journal'
      AND rc.from_table = 'letter')

SELECT ej.*,
 CASE
  oec.quotation WHEN 'F' THEN 'Sales Order'
                ELSE 'Quotation'
 END AS type,
 CASE
  oec.quotation WHEN 'F' THEN oec.ordnumber
                ELSE oec.quonumber
 END    AS recordnumber,
 oec.id AS record_id
     FROM email_journal ej
LEFT JOIN oe_emails_customer oec ON ej.id = oec.to_id
    WHERE oec.id = ?

UNION

SELECT ej.*, 'Delivery Order' AS type, dec.donumber AS recordnumber,dec.id AS record_id
     FROM email_journal ej
LEFT JOIN do_emails_customer dec ON ej.id = dec.to_id
    WHERE dec.id = ?

UNION

SELECT ej.*,
 CASE
  iec.type WHEN 'credit_note' THEN 'Credit Note'
           WHEN 'invoice' THEN 'Invoice'
           ELSE 'N/A'
 END           AS type,
 iec.invnumber AS recordnumber,
        iec.id AS record_id
     FROM email_journal ej
LEFT JOIN inv_emails_customer iec ON ej.id = iec.to_id
    WHERE iec.id = ?

UNION

SELECT ej.*, 'Letter' AS type, lec.letternumber AS recordnumber,lec.id AS record_id
     FROM email_journal ej
LEFT JOIN letter_emails_customer lec ON ej.id = lec.to_id
    WHERE lec.id = ?
 ORDER BY sent_on DESC
SQL
  }
  else {
    $query = <<SQL;
WITH
oe_emails_vendor
       AS (SELECT rc.to_id, rc.from_id, oe.quotation, oe.quonumber, oe.ordnumber, c.id
     FROM record_links rc
LEFT JOIN oe oe ON rc.from_id = oe.id
LEFT JOIN vendor c ON oe.vendor_id = c.id
    WHERE rc.to_table = 'email_journal'
      AND rc.from_table ='oe'),

do_emails_vendor
       AS (SELECT rc.to_id, rc.from_id, o.donumber, c.id
     FROM record_links rc
LEFT JOIN delivery_orders o ON rc.from_id = o.id
LEFT JOIN vendor c ON o.vendor_id = c.id
    WHERE rc.to_table = 'email_journal'
      AND rc.from_table = 'delivery_orders'),

inv_emails_vendor
       AS (SELECT rc.to_id, rc.from_id, inv.type, inv.invnumber, c.id
     FROM record_links rc
LEFT JOIN ap inv ON rc.from_id = inv.id
LEFT JOIN vendor c ON inv.vendor_id = c.id
    WHERE rc.to_table = 'email_journal'
      AND rc.from_table = 'ar'),

letter_emails_vendor
       AS (SELECT rc.to_id, rc.from_id, l.letternumber, c.id
     FROM record_links rc
LEFT JOIN letter l ON rc.from_id = l.id
LEFT JOIN vendor c ON l.vendor_id = c.id
    WHERE rc.to_table = 'email_journal'
      AND rc.from_table = 'letter')

SELECT ej.*,
 CASE
  oec.quotation WHEN 'F' THEN 'Purchase Order'
                ELSE 'Request quotation'
 END AS type,
 CASE
  oec.quotation WHEN 'F' THEN oec.ordnumber
                ELSE oec.quonumber
 END   AS recordnumber,
oec.id AS record_id
     FROM email_journal ej
LEFT JOIN oe_emails_vendor oec ON ej.id = oec.to_id
    WHERE oec.id = ?

UNION

SELECT ej.*, 'Purchase Delivery Order' AS type, dec.donumber AS recordnumber, dec.id AS record_id
     FROM email_journal ej
LEFT JOIN do_emails_vendor dec ON ej.id = dec.to_id
    WHERE dec.id = ?

UNION

SELECT ej.*, iec.type AS type, iec.invnumber AS recordnumber, iec.id AS record_id
     FROM email_journal ej
LEFT JOIN inv_emails_vendor iec ON ej.id = iec.to_id
    WHERE iec.id = ?

UNION

SELECT ej.*, 'Letter' AS type, lec.letternumber AS recordnumber, lec.id AS record_id
     FROM email_journal ej
LEFT JOIN letter_emails_vendor lec ON ej.id = lec.to_id
    WHERE lec.id = ?
 ORDER BY sent_on DESC
SQL
  }
  my $emails = selectall_hashref_query($::form, $dbh, $query, $cv, $cv, $cv, $cv);
  $self->render('customer_vendor_turnover/email_statistic', { layout => 0 }, emails => $emails);
}

sub action_get_letters {
  my ($self) = @_;

  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{id};

  my $cv = $::form->{id};
  my $letters;
  my $type = $::form->{type};
  if ( $::form->{db} eq 'customer' ) {
    $letters = SL::DB::Manager::Letter->get_all(
      query   => [ customer_id => $cv, ],
      sort_by => 'date DESC',
    );
  } else {
    $letters = SL::DB::Manager::Letter->get_all(
      query   => [ vendor_id => $cv, ],
      sort_by => 'date DESC',
    );
  }
    $self->render('customer_vendor_turnover/letter_statistic', { layout => 0 }, letters => $letters);
}

sub check_auth {
  $::auth->assert('show_extra_record_tab_customer | show_extra_record_tab_vendor');
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::CustomerVendorTurnover

=head1 DESCRIPTION

Gets all kinds of records like orders, request orders, quotations, invoices, emails, letters

wich belong to customer/vendor and displays them in an extra tab "Records".

=head1 URL ACTIONS

=over 4

=item C<action_list_turnover>

Basic action wich displays open invoices and open orders if there are any and shows the tab menu for the other actions

=item C<action_count_open_items_by_month>

gets and shows a dunning statistic of the customer by month

=item C<action_count_open_items_by_year>

gets and shows a dunning statistic of the customer by year

=item C<action_turnover_by_month>

gets and shows an invoice statistic of customer/vendor by month

=item C<action_turnover_by_year>

gets and shows an invoice statistic of customer/vendor by year

=item C<action_get_invoices>

get and shows all invoices from the customer/vendor in an extra tab

=item C<action_get_orders>

get and shows all orders from the customer/vendor in an extra tab

=item C<action_get_letters>

get and shows all letters from the customer/vendor in an extra tab

=item C<action_get_mails>

get and shows all mails from the customer/vendor in an extra tab

=back

=head1 Functions

=over 4

=item C<_get_open_orders>

retrieves the open orders for customer/vendor to display them

=item C<_list_open_items>

retrieves open invoices with their dunnings to display them

=back

=head1 BUGS

None yet. :)

=head1 AUTHOR

W. Hahn E<lt>wh@futureworldsearch.netE<gt>

=cut
