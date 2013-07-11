package SL::DB::Helper::PriceTaxCalculator;

use strict;

use parent qw(Exporter);
our @EXPORT = qw(calculate_prices_and_taxes);

use Carp;
use List::Util qw(sum min);

sub calculate_prices_and_taxes {
  my ($self, %params) = @_;

  require SL::DB::PriceFactor;
  require SL::DB::Unit;

  my %units_by_name       = map { ( $_->name => $_ ) } @{ SL::DB::Manager::Unit->get_all        };
  my %price_factors_by_id = map { ( $_->id   => $_ ) } @{ SL::DB::Manager::PriceFactor->get_all };

  my %data = ( lastcost_total      => 0,
               invoicediff         => 0,
               last_incex_chart_id => undef,
               units_by_name       => \%units_by_name,
               price_factors_by_id => \%price_factors_by_id,
               taxes               => { },
               amounts             => { },
               amounts_cogs        => { },
               allocated           => { },
               assembly_items      => [ ],
               exchangerate        => undef,
               is_sales            => $self->can('customer') && $self->customer,
               is_invoice          => (ref($self) =~ /Invoice/) || $params{invoice},
             );

  _get_exchangerate($self, \%data, %params);

  $self->netamount(  0);
  $self->marge_total(0);

  my $idx = 0;
  foreach my $item ($self->items) {
    $idx++;
    _calculate_item($self, $item, $idx, \%data, %params);
  }

  _calculate_amounts($self, \%data, %params);

  return $self unless wantarray;

  return map { ($_ => $data{$_}) } qw(taxes amounts amounts_cogs allocated exchangerate assembly_items);
}

sub _get_exchangerate {
  my ($self, $data, %params) = @_;
  require SL::DB::Default;

  my $currency = $self->currency_id ? $self->currency->name || '' : '';
  if ($currency ne SL::DB::Default->get_default_currency) {
    $data->{exchangerate}   = $::form->check_exchangerate(\%::myconfig, $currency, $self->transdate, $data->{is_sales} ? 'buy' : 'sell');
    $data->{exchangerate} ||= $params{exchangerate};
  }
  $data->{exchangerate} ||= 1;
}

