package SL::DB::PeriodicInvoiceItemsConfig;

use strict;

use SL::DB::MetaSetup::PeriodicInvoiceItemsConfig;
use SL::DB::Manager::PeriodicInvoiceItemsConfig;

__PACKAGE__->meta->initialize;

our %ITEM_PERIOD_LENGTHS = (  o => 0, m => 1, q => 3, b => 6, y => 12 , n => -1 );

sub get_item_period_length {
  my ($self) = @_;
  return $self->order_item->order->periodic_invoices_config->get_billing_period_length if $self->periodicity eq 'p';
  return $ITEM_PERIOD_LENGTHS{ $self->periodicity };
}

sub active {
  my ($self) = @_;
  return 0 if $self->periodicity eq 'n';
  if ($self->periodicity eq 'o') {
    return 0 if $self->once_invoice_id;
    return 1;
  }
  return 1 if !$self->end_date || (!$self->terminated && $self->extend_automatically_by);
  my $order_config = $self->order_item->order->periodic_invoices_config;
  my $last_billing_date = $order_config->get_previous_billed_period_start_date;
  if ($last_billing_date) {
    my $next_billing_date = $order_config->add_months(
      $last_billing_date, $self->get_item_period_length
    );
    return 0 if $next_billing_date > $self->end_date;
  }
  return 1;
}

1;
