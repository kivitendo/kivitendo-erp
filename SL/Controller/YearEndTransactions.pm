package SL::Controller::YearEndTransactions;

use strict;

use parent qw(SL::Controller::Base);

use DateTime;
use SL::Locale::String qw(t8);
use SL::ReportGenerator;
use SL::Helper::Flash;
use SL::DBUtils;

use SL::DB::Chart;
use SL::DB::GLTransaction;
use SL::DB::AccTransaction;
use SL::DB::Helper::AccountingPeriod qw(get_balance_starting_date);

use SL::Presenter::Tag qw(checkbox_tag);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(charts charts9000 cbob_chart cb_date cb_startdate ob_date cb_reference ob_reference cb_description ob_description) ],
);

__PACKAGE__->run_before('check_auth');

sub action_filter {
  my ($self) = @_;
  $self->ob_date(DateTime->today->truncate(to => 'year'))                  if !$self->ob_date;
  $self->cb_date(DateTime->today->truncate(to => 'year')->add(days => -1)) if !$self->cb_date;
  $self->ob_reference(t8('OB Transaction'))   if !$self->ob_reference;
  $self->cb_reference(t8('CB Transaction'))   if !$self->cb_reference;
  $self->ob_description(t8('OB Transaction')) if !$self->ob_description;
  $self->cb_description(t8('CB Transaction')) if !$self->cb_description;

  $self->setup_filter_action_bar;
  $self->render('gl/yearend_filter',
                title               => t8('CB/OB Transactions'),
                make_title_of_chart => sub { $_[0]->accno.' '.$_[0]->description }
               );

}

sub action_list {
  my ($self) = @_;
  $main::lxdebug->enter_sub();

  my $report     = SL::ReportGenerator->new(\%::myconfig, $::form);

  $self->prepare_report($report);

  $report->set_options(
    output_format        => 'HTML',
    raw_top_info_text    => $::form->parse_html_template('gl/yearend_top',    { SELF => $self }),
    raw_bottom_info_text => $::form->parse_html_template('gl/yearend_bottom', { SELF => $self }),
    allow_pdf_export     => 0,
    allow_csv_export     => 0,
    title                => $::locale->text('CB/OB Transactions'),
  );

  $self->setup_list_action_bar;
  $report->generate_with_headers();
  $main::lxdebug->leave_sub();
}

sub action_generate {
  my ($self) = @_;

  my $cnt = $self->make_booking();

  flash('info', $::locale->text('#1 CB transactions and #1 OB transactions generated.',$cnt)) if $cnt > 0;

  $self->action_list;
}

sub check_auth {
  $::auth->assert('general_ledger');
}

#
# helpers
#

sub make_booking {
  my ($self) = @_;
  $main::lxdebug->enter_sub();
  my @ids = map { $::form->{"multi_id_$_"} } grep { $::form->{"multi_id_$_"} } (1..$::form->{rowcount});
  my $cnt = 0;
  $main::lxdebug->message(LXDebug->DEBUG2(),"generate for ".$::form->{cbob_chart}." # ".scalar(@ids)." charts");
  if (scalar(@ids) && $::form->{cbob_chart}) {
    my $carryoverchart = SL::DB::Manager::Chart->get_first(  query => [ id => $::form->{cbob_chart} ] );
    my $charts = SL::DB::Manager::Chart->get_all(  query => [ id => \@ids ] );
    foreach my $chart (@{ $charts }) {
      $main::lxdebug->message(LXDebug->DEBUG2(),"chart_id=".$chart->id." accno=".$chart->accno);
      my $balance = $self->get_balance($chart);
      if ( $balance != 0 ) {
        # SB
        $self->gl_booking($balance,$self->cb_date,$::form->{cb_reference},$::form->{cb_description},$chart,$carryoverchart,0,1);
        # EB
        $self->gl_booking($balance,$self->ob_date,$::form->{ob_reference},$::form->{ob_description},$carryoverchart,$chart,1,0);
        $cnt++;
      }
    }
  }
  $main::lxdebug->leave_sub();
  return $cnt;
}


