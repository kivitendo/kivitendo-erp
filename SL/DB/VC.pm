package SL::DB::VC;

use strict;

use List::MoreUtils qw(uniq);
use SL::DBUtils;

require Exporter;

our @ISA    = qw(Exporter);
our @EXPORT = qw(get_credit_remaining get_all_email_addresses);

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

sub get_all_email_addresses {
  my ($self) = @_;

  my $is_sales = ref $self eq 'SL::DB::Customer';

  my @addresses;

  # billing address
  push @addresses, $self->$_ for qw(email cc bcc);
  if ($is_sales) {
    push @addresses, $self->$_ for qw(delivery_order_mail invoice_mail);
  }

  # additional billing addresses
  if ($is_sales) {
    foreach my $additional_billing_address (@{ $self->additional_billing_addresses }) {
      push @addresses, $additional_billing_address->$_ for qw(email);
    }
  }

  # contacts
  foreach my $contact (@{ $self->contacts }) {
    push @addresses, $contact->$_ for qw(cp_email cp_privatemail);
  }

  # shiptos
  foreach my $shipto (@{ $self->shipto }) {
    push @addresses, $shipto->$_ for qw(shiptoemail);
  }

  # remove empty ones and duplicates
  @addresses = grep { $_ } @addresses;
  @addresses = uniq @addresses;


  return \@addresses;
}

1;
