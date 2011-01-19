package SL::DB::Helper::PriceUpdater;

use strict;

use parent qw(Exporter);
our @EXPORT = qw(update_prices);

use Carp;

sub update_prices {
  my $self   = shift;
  my %params = @_;

  croak('Missing parameters amount/percent') unless $params{amount} || $params{percent};

  my @prices = ref $params{prices} eq 'ARRAY' ? @{ $params{prices} } : ( $params{prices} || 'sellprice' );

  foreach my $field (@prices) {
    my $rounding_error = 0;

    foreach my $item (@{ $self->items }) {
      my $new_price;
      if ($params{amount}) {
        $new_price = $item->$field + $params{amount}        + $rounding_error;
      } else {
        $new_price = $item->$field * $params{percent} / 100 + $rounding_error;
      }

      $item->$field($::form->round_amount($new_price, 2));
      $rounding_error += $new_price - $item->$field;

      _dbg("new_price $new_price new_price_no_err " . ($new_price - $rounding_error) . " rounded " . $item->$field .
           " error_old " . ($rounding_error - $new_price + $item->$field) . " error_new $rounding_error");
    }
  }

  return $self->calculate_prices_and_taxes if $params{calculate};
  return $self;
}

sub _dbg {
  # $::lxdebug->message(0, __PACKAGE__ . ': ' . join(' ', @_));
}

1;

__END__

=encoding utf8

=head1 NAME

SL::DB::Helper::PriceUpdater - Mixin for updating all prices by a fixed amount or by a percentage

=head1 FUNCTIONS

=over 4

=item C<update_prices %params>

Updates the prices of all items as returned by the function C<items>
provided by the mixing class.

Supported arguments via C<%params> are:

=over 2

=item C<amount>

Absolute amount to add or subtract. Either C<amount> or C<percent>
must be given. Resulting prices are rounded to two significant places.

=item C<percent>

Percentage to set the prices to (with 100 meaning "no
change"). Resulting prices are rounded to two significant
places. Rounding errors are carried over to the next item.

Either C<amount> or C<percent> must be given.

=item C<prices>

A string or an array of strings naming the prices to update. If
missing only the C<sellprice> field will be updated.

=item C<calculate>

If trueish the all prices, taxes and amounts are re-calculated by
calling
L<SL::DB::Helper::PriceTaxCalculator::calculate_prices_and_taxes>.
Returns that function's result.

=back

Returns C<$self> unless C<$params{calculate}> is trueish.

=back

=head1 EXPORTS

This mixin exports the function L</update_prices>.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
