use strict;
use Test::More tests => 5;

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

my $durchlaufende_posten_orig_clearing;
clear_up();

my $cash                 = SL::DB::Manager::Chart->find_by( description => 'Kasse');
my $bank                 = SL::DB::Manager::Chart->find_by( description => 'Bank' );
my $durchlaufende_posten = SL::DB::Manager::Chart->find_by( description => 'Durchlaufende Posten' ) // die "no chart durchlaufende Posten";

$durchlaufende_posten_orig_clearing = $durchlaufende_posten->clearing;
$durchlaufende_posten->clearing(1);
$durchlaufende_posten->save(changes_only => 1);
my $tax_0 = SL::DB::Manager::Tax->find_by(taxkey => 0, rate => 0.00);

my $dbh = SL::DB->client->dbh;

my $start_date = DateTime->today_local->subtract(days => 20);

my $expected_cleared_entries = 0;

quick_gl($durchlaufende_posten, 550, $bank,                 550, "abc");
quick_gl($cash,                 100, $durchlaufende_posten, 100, "abc");
quick_gl($cash,                 450, $durchlaufende_posten, 450, "abc");

my ($cg_abc);
my ($entries);
($cg_abc, $entries) = create_cleared_for_chart_and_reference($durchlaufende_posten, "abc");
$expected_cleared_entries += $entries;

is(SL::DB::Manager::Cleared->get_all_count(), $expected_cleared_entries, "$expected_cleared_entries cleared entries after creating cleared_group abc ok");

eval {
  create_cleared_for_chart_and_reference($durchlaufende_posten, "abc");
} or do {
  ok(1 == 1, "caught error when trying to clear already cleared transaction abc: ok");
};

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

# for my $i ( 2000..2005 ) {
#   quick_gl($cash, 77.77, $durchlaufende_posten, 77.77, "$i");
#   quick_gl($durchlaufende_posten, 77.77, $bank, 77.77, "$i");
# }

# my $randnum = 30;
# create_rand_entries($durchlaufende_posten, $randnum);
# die

done_testing;
clear_up();

1;

sub clear_up {
  "SL::DB::Manager::${_}"->delete_all(all => 1) for qw( ClearedGroup AccTransaction GLTransaction);
  if (defined $durchlaufende_posten_orig_clearing) {
    $durchlaufende_posten->clearing($durchlaufende_posten_orig_clearing);
    $durchlaufende_posten->save(changes_only => 1);
  }
}

sub quick_gl {
  my ($chart_credit, $amount_credit, $chart_debit, $amount_debit, $reference) = @_;

  my $gl_transaction = SL::DB::GLTransaction->new(
    taxincluded => 1,
    reference   => $reference,
    description => '1',
    transdate   => get_random_date(),
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

  my $query = 'select acc_trans_id from acc_trans where chart_id = ? and trans_id in (select id from gl where reference = ?)';
  my @acc_trans_ids = selectall_array_query($::form, $dbh, $query, $chart->id, $reference);
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
