package SL::Controller::Clearing;

use strict;

use parent qw(SL::Controller::Base);

use SL::Clearing;
use SL::Helper::DateTime;
use SL::DB::Chart;
use SL::DB::ClearedGroup;
use SL::DB::Department;
use SL::DBUtils qw(selectall_array_query);
use SL::Locale::String qw(t8);

use List::MoreUtils qw(any);

use Rose::Object::MakeMethods::Generic (
  'scalar'                => [ qw(chart fromdate todate project_id department_id load_cleared) ],
  'scalar --get_set_init' => [ qw(all_departments limit) ],
);

__PACKAGE__->run_before('check_auth');

#
# actions
#

sub action_form {
  my ($self) = @_;

  $self->parse_filter;

  if ($self->chart && !$self->chart->clearing) {
    return $self->render('clearing/chart_missing', title => t8('Clear bookings'));
  }

  $self->setup_form_action_bar;
  $::request->layout->use_javascript('kivi.Clearing.js');

  $self->render('clearing/form', title => t8('Clear bookings'));
}

sub action_list {
  my ($self) = @_;

  $self->parse_filter;

  if (!$self->chart) {
    return $self->js
      ->html('#clearing_list', '')
      ->flash('error', t8('No chart selected'))
      ->render;
  }

  if (!$self->chart->clearing) {
    return $self->js
      ->html('#clearing_list', '')
      ->flash('error', t8('Clearing is not enabled for this chart.'))
      ->render;
  }

  my $bookings = SL::Clearing::load_chart_transactions({
    chart_id      => $self->chart->id,
    fromdate      => $self->fromdate,
    todate        => $self->todate,
    project_id    => $self->project_id,
    department_id => $self->department_id,
    load_cleared  => $self->load_cleared,
    limit         => $self->limit + 1,
  });

  my $limit_exceeded = @$bookings > $self->limit;
  splice @$bookings, $self->limit if $limit_exceeded;

  my $html = $self->render('clearing/_list', { output => 0 },
    bookings => $bookings,
    sums     => $self->prepare_bookings($bookings),
  );

  $self->js
    ->html('#clearing_list', $html)
    ->run('kivi.Clearing.init_list');

  $self->js->flash('warning', t8('Only the first #1 bookings are shown. Please narrow down the filter.', $self->limit))
    if $limit_exceeded;

  $self->js->render;
}

sub action_create_cleared_group {
  my ($self) = @_;

  my @acc_trans_ids = grep { m/^\d+$/ } @{ $::form->{acc_trans_ids} || [] };

  my $cleared_group = eval { SL::Clearing::create_cleared_group(\@acc_trans_ids) };
  if (!$cleared_group) {
    $::lxdebug->message(LXDebug::WARN(), "Clearing: $@");
    return $self->js->flash('error', t8('The bookings could not be cleared.'))->render;
  }

  $self->js
    ->run('kivi.Clearing.mark_cleared', $cleared_group->id, \@acc_trans_ids)
    ->flash('info', t8('Cleared bookings'))
    ->render;
}

sub action_show_cleared_group {
  my ($self) = @_;

  my $cleared_group = $self->load_cleared_group;
  my $bookings      = SL::Clearing::load_cleared_group_transactions_by_group_id($cleared_group->id);

  $self->render('clearing/_cleared_group', { layout => 0 },
    cleared_group => $cleared_group,
    cleared_at    => $::locale->format_date_object($cleared_group->itime, precision => 'seconds'),
    bookings      => $bookings,
    sums          => $self->prepare_bookings($bookings),
  );
}

sub action_remove_cleared_group {
  my ($self) = @_;

  my $cleared_group = $self->load_cleared_group;
  my $id            = $cleared_group->id;

  if (!eval { SL::Clearing::remove_cleared_group($id); 1 }) {
    $::lxdebug->message(LXDebug::WARN(), "Clearing: $@");
    return $self->js->flash('error', t8('The clearing could not be undone.'))->render;
  }

  $self->js
    ->dialog->close('#clearing_group_dialog')
    ->run('kivi.Clearing.mark_uncleared', $id)
    ->flash('info', t8('Removed cleared group'))
    ->render;
}

#
# filters
#

sub check_auth {
  $::auth->assert('general_ledger');
}

#
# helpers
#

sub init_all_departments { SL::DB::Manager::Department->get_all_sorted }

sub init_limit { 1500 }

