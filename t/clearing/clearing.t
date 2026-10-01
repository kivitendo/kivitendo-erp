use strict;
use Test::More;

use lib 't';
use Support::TestSetup;
use Test::Exception;

use SL::DB::Chart;
use SL::DB::TaxKey;
use SL::DB::GLTransaction;
use SL::DB::Cleared;
use SL::DB::ClearedGroup;

use SL::DBUtils qw(selectall_hashref_query selectall_array_query);
use SL::Clearing;

use Data::Dumper;

Support::TestSetup::login();

my (%orig_clearing, @clearing_charts);
clear_up();

my $cash                 = SL::DB::Manager::Chart->find_by( description => 'Kasse');
my $bank                 = SL::DB::Manager::Chart->find_by( description => 'Bank' );
my $durchlaufende_posten = SL::DB::Manager::Chart->find_by( description => 'Durchlaufende Posten' ) // die "no chart durchlaufende Posten";
my $geldtransit          = SL::DB::Manager::Chart->find_by( description => 'Geldtransit' )          // die "no chart Geldtransit";

@clearing_charts = ($durchlaufende_posten, $geldtransit);
foreach my $chart (@clearing_charts) {
  $orig_clearing{$chart->id} = $chart->clearing;
  $chart->clearing(1);
  $chart->save(changes_only => 1);
}
my $tax_0 = SL::DB::Manager::Tax->find_by(taxkey => 0, rate => 0.00);

my $dbh = SL::DB->client->dbh;

my $start_date = DateTime->today_local->subtract(days => 20);

my $expected_cleared_entries = 0;

#
# create_cleared_group and remove_cleared_group
#

quick_gl($durchlaufende_posten, 550, $bank,                 550, "abc");
quick_gl($cash,                 100, $durchlaufende_posten, 100, "abc");
quick_gl($cash,                 450, $durchlaufende_posten, 450, "abc");

my ($cg_abc, $entries) = create_cleared_for_chart_and_reference($durchlaufende_posten, "abc");
$expected_cleared_entries += $entries;

isa_ok($cg_abc, 'SL::DB::ClearedGroup', 'create_cleared_group returns the cleared group');
is($cg_abc->employee_id, SL::DB::Manager::Employee->current->id, 'cleared group belongs to the current employee');
is(SL::DB::Manager::Cleared->get_all_count(), $expected_cleared_entries, "$expected_cleared_entries cleared entries after creating cleared_group abc ok");

throws_ok { create_cleared_for_chart_and_reference($durchlaufende_posten, "abc") } qr/already been cleared/, 'clearing already cleared bookings fails';
is(SL::DB::Manager::Cleared->get_all_count(), $expected_cleared_entries, "$expected_cleared_entries cleared entries after failing cleared_group abc ok");

quick_gl($durchlaufende_posten, 55, $bank,                 55, "xyz");
quick_gl($cash,                 55, $durchlaufende_posten, 55, "xyz");
my $cg_xyz;
($cg_xyz, $entries) = create_cleared_for_chart_and_reference($durchlaufende_posten, "xyz");
$expected_cleared_entries += $entries;
is(SL::DB::Manager::Cleared->get_all_count(), $expected_cleared_entries, "$expected_cleared_entries cleared entries after creating cleared_group xyz");

SL::Clearing::remove_cleared_group($cg_abc->id);
$expected_cleared_entries -= 3;

is(SL::DB::Manager::Cleared->get_all_count(), $expected_cleared_entries, "$expected_cleared_entries cleared entries after unclearing group abc ok");

#
# validation
#

quick_gl($durchlaufende_posten, 30, $bank,                 30, "unbalanced");
quick_gl($cash,                 20, $durchlaufende_posten, 20, "unbalanced");
throws_ok { create_cleared_for_chart_and_reference($durchlaufende_posten, "unbalanced") } qr/sum isn't 0/, 'clearing bookings whose sum is not 0 fails';

