package SL::BackgroundJob::InventoryClearAll;

use strict;

use parent qw(SL::BackgroundJob::Base);

use SL::DB::Inventory;
use SL::Helper::Inventory qw(:ALL);
use SL::Locale::String qw(t8);


sub run {
  my ($self, $job_obj) = @_;
  my $data = $job_obj->data_as_hash;

  my $comment        = $data->{comment} // 'vor Inventur';
  my $date           = DateTime->today_local();
  my $date_str       = $date->format_cldr('yyyy-MM-dd');
  my $dry_run        = ($data->{dry_run}) ? 1 : 0;
  my $employee_id    = SL::DB::Manager::Employee->current->id;
  my $trans_type_in  = SL::DB::Manager::TransferType->find_by(description => 'correction', direction => 'in');
  my $trans_type_out = SL::DB::Manager::TransferType->find_by(description => 'correction', direction => 'out');
  my $warehouse_id;

  if (exists $data->{warehouse}) {
    $warehouse_id = SL::DB::Manager::Warehouse->find_by(description => $data->{warehouse});
    die "Lager existiert nicht: $data->{warehouse}" if !defined $warehouse_id;
  }

  die "No parameter correction_date given"
    if !exists $data->{correction_date};
  die "Parameter correction_date $data->{correction_date} is not today $date_str"
    if $data->{correction_date} ne $date_str;

  my $stock_all      = get_stock(warehouse    => $warehouse_id,
                                 by           => [ qw(bin chargenumber part) ],
                                 with_objects => [ qw(part) ]);
  my @stock          = grep { $_->{qty} != 0 } @{ $stock_all };
  my $ntransactions  = scalar @stock;

  my @trans;
  foreach (@stock) {
    my $qty = $_->{qty} * -1;

    push @trans, "$_->{part}->{id} $qty $_->{part}->{unit}";

    next if $dry_run;
    my $x = SL::DB::Inventory->new();

    $x->bestbefore  ($_->{bestbefore});
    $x->bin_id      ($_->{bin_id});
    $x->chargenumber($_->{chargenumber});
    $x->comment     ($comment);
    $x->employee_id ($employee_id);
    $x->parts_id    ($_->{parts_id});
    $x->qty         ($qty);
    $x->shippingdate($date);
    $x->trans_type  (($qty > 0) ? $trans_type_in : $trans_type_out);
    $x->warehouse_id($_->{warehouse_id});

    $x->save();
  }

  return $dry_run
    ? t8('Inventory: #1 transactions not yet executed to clear all inventory slots. Parts: #2',
      $ntransactions, join(',', @trans))
    : t8('Inventory: #1 transactions executed to clear all inventory slots. Parts: #2',
      $ntransactions, join(',', @trans));
}

1;


__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::InventoryClearAll —
Background job which performs all inventory transactions needed to empty all
warehoue bins. Useful before stocktaking

=head1 SYNOPSIS

=head1 AUTHOR

Niklas Schmidt


=cut
