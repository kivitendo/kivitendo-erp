package SL::POS::Receipt;

use strict;
use warnings;

sub load_receipt_by_ar_id {
  my ($ar_id) = @_;

  my $ar = SL::DB::Invoice->new(id => $ar_id)->load;
  my $tse_transaction = SL::DB::Manager::TSETransaction->find_by(ar_id => $ar_id);
  die "invoice has no tse_transaction" unless $tse_transaction;

  my @items = map {
    {
      item => $_->description,
      qty => $_->qty,
      sellprice => $_->sellprice,
    }
  } $ar->items;

  {
    items => \@items,
    salesman => $ar->employee->name,  # TODO: store normalised
    signature => $tse_transaction->signature,
    sig_counter => $tse_transaction->sig_counter,
    start_timestamp => $tse_transaction->formatted_start_time,
    finish_timestamp => $tse_transaction->formatted_finish_time,
    client_id => $tse_transaction->client_id,
    pos_serial_number => $tse_transaction->pos_serial_number,
    # TODO:
    # formatted date and time
  }
}

1;