my @single = acc_trans_ids_for($durchlaufende_posten, "unbalanced");
throws_ok { SL::Clearing::create_cleared_group([ $single[0] ]) } qr/need at least 2/, 'clearing a single booking fails';
throws_ok { SL::Clearing::create_cleared_group([]) }             qr/need at least 2/, 'clearing no bookings fails';
throws_ok { SL::Clearing::create_cleared_group([ 999999998, 999999999 ]) } qr/no acc_trans selected/, 'clearing unknown bookings fails';

# both bookings of one gl transaction: sum is 0, but different charts
quick_gl($geldtransit, 40, $durchlaufende_posten, 40, "two charts");
my @two_charts = selectall_array_query($::form, $dbh, 'SELECT acc_trans_id FROM acc_trans WHERE trans_id IN (SELECT id FROM gl WHERE reference = ?)', "two charts");
throws_ok { SL::Clearing::create_cleared_group(\@two_charts) } qr/same chart/, 'clearing bookings of different charts fails';

quick_gl($cash, 15, $bank, 15, "no clearing chart");
quick_gl($bank, 15, $cash, 15, "no clearing chart");
throws_ok { create_cleared_for_chart_and_reference($cash, "no clearing chart") } qr/configured for clearing/, 'clearing bookings of a chart not enabled for clearing fails';

is(SL::DB::Manager::Cleared->get_all_count(), $expected_cleared_entries, "$expected_cleared_entries cleared entries after failed validations ok");

#
# trigger dissolving cleared groups
#

# deleting a cleared booking (e.g. when an invoice is posted again) dissolves its whole cleared group
my ($xyz_acc_trans_id) = map { $_->acc_trans_id } @{ SL::DB::Manager::Cleared->get_all(where => [ cleared_group_id => $cg_xyz->id ], limit => 1) };
$dbh->do('DELETE FROM acc_trans WHERE acc_trans_id = ?', undef, $xyz_acc_trans_id);
$expected_cleared_entries -= 2;

is(SL::DB::Manager::ClearedGroup->get_all_count(where => [ id => $cg_xyz->id ]), 0, "cleared group xyz dissolved after deleting one of its bookings");
is(SL::DB::Manager::Cleared->get_all_count(), $expected_cleared_entries, "$expected_cleared_entries cleared entries after deleting a cleared booking ok");

quick_gl($durchlaufende_posten, 70, $bank,                 70, "update");
quick_gl($cash,                 70, $durchlaufende_posten, 70, "update");
my ($cg_update) = create_cleared_for_chart_and_reference($durchlaufende_posten, "update");
my ($update_acc_trans_id) = acc_trans_ids_for($durchlaufende_posten, "update");

$dbh->do('UPDATE acc_trans SET memo = ? WHERE acc_trans_id = ?', undef, 'changed memo', $update_acc_trans_id);
is(SL::DB::Manager::ClearedGroup->get_all_count(where => [ id => $cg_update->id ]), 1, "cleared group kept after changing the memo of a cleared booking");

$dbh->do('UPDATE acc_trans SET amount = amount * 2 WHERE acc_trans_id = ?', undef, $update_acc_trans_id);
is(SL::DB::Manager::ClearedGroup->get_all_count(where => [ id => $cg_update->id ]), 0, "cleared group dissolved after changing the amount of a cleared booking");

quick_gl($durchlaufende_posten, 80, $bank,                 80, "chart change");
quick_gl($cash,                 80, $durchlaufende_posten, 80, "chart change");
my ($cg_chart_change) = create_cleared_for_chart_and_reference($durchlaufende_posten, "chart change");
my ($chart_change_acc_trans_id) = acc_trans_ids_for($durchlaufende_posten, "chart change");

$dbh->do('UPDATE acc_trans SET chart_id = ? WHERE acc_trans_id = ?', undef, $geldtransit->id, $chart_change_acc_trans_id);
is(SL::DB::Manager::ClearedGroup->get_all_count(where => [ id => $cg_chart_change->id ]), 0, "cleared group dissolved after changing the chart of a cleared booking");

#
# load_chart_transactions
#

clear_up_bookings();