sub prepare_report {
  my ($self,$report) = @_;
  $main::lxdebug->enter_sub();
  my $idx = 1;

  my %column_defs = (
    'ids'         => { raw_header_data => checkbox_tag("", id => "check_all",
                                                                          checkall => "[data-checkall=1]"), 'align' => 'center' },
    'chart'       => { text => $::locale->text('Account'), },
    'description' => { text => $::locale->text('Description'), },
    'saldo'       => { text => $::locale->text('Saldo'),  'align' => 'right'},
    'sum_cb'      => { text => $::locale->text('Sum CB Transactions'), 'align' => 'right'},  ##close == Schluss
    'sum_ob'      => { text => $::locale->text('Sum OB Transactions'), 'align' => 'right'},  ##open  == Eingang
  );
  my @columns      = qw(ids chart description saldo sum_cb sum_ob);
  map { $column_defs{$_}->{visible} = 1 } @columns;

  my $ob_next_date = $self->ob_date->clone();
  $ob_next_date->add(years => 1)->add(days => -1);

  $self->cb_startdate($::locale->parse_date_to_object($self->get_balance_starting_date($self->cb_date)));

  my @custom_headers = ();
  # Zeile 1:
  push @custom_headers, [
      { 'text' => '   ', 'colspan' => 3 },
      { 'text' => $::locale->text("Timerange")."<br />".$self->cb_startdate->to_kivitendo." - ".$self->cb_date->to_kivitendo, 'colspan' => 2, 'align' => 'center'},
      { 'text' => $::locale->text("Timerange")."<br />".$self->ob_date->to_kivitendo." - ".$ob_next_date->to_kivitendo, 'align' => 'center'},
    ];

  # Zeile 2:
  my @line_2 = ();
  map { push @line_2 , $column_defs{$_} } grep { $column_defs{$_}->{visible} } @columns;
  push @custom_headers, [ @line_2 ];

  $report->set_custom_headers(@custom_headers);
  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  my $chart9actual = SL::DB::Manager::Chart->get_first( query => [ id => $self->cbob_chart ] );
  $self->{cbob_chartaccno} = $chart9actual->accno.' '.$chart9actual->description;

  foreach my $chart (@{ $self->charts }) {
    my $balance = $self->get_balance($chart);
    if ( $balance != 0 ) {
      my $chart_id = $chart->id;
      my $row = { map { $_ => { 'data' => '' } } @columns };
      $row->{ids}  = {
        'raw_data' => checkbox_tag("multi_id_${idx}", value => $chart_id, "data-checkall" => 1),
        'valign'   => 'center',
        'align'    => 'center',
      };
      $row->{chart}->{data}       = $chart->accno;
      $row->{description}->{data} = $chart->description;
      if ( $balance > 0 ) {
        $row->{saldo}->{data} = $::form->format_amount(\%::myconfig, $balance, 2)." H";
      } elsif ( $balance < 0 )  {
        $row->{saldo}->{data} = $::form->format_amount(\%::myconfig,-$balance, 2)." S";
      } else {
        $row->{saldo}->{data} = $::form->format_amount(\%::myconfig,0, 2)."  ";
      }
      my $sum_cb = 0;
      foreach my $acc ( @{ SL::DB::Manager::AccTransaction->get_all(where => [ chart_id  => $chart->id, cb_transaction => 't',
                                                                               transdate => { ge => $self->cb_startdate},
                                                                               transdate => { le => $self->cb_date }
                                                                             ]) }) {
        $sum_cb += $acc->amount;
      }
      my $sum_ob = 0;
      foreach my $acc ( @{ SL::DB::Manager::AccTransaction->get_all(where => [ chart_id  => $chart->id, ob_transaction => 't',
                                                                               transdate => { ge => $self->ob_date},
                                                                               transdate => { le => $ob_next_date }
                                                                             ]) }) {
        $sum_ob += $acc->amount;
      }
      if ( $sum_cb > 0 ) {
        $row->{sum_cb}->{data} = $::form->format_amount(\%::myconfig, $sum_cb, 2)." H";
      } elsif ( $sum_cb < 0 )  {
        $row->{sum_cb}->{data} = $::form->format_amount(\%::myconfig,-$sum_cb, 2)." S";
      } else {
        $row->{sum_cb}->{data} = $::form->format_amount(\%::myconfig,0, 2)."  ";
      }
      if ( $sum_ob > 0 ) {
        $row->{sum_ob}->{data} = $::form->format_amount(\%::myconfig, $sum_ob, 2)." H";
      } elsif ( $sum_ob < 0 )  {
        $row->{sum_ob}->{data} = $::form->format_amount(\%::myconfig,-$sum_ob, 2)." S";
      } else {
        $row->{sum_ob}->{data} = $::form->format_amount(\%::myconfig,0, 2)."  ";
      }
      $report->add_data($row);
    }
    $idx++;
  }

  $self->{row_count} = $idx;
  $main::lxdebug->leave_sub();
}

