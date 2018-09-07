package SL::Controller::CustomerVendorTurnover;
use strict;
use parent qw(SL::Controller::Base);
use SL::DBUtils;
use SL::DB::AccTransaction;
use SL::DB::Invoice;
use SL::DB::Order;
use SL::DB;

__PACKAGE__->run_before('check_auth');

sub action_list_turnover {
  my ($self) = @_;

  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{id};

  my $cv = $::form->{id} || {};
  my $open_invoices;
  if ( $::form->{db} eq 'customer' ) {
  $open_invoices = SL::DB::Manager::Invoice->get_all(
    query => [customer_id => $cv,
                or => [
                      amount => { gt => \'paid'},
                      amount => { lt => \'paid'},
                    ],
    ],
    with_objects => ['dunnings'],
  );
  } else {
    $open_invoices = SL::DB::Manager::PurchaseInvoice->get_all(
      query   => [ vendor_id => $cv,
                or => [
                      amount => { gt => \'paid'},
                      amount => { lt => \'paid'},
                    ],
               ],
      sort_by => 'invnumber DESC',
    );
  }
  my $open_items;
  if (@{$open_invoices}) {
    return $self->render(\'', { type => 'json' }) unless scalar @{$open_invoices};
    $open_items = $self->_list_open_items($open_invoices);
  }
  my $open_orders = $self->_get_open_orders();
  return $self->render('customer_vendor_turnover/turnover', { header => 0 }, open_orders => $open_orders, open_items => $open_items, id => $cv);
}

sub _list_open_items {
  my ($self, $open_items) = @_;

  return $self->render('customer_vendor_turnover/_list_open_items', { output => 0 }, OPEN_ITEMS => $open_items, title => $::locale->text('Open Items') );
}

sub action_count_open_items_by_year {
  my ($self) = @_;

  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{id};
  my $dbh = SL::DB->client->dbh;

  my $cv = $::form->{id} || {};

  my $query = "SELECT EXTRACT (YEAR FROM d.transdate),
    count(d.id),
    max(d.dunning_level)
    FROM dunning d
    LEFT JOIN ar a
    ON a.id = d.trans_id
    LEFT JOIN customer c
    ON a.customer_id = c.id
    WHERE c.id = $cv
    GROUP BY EXTRACT (YEAR FROM d.transdate), c.id
    ORDER BY date_part DESC";

   $self->{dun_statistic} = selectall_hashref_query($::form, $dbh, $query);
   $self->render('customer_vendor_turnover/count_open_items_by_year', { layout => 0 });
}
sub action_count_open_items_by_month {

  my ($self) = @_;

  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{id};
  my $dbh = SL::DB->client->dbh;

  my $cv = $::form->{id} || {};

  my $query = "SELECT CONCAT(EXTRACT (MONTH FROM d.transdate),'/',EXTRACT (YEAR FROM d.transdate)) AS date_part,
    count(d.id),
    max(d.dunning_level)
    FROM dunning d
    LEFT JOIN ar a
    ON a.id = d.trans_id
    LEFT JOIN customer c
    ON a.customer_id = c.id
    WHERE c.id = $cv
    GROUP BY EXTRACT (YEAR FROM d.transdate), EXTRACT (MONTH FROM d.transdate), c.id
    ORDER BY EXTRACT (YEAR FROM d.transdate) DESC";

   $self->{dun_statistic} = selectall_hashref_query($::form, $dbh, $query);
   $self->render('customer_vendor_turnover/count_open_items_by_year', { layout => 0 });
}
sub action_turnover_by_month {

  my ($self) = @_;

  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{id};

  my $dbh = SL::DB->client->dbh;
  my $cv = $::form->{id} || {};
  my ($db, $cv_type);
  if ($::form->{db} eq 'customer') {
    $db      = "ar";
    $cv_type = "customer_id";
  } else {
    $db      = "ap";
    $cv_type = "vendor_id";
  }
  my $query = <<SQL;
SELECT CONCAT(EXTRACT (MONTH FROM transdate),'/',EXTRACT (YEAR FROM transdate)) AS date_part,
    count(id) as count,
    sum(amount) as amount,
    sum(netamount) as netamount,
    sum(paid) as paid
    FROM $db WHERE $cv_type = $cv
    GROUP BY EXTRACT (YEAR FROM transdate), EXTRACT (MONTH FROM transdate)
    ORDER BY EXTRACT (YEAR FROM transdate) DESC, EXTRACT (MONTH FROM transdate) DESC
SQL
   $self->{turnover_statistic} = selectall_hashref_query($::form, $dbh, $query);
   $self->render('customer_vendor_turnover/count_turnover', { layout => 0 });
}
sub action_turnover_by_year {
  my ($self) = @_;

  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{id};

  my $dbh = SL::DB->client->dbh;
  my $cv = $::form->{id} || {};
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
    count(id) as count,
    sum(amount) as amount,
    sum(netamount) as netamount,
    sum(paid) as paid
    FROM $db WHERE $cv_type = $cv
    GROUP BY date_part
    ORDER BY date_part DESC
SQL
   $self->{turnover_statistic} = selectall_hashref_query($::form, $dbh, $query);
   $self->render('customer_vendor_turnover/count_turnover', { layout => 0 });
}

sub action_get_invoices {
  my ($self) = @_;

  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{id};

  my $cv = $::form->{id} || {};
  my $invoices;
  if ( $::form->{db} eq 'customer' ) {
    $invoices = SL::DB::Manager::Invoice->get_all(
      query => [ customer_id => $cv, ],
      sort_by => 'invnumber DESC',
    );
  } else {
    $invoices = SL::DB::Manager::PurchaseInvoice->get_all(
      query => [ vendor_id => $cv, ],
      sort_by => 'invnumber DESC',
    );
  }
  $self->render('customer_vendor_turnover/invoices_statistic', { layout => 0 }, invoices => $invoices);
}

sub action_get_orders {
  my ($self) = @_;

  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{id};

  my $cv = $::form->{id} || {};
  my $orders;
  my $type = $::form->{type};
  if ( $::form->{db} eq 'customer' ) {
    $orders = SL::DB::Manager::Order->get_all(
      query => [ customer_id => $cv,
                 quotation   => ($type eq 'quotation' ? 'T' : 'F') ],
      sort_by => ( $type eq 'order' ? 'ordnumber DESC' : 'quonumber DESC'),
    );
  } else {
    $orders = SL::DB::Manager::Order->get_all(
      query => [ vendor_id => $cv,
                 quotation   => ($type eq 'quotation' ? 'T' : 'F') ],
      sort_by => ( $type eq 'order' ? 'ordnumber DESC' : 'quonumber DESC'),
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
  my $cv = $::form->{id} || {};

  if ( $::form->{db} eq 'customer' ) {
    $open_orders = SL::DB::Manager::Order->get_all(
      query => [ customer_id => $cv,
                   closed => 'F',
               ],
               sort_by => 'ordnumber DESC',
               );
  } else {
    $open_orders = SL::DB::Manager::Order->get_all(
      query => [ vendor_id => $cv,
                   closed => 'F',
               ],
               sort_by => 'ordnumber DESC',
               );
  }

  return 0 unless scalar @{$open_orders};
  return $self->render('customer_vendor_turnover/_list_open_orders', { output => 0 }, orders => $open_orders, title => $::locale->text('Open Orders') );
}

sub _list_articles_by_invoice {
}
sub _list_count_articles_by_year {
}
sub check_auth {
  $::auth->assert('general_ledger');
}
1;