my $day = DateTime->new(year => 2025, month => 3, day => 10);
quick_gl($durchlaufende_posten, 100, $bank,                 100, "load 1", $day->clone);
quick_gl($cash,                 100, $durchlaufende_posten, 100, "load 1", $day->clone->add(days => 5));
quick_gl($durchlaufende_posten,  25, $bank,                  25, "load 2", $day->clone->add(days => 10));

my $loaded = SL::Clearing::load_chart_transactions({ chart_id => $durchlaufende_posten->id });
is(scalar @$loaded, 3, 'load_chart_transactions: all uncleared bookings of the chart');

my ($credit_booking) = grep { $_->{reference} eq 'load 2' } @$loaded;
is($credit_booking->{record_type},        'gl',          'load_chart_transactions: record type');
ok(!$credit_booking->{invoice},                          'load_chart_transactions: gl booking is no invoice');
is($credit_booking->{credit} * 1,         25,            'load_chart_transactions: credit');
is($credit_booking->{debit},              undef,         'load_chart_transactions: no debit for a credit booking');
is($credit_booking->{gegen_chart_accnos}, $bank->accno,  'load_chart_transactions: contra chart');

my ($cg_load) = create_cleared_for_chart_and_reference($durchlaufende_posten, "load 1");

$loaded = SL::Clearing::load_chart_transactions({ chart_id => $durchlaufende_posten->id });
is_deeply([ map { $_->{reference} } @$loaded ], [ 'load 2' ], 'load_chart_transactions: cleared bookings are hidden by default');