sub parse_filter {
  my ($self) = @_;

  my $filter = $::form->{filter} || {};

  # accno is used by the link from the chart's list of transactions (ca.pl)
  if ($::form->{accno}) {
    $self->chart(SL::DB::Manager::Chart->find_by(accno => $::form->{accno}));
  } elsif ($filter->{chart_id} || $::form->{chart_id}) {
    $self->chart(SL::DB::Manager::Chart->find_by(id => $filter->{chart_id} || $::form->{chart_id}));
  }

  my $fromdate = $filter->{fromdate} || $::form->{fromdate};
  my $todate   = $filter->{todate}   || $::form->{todate};
  $self->fromdate($::locale->parse_date_to_object($fromdate)) if $fromdate;
  $self->todate(  $::locale->parse_date_to_object($todate))   if $todate;

  $self->project_id(   $filter->{project_id}    || $::form->{project_id});
  $self->department_id($filter->{department_id} || $::form->{department_id});
  $self->load_cleared( $filter->{load_cleared}  ? 1 : 0);
}

# adds formatted date and record link to each booking, returns the sums
sub prepare_bookings {
  my ($self, $bookings) = @_;

  my %scripts = (
    gl => [ 'gl.pl', 'gl.pl' ],
    ar => [ 'ar.pl', 'is.pl' ],
    ap => [ 'ap.pl', 'ir.pl' ],
  );

  my %sums = (debit => 0, credit => 0);
  foreach my $booking (@$bookings) {
    # dates are returned in the user's date format
    my $transdate                   = $::locale->parse_date_to_object($booking->{transdate});
    $booking->{transdate_formatted} = $transdate->to_kivitendo;
    $booking->{transdate_iso}       = $transdate->ymd;
    $booking->{record_url}          = $scripts{ $booking->{record_type} }->[ $booking->{invoice} ? 1 : 0 ] . '?action=edit&id=' . $booking->{trans_id};

    $sums{debit}  += $booking->{debit}  // 0;
    $sums{credit} += $booking->{credit} // 0;
  }
  $sums{balance} = $sums{credit} - $sums{debit};

  return \%sums;
}

sub load_cleared_group {
  my ($self) = @_;

  my $cleared_group = SL::DB::Manager::ClearedGroup->find_by(id => $::form->{cleared_group_id})
    or die t8('The cleared group does not exist anymore.');

  # only groups of charts enabled for clearing may be viewed and changed
  my @chart_ids = selectall_array_query($::form, SL::DB->client->dbh, <<SQL, $cleared_group->id);
    SELECT DISTINCT a.chart_id
      FROM acc_trans a
      JOIN cleared c ON (c.acc_trans_id = a.acc_trans_id)
     WHERE c.cleared_group_id = ?
SQL
  my $charts = @chart_ids ? SL::DB::Manager::Chart->get_all(where => [ id => \@chart_ids ]) : [];
  die "invalid cleared group" if !@$charts || any { !$_->clearing } @$charts;

  return $cleared_group;
}

sub setup_form_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        call      => [ 'kivi.Clearing.load_list' ],
      ],
      action => [
        t8('Clear bookings'),
        id       => 'clearing_create_button',
        call     => [ 'kivi.Clearing.create_cleared_group' ],
        disabled => t8('Select at least two bookings whose amounts add up to 0.'),
      ],
      combobox => [
        action => [ t8('Booking selection') ],
        action => [
          t8('Select all shown bookings'),
          call => [ 'kivi.Clearing.select_all_visible' ],
        ],
        action => [
          t8('Reset selection'),
          call => [ 'kivi.Clearing.deselect_all' ],
        ],
        action => [
          t8('Reset column filters'),
          call => [ 'kivi.Clearing.reset_column_filters' ],
        ],
      ],
    );
  }
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::Clearing - User interface for clearing bookings on a chart

=head1 OVERVIEW

The form (C<action_form>) shows a filter for the chart and the period. The
bookings are loaded by C<action_list>, which renders the table and inserts
it into the page via L<SL::ClientJS>. Selecting, filtering and summing up
bookings in the table is done by C<js/kivi.Clearing.js> without a round
trip to the server. See L<SL::Clearing> for the business logic.

=head1 ACTIONS

=over 4

=item C<form>

Renders the page. Accepts C<accno> or C<chart_id> and C<fromdate>,
C<todate>, so the chart's list of transactions (C<ca.pl>) can link to it.

=item C<list>

Renders the bookings of the chart according to C<filter.*> into
C<#clearing_list>. At most C<limit> (1500) bookings are loaded; a warning is shown
if there are more.

=item C<create_cleared_group>

Clears the bookings given as C<acc_trans_ids[]> and marks them as cleared
in the table.

=item C<show_cleared_group>

Renders the content of the dialog showing a cleared group
(C<cleared_group_id>).

=item C<remove_cleared_group>

Undoes the clearing of the group C<cleared_group_id>.

=back

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitec.deE<gt>

=cut
