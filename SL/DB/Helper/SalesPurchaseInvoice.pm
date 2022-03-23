package SL::DB::Helper::SalesPurchaseInvoice;

use strict;
use utf8;

use parent qw(Exporter);
our @EXPORT = qw(get_tax_and_amount_by_tax_chart_id);

sub get_tax_and_amount_by_tax_chart_id {
  my ($self) = @_;

  my $ARAP = $self->is_sales ? 'AR' : 'AP';
  my ($tax_and_amount_by_tax_id, $total);

  foreach my $transaction (@{ $self->transactions }) {
    next if $transaction->chart_link =~ m/(^${ARAP}$|paid)/;

    my $tax_or_netamount = $transaction->chart_link =~ m/tax/            ? 'tax'
                         : $transaction->chart_link =~ m/(${ARAP}_amount|IC_cogs)/ ? 'netamount'
                         : undef;
    if ($tax_or_netamount eq 'netamount') {
      $tax_and_amount_by_tax_id->{ $transaction->tax->chart_id }->{$tax_or_netamount} ||= 0;
      $tax_and_amount_by_tax_id->{ $transaction->tax->chart_id }->{$tax_or_netamount}  += $transaction->amount;
      # die "Invalid state" unless $tax_and_amount_by_tax_id->{ $transaction->tax->chart_id }->{tax_id} == 0
      $tax_and_amount_by_tax_id->{ $transaction->tax->chart_id }->{tax_id}              = $transaction->tax_id;
    } elsif ($tax_or_netamount eq 'tax') {
      $tax_and_amount_by_tax_id->{ $transaction->chart_id }->{$tax_or_netamount} ||= 0;
      $tax_and_amount_by_tax_id->{ $transaction->chart_id }->{$tax_or_netamount}  += $transaction->amount;
    } else {
      die "Invalid chart link at: " . $transaction->chart_link unless $tax_or_netamount;
    }
    $total ||= 0;
    $total  += $transaction->amount;
  }
  die "Invalid calculated amount. Calc: $total Amount: " . abs($self->amount) if abs($total) - abs($self->amount) > 0.001;
  return $tax_and_amount_by_tax_id;
}



1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Helper::SalesPurchaseInvoice - Helper functions for Sales or Purchase bookings (mirrored)

Delivers the booked amounts split by net amount and tax amount for one ar or ap transaction
as persisted in the table acc_trans.
Should be rounding or calculation error prone because all values are already computed before
the values are written in the acc_trans table.

That is the main purpose for this helper class.
=head1 FUNCTIONS

=over 4

=item C<get_tax_and_amount_by_tax_chart_id>

Iterates over all transactions for one distinct ar or ap transaction (trans_id in acc_trans) and
groups the amounts in relation to distinct tax (tax.id) and net amounts (sums all bookings with
_cogs or _amount chart links).
Returns a hashref with the chart_id of the tax entry as key like this:

 '775' => {
    'tax_id'    => 777
    'tax'       => '332.18',
    'netamount' => '1748.32',
  },

 '194' => {
    'tax_id'    => 378,
    'netamount' => '20',
    'tax'       => '1.4'
  }

C<tax_id> is the id of the used tax. C<tax> ist the amount of tax booked for the whole transaction.
C<netamount> is the netamount booked with this tax.
TODO: Please note the hash key chart_id may not be unique but the entry tax_id is always unique.

As additional safety method the functions dies if the calculated sums do not match the
the whole amount of the transaction with an accuracy of two decimal places.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Jan Büren E<lt>jan@kivitendo.deE<gt>

=cut
