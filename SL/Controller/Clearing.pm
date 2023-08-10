package SL::Controller::Clearing;

use strict;

use parent qw(SL::Controller::Base);

use SL::Clearing;
use SL::DB::ClearedGroup;
use SL::DB::Project;
use SL::DB::Department;
use SL::DB::Chart;
use SL::Locale::String qw(t8);
use SL::DBUtils qw(selectall_hashref_query);
use List::MoreUtils qw(uniq);

use Rose::Object::MakeMethods::Generic (
  'scalar' => [ qw(chart chart_transactions cleared_group_transactions fromdate todate project_id department_id susa_link) ]
);

__PACKAGE__->run_before('check_auth');

sub action_form {
  my ($self) = @_;

  $self->_parse_form;

  if ( $self->chart && !$self->chart->clearing ) {
    return $self->render('clearing/chart_missing', { layout => 1, process => 1 },
      chart => $self->chart,
    );
  }

  my @susa_url_params = (
    controller => 'ca.pl',
    action     => 'list_transactions',
    method     => 'cash'
  );

  my %susa_params = (
    accno       => $self->chart    ? $self->chart->accno           : '',
    fromdate    => $self->fromdate ? $self->fromdate->to_kivitendo : undef,
    todate      => $self->todate   ? $self->todate->to_kivitendo   : undef,
    description => $self->chart    ? $self->chart->description     : '',
  );

  foreach my $key ( keys %susa_params ) {
    if ( $susa_params{$key} ) {
      push(@susa_url_params, ( $key => $susa_params{$key} ));
    }
  }

  $self->susa_link($self->url_for(@susa_url_params));
  $self->setup_action_bar;

  $self->{all_departments} = SL::DB::Manager::Department->get_all_sorted();

  $::request->layout->use_javascript("${_}.js") for qw(knockout-3.5.1 knockout.kivitendo clearing);
  $::request->layout->use_stylesheet("css/clearing.css");

  $self->render('clearing/form', { layout => 1, process => 1 },
                 chart_id  => $self->chart ? $self->chart->id : '',
                 susa_link => $self->susa_link,
               );
}

sub _parse_form {
  my ($self) = @_;

  # chart, fromdate, todate, project_id, department_id, load_cleared

  if ( $::form->{accno} ) { # only needed for link from ca list_transactions
    # here we assume that there is only one chart per accno, though the old code for CA all_transactions allows for several chart.id to be summed up
    $self->chart( SL::DB::Manager::Chart->find_by(accno => delete $::form->{accno}) );
  } elsif ( $::form->{chart_id} ) {
    $self->chart( SL::DB::Chart->new(id => delete $::form->{chart_id})->load);
  };
  # TODO: check that chart has clearing attribute

  if ( $::form->{filter}->{fromdate} || $::form->{fromdate} ) {
    my $fromdate = $::form->{filter}->{fromdate} || $::form->{fromdate};
    $self->fromdate( $::locale->parse_date_to_object($fromdate) );
  }

  if ( $::form->{filter}->{todate} || $::form->{todate} ) {
    my $todate = $::form->{filter}->{todate} || $::form->{todate};
    $self->todate( $::locale->parse_date_to_object($todate) );
  }

  if ( $::form->{filter}->{project_id} || $::form->{project_id} ) {
    $self->project_id($::form->{filter}->{project_id} || $::form->{project_id});
  }

  if ( $::form->{filter}->{department_id} || $::form->{department_id} ) {
    $self->department_id($::form->{filter}->{department_id} || $::form->{department_id});
  }
}

sub action_create_cleared_group {
  my ($self) = @_;

  my $cleared_group_transactions = $::request->post_data;

  my @acc_trans_ids = map { $_->{acc_trans_id} } @{ $cleared_group_transactions };

  my $result = SL::Clearing::create_cleared_group(\@acc_trans_ids);
  if ( $result ) {
    $self->js->flash('info', t8('Cleared bookings'));
  } else {
    $self->js->flash('error', t8('Error while clearing'));
  }
  return $self->js->render;
}

sub action_remove_cleared_group {
  my ($self) = @_;

  my $cleared_group_transactions = $::request->post_data;

  my @cleared_group_ids= map { $_->{cleared_group_id} } @{ $cleared_group_transactions };
  die "no unique cleared group" unless scalar uniq @cleared_group_ids == 1;
  my $cleared_group_id = $cleared_group_ids[0];

  my $result = SL::Clearing::remove_cleared_group($cleared_group_id);
  if ( $result ) {
    $self->js->flash('info', t8('Removed cleared group'));
  } else {
    $self->js->flash('error', t8('error while unclearing'));
  }
  return $self->js->render;
}

# actions returning JSON

sub action_list {
  my ($self) = @_;

  $self->_parse_form;

  die "no valid clearing chart" unless $self->chart && $self->chart->clearing;

  my $filter = delete $::form->{filter};

  my %params = (
    chart_id      => $self->chart->id,
    fromdate      => $self->fromdate,
    todate        => $self->todate,
    project_id    => $self->project_id,
    department_id => $self->department_id,
    load_cleared  => $filter->{load_cleared} ? 1 : 0,
  );

  my $chart_transactions = SL::Clearing::load_chart_transactions(\%params);

  $self->chart_transactions($chart_transactions);

  return $self->render(\ SL::JSON::to_json( $self->chart_transactions ), { layout => 0, type => 'json', process => 0 });
}

sub action_fetch_cleared_group {
  my ($self) = @_;

  $self->load_cleared_group_transactions($::form->{cleared_group_id});
  return $self->render(\ SL::JSON::to_json( $self->cleared_group_transactions ), { layout => 0, type => 'json', process => 0 });
}

sub load_cleared_group_transactions {
  my ($self, $cleared_group_id) = @_;

  my $cleared_group_transactions = SL::Clearing::load_cleared_group_transactions_by_group_id($cleared_group_id);

  # convert itime to locale_formatted itime
  foreach my $line ( @$cleared_group_transactions ) {
    my $dt = DateTime::Format::Pg->parse_datetime( $line->{itime} );
    $line->{formatted_itime} = $::locale->format_date_object($dt, precision => 'seconds');
  }
  $self->cleared_group_transactions($cleared_group_transactions);
}

sub setup_action_bar {
  my ($self, %params) = @_;
  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      link => [
        t8('List Transactions'),
        link => $self->susa_link,
      ],
    );
  }
}

sub add_javascripts  {
  $::request->layout->add_javascripts(qw(knockout-3.5.1.js knockout.kivitendo.js));
}

sub check_auth {
  $::auth->assert('general_ledger');
}

1;