$loaded = SL::Clearing::load_chart_transactions({ chart_id => $durchlaufende_posten->id, load_cleared => 1 });
is(scalar @$loaded, 3, 'load_chart_transactions: load_cleared also returns cleared bookings');
is(scalar(grep { ($_->{cleared_group_id} // 0) == $cg_load->id } @$loaded), 2, 'load_chart_transactions: cleared bookings carry their cleared group');

$loaded = SL::Clearing::load_chart_transactions({
  chart_id     => $durchlaufende_posten->id,
  load_cleared => 1,
  fromdate     => $day->clone->add(days => 1),
  todate       => $day->clone->add(days => 6),
});
is_deeply([ map { $_->{reference} } @$loaded ], [ 'load 1' ], 'load_chart_transactions: fromdate and todate');

$loaded = SL::Clearing::load_chart_transactions({ chart_id => $durchlaufende_posten->id, load_cleared => 1, limit => 2 });
is(scalar @$loaded, 2, 'load_chart_transactions: limit');

throws_ok { SL::Clearing::load_chart_transactions({}) } qr/missing chart_id/, 'load_chart_transactions: chart_id is mandatory';

#
# load_cleared_group_transactions_by_group_id
#

my $group_bookings = SL::Clearing::load_cleared_group_transactions_by_group_id($cg_load->id);
is(scalar @$group_bookings, 2, 'load_cleared_group_transactions_by_group_id: all bookings of the group');
is(scalar(grep { $_->{cleared_group_id} == $cg_load->id } @$group_bookings), 2, 'load_cleared_group_transactions_by_group_id: bookings belong to the group');
ok($group_bookings->[0]{itime},    'load_cleared_group_transactions_by_group_id: time of clearing');
ok($group_bookings->[0]{employee}, 'load_cleared_group_transactions_by_group_id: employee who cleared');

done_testing;
clear_up();

1;

sub clear_up_bookings {
  "SL::DB::Manager::${_}"->delete_all(all => 1) for qw( ClearedGroup AccTransaction GLTransaction);
}

sub clear_up {
  clear_up_bookings();
  foreach my $chart (@clearing_charts) {
    next unless defined $orig_clearing{$chart->id};
    $chart->clearing($orig_clearing{$chart->id});
    $chart->save(changes_only => 1);
  }
}

sub acc_trans_ids_for {
  my ($chart, $reference) = @_;

  my $query = 'select acc_trans_id from acc_trans where chart_id = ? and trans_id in (select id from gl where reference = ?) order by acc_trans_id';
  return selectall_array_query($::form, $dbh, $query, $chart->id, $reference);
}

sub quick_gl {
  my ($chart_credit, $amount_credit, $chart_debit, $amount_debit, $reference, $transdate) = @_;

  my $gl_transaction = SL::DB::GLTransaction->new(
    taxincluded => 1,
    reference   => $reference,
    description => '1',
    transdate   => $transdate // get_random_date(),
  )->add_chart_booking(
    chart  => $chart_credit,
    credit => $amount_credit,
    tax_id => $tax_0->id,
  )->add_chart_booking(
    chart  => $chart_debit,
    debit  => $amount_debit,
    tax_id => $tax_0->id,
  )->post;
}

sub quick_gl_multi {
  my ($chart_credit, $amount_credit, $chart_debit, $amount_debit, $reference) = @_;

  my $gl_transaction = SL::DB::GLTransaction->new(
    taxincluded => 1,
    reference   => $reference,
    description => '1',
    transdate   => get_random_date(),
  );

  my $rand_diff = int(rand($amount_credit)*100)/100;
  $rand_diff = 1 unless $rand_diff > 0;
  # printf("credit = %s   debit = %s   rand_diff = %s\n", $amount_credit, $amount_debit, $rand_diff);
  if ( rand(1) > 0.5 ) {
    # several credit
    $gl_transaction->add_chart_booking(
      chart  => $chart_credit,
      credit => $amount_credit-$rand_diff,
      tax_id => $tax_0->id,
    );

    $gl_transaction->add_chart_booking(
      chart  => $chart_credit,
      credit => $rand_diff,
      tax_id => $tax_0->id,
    );

    $gl_transaction->add_chart_booking(
      chart  => $chart_debit,
      debit  => $amount_debit,
      tax_id => $tax_0->id,
    );


  } else {
    # several debit
    $gl_transaction->add_chart_booking(
      chart  => $chart_credit,
      credit => $amount_credit,
      tax_id => $tax_0->id,
    );
    $gl_transaction->add_chart_booking(
      chart  => $chart_debit,
      debit  => $amount_debit-$rand_diff,
      tax_id => $tax_0->id,
    );
    $gl_transaction->add_chart_booking(
      chart  => $chart_debit,
      debit  => $rand_diff,
      tax_id => $tax_0->id,
    );
  }

  $gl_transaction->post;
}

sub create_cleared_for_chart_and_reference {
  my ($chart, $reference) = @_;

  my @acc_trans_ids = acc_trans_ids_for($chart, $reference);
  my $cg = SL::Clearing::create_cleared_group(\@acc_trans_ids);
  ($cg, scalar @acc_trans_ids);  # return cleared_group and expected number of acc_trans_ids (for testing)
}

sub get_next_date {
  return $start_date->add(days => 1);
}

sub get_random_date {
  my ($max_subtract_days, $max_add_days) = @_;

  $max_subtract_days //= 30;
  $max_add_days      //=  0;

  my $span = $max_subtract_days + $max_add_days;
  my $rand = int(rand($span));

  return DateTime->today_local->subtract( days => $max_subtract_days )->add( days => $rand );
}

sub create_rand_entries {
  my $chart = shift;
  my $i = shift // 40;

  my $single_prob = 0.3;
  my $mult_prob = 0.3;
  # create lots of random entries
  for my $i ( 1000 .. (1000+$i) ) {
    my $amount = int(rand(99))+1 + (int(rand(99))+1)/100;

    quick_gl($bank, $amount, $chart, $amount, $i);
    my $rand = rand(1);
    if ( $rand < 0.3 ) {
      # most entries will be clearable
      quick_gl($chart, $amount, $bank, $amount, $i);
      if ( rand(1) > 0.6 ) {
        # some of the entries will already be set as cleared
        $expected_cleared_entries += create_cleared_for_chart_and_reference($chart, "$i");
      }
    } elsif ( $rand < ($single_prob + $mult_prob) ) {
      quick_gl_multi($chart, $amount, $bank, $amount, $i);
      if ( rand(1) > 0.6 ) {
        # some of the entries will already be set as cleared
        $expected_cleared_entries += create_cleared_for_chart_and_reference($chart, "$i");
      }
    } else {
      # no matching booking
    }
  }
}