sub get_balance {
  $main::lxdebug->enter_sub();
  my ($self,$chart) = @_;

  #$main::lxdebug->message(LXDebug->DEBUG2(),"get_balance from=".$self->cb_startdate->to_kivitendo." to=".$self->cb_date->to_kivitendo);
  my $balance = $chart->get_balance(fromdate => $self->cb_startdate, todate => $self->cb_date);
  $main::lxdebug->leave_sub();
  return 0 if !defined $balance || $balance == 0;
  return $balance;
}

sub gl_booking {
  my ($self, $amount, $transdate, $reference, $description, $konto, $gegenkonto, $ob, $cb) = @_;
  $::form->get_employee();
  my $employee_id = $::form->{employee_id};
  $main::lxdebug->message(LXDebug->DEBUG2(),"employee_id=".$employee_id." ob=".$ob." cb=".$cb);
  my $gl_entry = SL::DB::GLTransaction->new(
    employee_id    => $employee_id,
    transdate      => $transdate,
    reference      => $reference,
    description    => $description,
    ob_transaction => $ob,
    cb_transaction => $cb,
  );
  #$gl_entry->save;
  my $kto_trans1 = SL::DB::AccTransaction->new(
    trans_id       => $gl_entry->id,
    transdate      => $transdate,
    ob_transaction => $ob,
    cb_transaction => $cb,
    chart_id       => $gegenkonto->id,
    chart_link     => $konto->link,
    tax_id         => 0,
    taxkey         => 0,
    amount         => $amount,
  );
  #$kto_trans1->save;
  my $kto_trans2 = SL::DB::AccTransaction->new(
    trans_id       => $gl_entry->id,
    transdate      => $transdate,
    ob_transaction => $ob,
    cb_transaction => $cb,
    chart_id       => $konto->id,
    chart_link     => $konto->link,
    tax_id         => 0,
    taxkey         => 0,
    amount         => -$amount,
  );
  #$kto_trans2->save;
  $gl_entry->add_transactions($kto_trans1);
  $gl_entry->add_transactions($kto_trans2);
  $gl_entry->save;
}

sub init_cbob_chart     { $::form->{cbob_chart}                                    }
sub init_ob_date        { $::locale->parse_date_to_object($::form->{ob_date})      }
sub init_ob_reference   { $::form->{ob_reference}                                  }
sub init_ob_description { $::form->{ob_description}                                }
sub init_cb_startdate   { $::locale->parse_date_to_object($::form->{cb_startdate}) }
sub init_cb_date        { $::locale->parse_date_to_object($::form->{cb_date})      }
sub init_cb_reference   { $::form->{cb_reference}                                  }
sub init_cb_description { $::form->{cb_description}                                }

sub init_charts9000 {
  SL::DB::Manager::Chart->get_all(  query => [ accno => { like => '9%'}] );
}

sub init_charts {
  # wie geht 'not like' in rose ?
  SL::DB::Manager::Chart->get_all(  query => [ \ "accno not like '9%'"], sort_by => 'accno ASC' );
}

sub setup_filter_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Continue'),
        submit    => [ '#filter_form', { action => 'YearEndTransactions/list' } ],
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_list_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Post'),
        submit    => [ '#form', { action => 'YearEndTransactions/generate' } ],
        tooltip   => t8('generate cb/ob transactions for selected charts'),
        confirm   => t8('Are you sure to generate cb/ob transactions?'),
        accesskey => 'enter',
      ],
      action => [
        t8('Back'),
        call => [ 'kivi.history_back' ],
      ],
    );
  }
}

1;
