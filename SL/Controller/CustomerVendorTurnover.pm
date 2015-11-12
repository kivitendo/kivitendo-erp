package SL::Controller::CustomerVendorTurnover;
use strict;
use parent qw(SL::Controller::Base);
use SL::DBUtils;
use SL::DB::AccTransaction;
use SL::DB::Invoice;

__PACKAGE__->run_before('check_auth');

sub action_list_turnover {
  my ($self) = @_;
  
  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{id};

  my $cv = $::form->{id} || {};
  my $open_invoices;
  $open_invoices = SL::DB::Manager::Invoice->get_all(
    query => [customer_id => $cv,
              paid => {lt_sql => 'amount'},      
    ],
    with_objects => ['dunnings'],
  );
  my $open_items;
  if (@{$open_invoices}) {
    return $self->render(\'', { type => 'json' }) unless scalar @{$open_invoices};
    $open_items = $self->_list_open_items($open_invoices);
  }
  return $self->render('customer_vendor_turnover/turnover', { header => 0 }, open_items => $open_items, id => $cv);
}

sub _list_open_items {
  my ($self, $open_items) = @_;

  return $self->render('customer_vendor_turnover/_list_open_items', { output => 0 }, OPEN_ITEMS => $open_items, title => $::locale->text('Open Items') );
}

sub action_count_open_items_by_year {
  my ($self) = @_;

  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{id};
  my $dbh = $::form->get_standard_dbh();

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
  my $dbh = $::form->get_standard_dbh();

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

  my $dbh = $::form->get_standard_dbh();
  my $cv = $::form->{id} || {};
  my $query = "SELECT CONCAT(EXTRACT (MONTH FROM transdate),'/',EXTRACT (YEAR FROM transdate)) AS date_part,
    count(id) as count,
    sum(amount) as amount,
    sum(netamount) as netamount,
    sum(paid) as paid
    FROM ar WHERE customer_id = $cv
    GROUP BY EXTRACT (YEAR FROM transdate), EXTRACT (MONTH FROM transdate)
    ORDER BY EXTRACT (YEAR FROM transdate) DESC, EXTRACT (MONTH FROM transdate) DESC";

   $self->{turnover_statistic} = selectall_hashref_query($::form, $dbh, $query);
   $self->render('customer_vendor_turnover/count_turnover', { layout => 0 }); 
}
sub action_turnover_by_year {

  my ($self) = @_;

  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{id};

  my $dbh = $::form->get_standard_dbh();
  my $cv = $::form->{id} || {};
  my $query = "SELECT EXTRACT (YEAR FROM transdate) as date_part,
    count(id) as count,
    sum(amount) as amount,
    sum(netamount) as netamount,
    sum(paid) as paid
    FROM ar WHERE customer_id = $cv
    GROUP BY date_part
    ORDER BY date_part DESC";

   $self->{turnover_statistic} = selectall_hashref_query($::form, $dbh, $query);
   $self->render('customer_vendor_turnover/count_turnover', { layout => 0 }); 
}
sub action_get_invoices {
  my ($self) = @_;
  
  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{id};

  my $cv = $::form->{id} || {};
  my $invoices = SL::DB::Manager::Invoice->get_all(
    query => [ customer_id => $cv, ],
    sort_by => 'invnumber DESC',
  );
  $self->render('customer_vendor_turnover/invoices_statistic', { layout => 0 }, invoices => $invoices);
}
sub _list_articles_by_invoice {
}
sub _list_count_articles_by_year {
}
sub check_auth {
  $::auth->assert('general_ledger');
}
1;
