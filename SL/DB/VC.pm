package SL::DB::VC;

use strict;

require Exporter;
use SL::DBUtils;

our @ISA    = qw(Exporter);
our @EXPORT = qw(get_credit_remaining);

sub get_credit_remaining {
  my $vc               = shift;
  my ($type, $arap)    = ref $vc eq 'SL::DB::Customer' ? ('customer', 'ar') : ('vendor', 'ap');
  my %params           = @_;

  my $credit_remaining = $vc->creditlimit || 0;

  my $query            = <<SQL;
    SELECT SUM(${arap}.amount - ${arap}.paid)
    FROM ${arap}
    WHERE ${type}_id = ?
SQL
  my ($amount_unpaid)  = selectfirst_array_query($::form, $vc->dbh, $query, $vc->id);
  $credit_remaining   -= $amount_unpaid;

  $query = <<SQL;
    SELECT o.amount,
      (SELECT e.buy FROM exchangerate e
       WHERE e.currency_id = o.currency_id
         AND e.transdate = o.transdate)
    FROM oe o
    WHERE (o.${type}_id = ?)
      AND NOT COALESCE(o.quotation, FALSE)
      AND NOT COALESCE(o.closed,    FALSE)
SQL

  my @values;
  if ($params{exclude_order_id}) {
    $query .= qq| AND (o.id <> ?)|;
    push @values, $params{exclude_order_id};
  }

  my $sth = prepare_execute_query($::form, $vc->dbh, $query, $vc->id, @values);

  while (my ($amount, $exch) = $sth->fetchrow_array) {
    $credit_remaining -= $amount * ($exch || 1);
  }
  $sth->finish;

  return $credit_remaining;
}

1;
