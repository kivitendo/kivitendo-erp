package SL::BackgroundJob::CloseOrdersIfBilled;

use strict;

use parent qw(SL::BackgroundJob::Base);

use List::Util qw(none);

use SL::ARAP;
use SL::DB::Order;
use SL::DB::Order::TypeData qw(:types);
use SL::Locale::String qw(t8);

sub run {
  my ($self, $job_obj) = @_;

  my $data      = $job_obj->data_as_hash;
  my $dry_run   = $data->{dry_run} ? 1 : 0;

  my @exclude_partsgroup_ids = (); # partsgroup ids for parts which does not need to be billed

  $data->{side} //= 'both';
  if (none { $_ eq $data->{side} } qw(sales purchase both)) {
    die "parameter 'side' as to be 'sales', 'purchase' or 'both' if given.";
  }

  my $record_types = 'both'     eq $data->{side} ? [ SALES_ORDER_TYPE(), PURCHASE_ORDER_TYPE() ]
                   : 'sales'    eq $data->{side} ? [ SALES_ORDER_TYPE() ]
                   : 'purchase' eq $data->{side} ? [ PURCHASE_ORDER_TYPE() ]
                   :                               [];

  my ($sales_order_ids_closed, $purchase_order_ids_closed) = ([], []);

  foreach my $record_type (@$record_types) {
    my $open_orders = SL::DB::Manager::Order->get_all(where => [
                                                        record_type => $record_type,
                                                        or          => [ closed => 0, closed => undef],
                                                      ]);

    my @linked_invoices;
    if (SALES_ORDER_TYPE() eq $record_type) {
      @linked_invoices =
        grep { $_->type eq 'invoice' }
        map  { @$_}
        grep { @$_ }
        map  {$_->linked_records(direction => 'to', via => 'DeliveryOrder', to => 'Invoice')} @$open_orders;
    } else {
      @linked_invoices =
        grep { $_->type eq 'purchase_invoice' }
        map  { @$_}
        grep { @$_ }
        map  {$_->linked_records(direction => 'to', via => 'DeliveryOrder', to => 'PurchaseInvoice')} @$open_orders;
    }

    my @order_ids_closed = map {
      ARAP->close_orders_if_billed(arap_id                => $_->id,
                                   table                  => (SALES_ORDER_TYPE() eq $record_type) ? 'ar' : 'ap',
                                   exclude_partsgroup_ids => \@exclude_partsgroup_ids,
                                   dry_run                => $dry_run)
    } @linked_invoices;

    if (SALES_ORDER_TYPE() eq $record_type) {
      $sales_order_ids_closed    = \@order_ids_closed;
    } else {
      $purchase_order_ids_closed = \@order_ids_closed;
    }
  }

  return $dry_run
    ? t8('Sales order ids not yet closed: #1 Purchase order ids not yet closed: #2',
      join(', ', @$sales_order_ids_closed), join(', ', @$purchase_order_ids_closed))
    : t8('Sales order ids closed: #1 Purchase order ids closed: #2',
      join(', ', @$sales_order_ids_closed), join(', ', @$purchase_order_ids_closed));
}

1;

__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::CloseOrdersIfBilled

Background job for closing orders that are billed completely

=head1 SYNOPSIS

=head1 AUTHOR

Bernd Bleßmann


=cut