sub _calculate_item {
  my ($self, $item, $idx, $data, %params) = @_;

  my $part_unit  = $data->{units_by_name}->{ $item->part->unit };
  my $item_unit  = $data->{units_by_name}->{ $item->unit       };

  croak("Undefined unit " . $item->part->unit) if !$part_unit;
  croak("Undefined unit " . $item->unit)       if !$item_unit;

  $item->base_qty($item_unit->convert_to($item->qty, $part_unit));
  $item->fxsellprice($item->sellprice) if $data->{is_invoice};

  my $num_dec   = _num_decimal_places($item->sellprice);
  my $discount  = _round($item->sellprice * ($item->discount || 0), $num_dec);
  my $sellprice = _round($item->sellprice - $discount,              $num_dec);

  $item->price_factor(      ! $item->price_factor_obj   ? 1 : ($item->price_factor_obj->factor   || 1));
  $item->marge_price_factor(! $item->part->price_factor ? 1 : ($item->part->price_factor->factor || 1));
  my $linetotal = _round($sellprice * $item->qty / $item->price_factor, 2) * $data->{exchangerate};
  $linetotal    = _round($linetotal,                                    2);

  $data->{invoicediff} += $sellprice * $item->qty * $data->{exchangerate} / $item->price_factor - $linetotal if $self->taxincluded;

  if (!$linetotal) {
    $item->marge_total(  0);
    $item->marge_percent(0);

  } else {
    my $lastcost       = ! ($item->lastcost * 1) ? ($item->part->lastcost || 0) : $item->lastcost;
    my $linetotal_cost = _round($lastcost * $item->qty / $item->marge_price_factor, 2);

    $item->marge_total(  $linetotal - $linetotal_cost);
    $item->marge_percent($item->marge_total * 100 / $linetotal);

    $self->marge_total(  $self->marge_total + $item->marge_total);
    $data->{lastcost_total} += $linetotal_cost;
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

  if ($taxkey->tax->chart_id) {
    $data->{taxes}->{ $taxkey->tax->chart_id } ||= 0;
    $data->{taxes}->{ $taxkey->tax->chart_id }  += $tax_amount;
  } elsif ($tax_amount) {
    die "tax_amount != 0 but no chart_id for taxkey " . $taxkey->id . " tax " . $taxkey->tax->id;
  }

  $self->netamount($self->netamount + $sellprice * $item->qty / $item->price_factor);

  my $chart = $item->part->get_chart(type => $data->{is_sales} ? 'income' : 'expense', taxzone => $self->taxzone_id);
  $data->{amounts}->{ $chart->id }           ||= { taxkey => $taxkey->taxkey_id, tax_id => $taxkey->tax_id, amount => 0 };
  $data->{amounts}->{ $chart->id }->{amount}  += $linetotal;

  push @{ $data->{assembly_items} }, [];
  if ($item->part->is_assembly) {
    _calculate_assembly_item($self, $data, $item->part, $item->base_qty, $item->unit_obj->convert_to(1, $item->part->unit_obj));
  } elsif ($item->part->is_part) {
    if ($data->{is_invoice}) {
      $item->allocated(_calculate_part_item($self, $data, $item->part, $item->base_qty, $item->unit_obj->convert_to(1, $item->part->unit_obj)));
    }
  }

  $data->{last_incex_chart_id} = $chart->id if $data->{is_sales};

  _dbg("CALCULATE! ${idx} i.qty " . $item->qty . " i.sellprice " . $item->sellprice . " sellprice $sellprice num_dec $num_dec taxamount $tax_amount " .
       "i.linetotal $linetotal netamount " . $self->netamount . " marge_total " . $item->marge_total . " marge_percent " . $item->marge_percent);
}

sub _calculate_amounts {
  my ($self, $data, %params) = @_;

  my $tax_diff = 0;
  foreach my $chart_id (keys %{ $data->{taxes} }) {
    my $rounded                  = _round($data->{taxes}->{$chart_id} * $data->{exchangerate}, 2);
    $tax_diff                   += $data->{taxes}->{$chart_id} * $data->{exchangerate} - $rounded if $self->taxincluded;
    $data->{taxes}->{$chart_id}  = $rounded;
  }

  my $amount    = _round(($self->netamount + $tax_diff) * $data->{exchangerate}, 2);
  my $diff      = $amount - ($self->netamount + $tax_diff) * $data->{exchangerate};
  my $netamount = $amount;

  if ($self->taxincluded) {
    $data->{invoicediff}                                         += $diff;
    $data->{amounts}->{ $data->{last_incex_chart_id} }->{amount} += $data->{invoicediff} if $data->{last_incex_chart_id};
  }

  _dbg("Sna " . $self->netamount . " idiff " . $data->{invoicediff} . " tdiff ${tax_diff}");

  my $tax              = sum values %{ $data->{taxes} };
  $data->{arap_amount} = $netamount + $tax;

  $self->netamount(    $netamount);
  $self->amount(       $netamount + $tax);
  $self->marge_percent($self->netamount ? ($self->netamount - $data->{lastcost_total}) * 100 / $self->netamount : 0);
}

sub _calculate_assembly_item {
  my ($self, $data, $part, $total_qty, $base_factor) = @_;

  return 0 if $::instance_conf->get_inventory_system eq 'periodic' || !$data->{is_invoice};

  foreach my $assembly_entry (@{ $part->assemblies }) {
    push @{ $data->{assembly_items}->[-1] }, { part      => $assembly_entry->part,
                                               qty       => $total_qty * $assembly_entry->qty,
                                               allocated => 0 };

    if ($assembly_entry->part->is_assembly) {
      _calculate_assembly_item($self, $data, $assembly_entry->part, $total_qty * $assembly_entry->qty);
    } elsif ($assembly_entry->part->is_part) {
      my $allocated = _calculate_part_item($self, $data, $assembly_entry->part, $total_qty * $assembly_entry->qty);
      $data->{assembly_items}->[-1]->[-1]->{allocated} = $allocated;
    }
  }
}

sub _calculate_part_item {
  my ($self, $data, $part, $total_qty, $base_factor) = @_;

  _dbg("cpsi tq " . $total_qty);

  return 0 if $::instance_conf->get_inventory_system eq 'periodic' || !$data->{is_invoice} || !$total_qty;

  my ($entry);
  $base_factor           ||= 1;
  my $remaining_qty        = $total_qty;
  my $expense_income_chart = $part->get_chart(type => $data->{is_sales} ? 'expense' : 'income', taxzone => $self->taxzone_id);
  my $inventory_chart      = $part->get_chart(type => 'inventory',                              taxzone => $self->taxzone_id);

  my $iterator             = SL::DB::Manager::InvoiceItem->get_all_iterator(query => [ and => [ parts_id => $part->id,
                                                                                                \'(base_qty + allocated) < 0' ] ]);

  while (($remaining_qty > 0) && ($entry = $iterator->next)) {
    my $qty = min($remaining_qty, $entry->base_qty * -1 - $entry->allocated - $data->{allocated}->{ $entry->id });
    _dbg("qty $qty");

    next unless $qty;

    my $linetotal = _round(($entry->sellprice * $qty) / $base_factor, 2);

    $data->{amounts_cogs}->{ $expense_income_chart->id } -= $linetotal;
    $data->{amounts_cogs}->{ $inventory_chart->id      } += $linetotal;

    $data->{allocated}->{ $entry->id } ||= 0;
    $data->{allocated}->{ $entry->id }  += $qty;
    $remaining_qty                      -= $qty;
  }

  $iterator->finish;

  return $remaining_qty - $total_qty;
}

sub _round {
  return $::form->round_amount(@_);
}

sub _num_decimal_places {
  return length( (split(/\./, '' . ($_[0] * 1), 2))[1] || '' );
}

sub _dbg {
  # $::lxdebug->message(0, join(' ', @_));
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
an invoice.

The function assumes that the mixing package has a certain layout and
provides certain functions:

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

=item C<taxes>

A hash reference with the calculated taxes. The keys are chart IDs,
the values the calculated taxes.

=item C<amounts>

A hash reference with the calculated amounts. The keys are chart IDs,
the values are hash references containing the two keys C<amount> and
C<taxkey>.

=item C<amounts_cogs>

A hash reference with the calculated amounts for costs of goods
sold. The keys are chart IDs, the values the calculated amounts.

=item C<assembly_items>

An array reference with as many entries as there are items in the
record. Each entry is again an array reference of hash references with
the keys C<part> (an instance of L<SL::DB::Part>), C<qty> and
C<allocated>. Is only valid for invoices and can be used to populate
the C<invoice> table with entries for assemblies.

=item C<allocated>

A hash reference. The keys are IDs of entries in the C<invoice>
table. The values are the new values for the entry's C<allocated>
column. Only valid for invoices.

=item C<exchangerate>

The exchangerate used for the calculation.

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
