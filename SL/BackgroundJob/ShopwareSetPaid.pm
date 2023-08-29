package SL::BackgroundJob::ShopwareSetPaid;

use strict;

use parent qw(SL::BackgroundJob::Base);

use SL::DB::Invoice;
use SL::Locale::String qw(t8);
use SL::Shop;

sub run {
  my ($self, $db_obj)     = @_;
  my $data       = $db_obj->data_as_hash;

  my $dry_run = ($data->{dry_run})  ? 1 : 0;
  my $today   = ($data->{datepaid}) ? DateTime->from_kivitendo($data->{datepaid}) : DateTime->today_local;

  my $paid_invoices = SL::DB::Manager::Invoice->get_all(query => [ and => [ datepaid => { ge => $today }, amount  =>   \'paid'  ]]);

  my @shoporders;
  foreach my $invoice (@{ $paid_invoices }) {
    # check if we have a shop order invoice
    my @linked_shop_orders = $invoice->linked_records(
                               from => 'ShopOrder',
                               via  => ['DeliveryOrder','Order'],
                             );
    my $shop_order = $linked_shop_orders[0][0];
    if ( $shop_order ) {
       #do update
       push @shoporders, $shop_order->shop_ordernumber;
       next if $dry_run;
       my $shop_config = SL::DB::Manager::Shop->get_first( query => [ id => $shop_order->shop_id ] );
       my $shop = SL::Shop->new( config => $shop_config );
       $shop->connector->set_orderstatus($shop_order->shop_trans_id, "paid");
    }
  }
  # nothing found
  return t8("No valid invoice(s) found") if scalar @shoporders == 0;

  my $message = t8("The following Shop Orders: ") . join (', ', @shoporders);
  $message   .= $dry_run ? t8(" would be set to the state 'paid'") : t8(" have been set to the state 'paid'");

  return $message;
}

1;

__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::ShopwareSetPaid

Background job for setting the shopware state paid for shopware orders

With the default values the job should be run once a day after all payments are booked.

=head1 SYNOPSIS

Accepts two params 'dry_run' and 'datepaid'.
If 'dry_run' has trueish vale, the job simply returns what would have been done in the Background Job Journal.
If 'datepaid' is set all Invoices with a datepaid higher or equal the 'datepaid' value are checked. Date should be
in the correct system locales. If ommitted datepaid will be the current date.


=head1 AUTHOR

Jan Büren

=cut
