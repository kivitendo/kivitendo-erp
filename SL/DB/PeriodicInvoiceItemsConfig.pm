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

1;
