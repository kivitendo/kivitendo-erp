package SL::DB::Helper::PriceTaxCalculator;

use strict;

use parent qw(Exporter);
our @EXPORT = qw(calculate_prices_and_taxes);

use Carp;
use List::Util qw(sum);
use SL::DB::Default;
use SL::DB::PriceFactor;
use SL::DB::Unit;

sub calculate_prices_and_taxes {
  my ($self, %params) = @_;

  my $is_sales            = $self->can('customer') && $self->customer;
  my $is_invoice          = (ref($self) =~ /Invoice/) || $params{invoice};

  my %units_by_name       = map { ( $_->name => $_ ) } @{ SL::DB::Manager::Unit->get_all        };
  my %price_factors_by_id = map { ( $_->id   => $_ ) } @{ SL::DB::Manager::PriceFactor->get_all };
  my %taxes_by_chart_id   = ();
  my %amounts_by_chart_id = ();

  my %data = ( lastcost_total      => 0,
               invoicediff         => 0,
               units_by_name       => \%units_by_name,
               price_factors_by_id => \%price_factors_by_id,
               taxes_by_chart_id   => \%taxes_by_chart_id,
               amounts_by_chart_id => \%amounts_by_chart_id,
               exchangerate        => undef,
             );

  if (($self->curr || '') ne SL::DB::Default->get_default_currency) {
    $data{exchangerate}   = $::form->check_exchangerate(\%::myconfig, $self->curr, $self->transdate, $is_sales ? 'buy' : 'sell');
    $data{exchangerate} ||= $params{exchangerate};
  }
  $data{exchangerate} ||= 1;

  $self->netamount(  0);
  $self->marge_total(0);

  my $idx = 0;
  foreach my $item ($self->items) {
    $idx++;
    _calculate_item($self, $item, $idx, \%data);
  }

  my $tax_sum = sum map { _round($_, 2) } values %taxes_by_chart_id;

  $self->amount(       _round($self->netamount + $tax_sum, 2));
  $self->netamount(    _round($self->netamount,            2));
  $self->marge_percent($self->netamount ? ($self->netamount - $data{lastcost_total}) * 100 / $self->netamount : 0);

  return $self unless wantarray;
  return ( self    => $self,
           taxes   => \%taxes_by_chart_id,
           amounts => \%amounts_by_chart_id,
         );
}

sub _calculate_item {
  my ($self, $item, $idx, $data) = @_;

  my $part_unit  = $data->{units_by_name}->{ $item->part->unit };
  my $item_unit  = $data->{units_by_name}->{ $item->unit       };

  croak("Undefined unit " . $item->part->unit) if !$part_unit;
  croak("Undefined unit " . $item->unit)       if !$item_unit;

  $item->base_qty($item_unit->convert_to($item->qty, $part_unit));

  my $num_dec   = _num_decimal_places($item->sellprice);
  my $discount  = _round($item->sellprice * ($item->discount || 0), $num_dec);
  my $sellprice = _round($item->sellprice - $discount,              $num_dec);

  $item->price_factor(      ! $item->price_factor_obj   ? 1 : ($item->price_factor_obj->factor   || 1));
  $item->marge_price_factor(! $item->part->price_factor ? 1 : ($item->part->price_factor->factor || 1));
  my $linetotal = _round($sellprice * $item->qty / $item->price_factor, 2) * $data->{exchangerate};
  $linetotal    = _round($linetotal,                                    2);

  $data->{invoicediff} += $sellprice * $item->qty * $data->{exchangerate} / $item->price_factor - $linetotal;

  if (!$linetotal) {
    $item->marge_total(  0);
    $item->marge_percent(0);

  } else {
    my $lastcost = ! ($item->lastcost * 1) ? ($item->part->lastcost || 0) : $item->lastcost;

    $item->marge_total(  $linetotal - $lastcost / $item->marge_price_factor);
    $item->marge_percent($item->marge_total * 100 / $linetotal);

    $self->marge_total(  $self->marge_total + $item->marge_total);
    $data->{lastcost_total} += $lastcost;
  }

  my $taxkey     = $item->part->get_taxkey(date => $self->transdate, is_sales => $data->{is_sales}, taxzone => $self->taxzone_id);
  my $tax_rate   = $taxkey->tax->rate;
  my $tax_amount = undef;

  if ($self->taxincluded) {
    $tax_amount = $linetotal * $tax_rate / ($tax_rate + 1);
    $sellprice  = $sellprice             / ($tax_rate + 1);

  } else {
    $tax_amount = $linetotal * $tax_rate;
  }

  $data->{taxes_by_chart_id}->{ $taxkey->chart_id } ||= 0;
  $data->{taxes_by_chart_id}->{ $taxkey->chart_id }  += $tax_amount;

  $self->netamount($self->netamount + $sellprice * $item->qty / $item->price_factor);

  my $chart = $item->part->get_chart(type => $data->{is_sales} ? 'income' : 'expense', taxzone => $self->taxzone_id);
  $data->{amounts_by_chart_id}->{$chart->id} += $linetotal;

  if ($data->{is_invoice}) {
    if ($item->part->is_assembly) {
      # process_assembly()...
    } else {
      # cogs...
    }
  }

  $::lxdebug->message(0, "CALCULATE! ${idx} i.qty " . $item->qty . " i.sellprice " . $item->sellprice . " sellprice $sellprice taxamount $tax_amount " .
                      "i.linetotal $linetotal netamount " . $self->netamount . " marge_total " . $item->marge_total . " marge_percent " . $item->marge_percent);
}

sub _round {
  return $::form->round_amount(@_);
}

sub _num_decimal_places {
  return length( (split(/\./, '' . shift, 2))[1] || '' );
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Helper::PriceTaxCalculator - Mixin for calculating the prices,
amounts and taxes of orders, quotations, invoices

=head1 FUNCTIONS

=over 4

=item C<calculate_prices_and_taxes %params>

Calculates the prices, amounts and taxes for an order, a quotation or
an invoice. The function assumes that the mixing package has a certain
layout and provides certain functions:

=over 2

=item C<transdate>

The record's date.

=item C<customer> or C<vendor>

Determines if the record is a sales or purchase record.

=item C<items>

Accessor returning all line items for this record. The line items
themselves must again have a certain layout. Instances of
L<SL::DB::OrderItem> and L<SL::DB::InvoiceItem> are supported.

=back

The following values are calculated and set for C<$self>: C<amount>,
C<netamount>, C<marge_percent>, C<marge_total>.

The following values are calculated and set for each line item:
C<base_qty>, C<price_factor>, C<marge_price_factor>, C<marge_total>,
C<marge_percent>.

The objects are not saved.

Returns C<$self> in scalar context.

In array context a hash with the following keys is returned:

=over 2

=item C<self>

The object itself.

=item C<taxes>

A hash reference with the calculated taxes. The keys are chart IDs,
the values the calculated taxes.

=item C<amounts>

A hash reference with the calculated amounts. The keys are chart IDs,
the values the calculated amounts.

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
