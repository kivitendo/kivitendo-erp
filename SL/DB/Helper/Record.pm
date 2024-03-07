package SL::DB::Helper::Record;

use strict;
use warnings;
use Carp;
use Exporter qw(import);

use SL::DB::Order::TypeData;
use SL::DB::DeliveryOrder::TypeData;
use SL::DB::Reclamation::TypeData;
use SL::DB::Invoice::TypeData;
use SL::DB::PurchaseInvoice::TypeData;

use SL::DB::Helper::TypeDataProxy;

my @export_subs = qw(
  get_object_name_from_type get_class_from_type get_items_class_from_type
  get_type_data_proxy_from_type
);

our @EXPORT_OK = (@export_subs);
our %EXPORT_TAGS = (subs => \@export_subs);

my %type_to_object_name = ();
$type_to_object_name{$_} = 'Order'           for (@{(SL::DB::Order::TypeData::valid_types)});
$type_to_object_name{$_} = 'DeliveryOrder'   for (@{(SL::DB::DeliveryOrder::TypeData::valid_types)});
$type_to_object_name{$_} = 'Reclamation'     for (@{(SL::DB::Reclamation::TypeData::valid_types)});
$type_to_object_name{$_} = 'Invoice'         for (@{(SL::DB::Invoice::TypeData::valid_types)});
$type_to_object_name{$_} = 'PurchaseInvoice' for (@{(SL::DB::Invoice::TypeData::valid_types)});

sub get_object_name_from_type {
  my ($type) = @_;
  return $type_to_object_name{$type} // croak "invalid type '$type'";
}

sub get_class_from_type {
  my ($type) = @_;
  return 'SL::DB::' . get_object_name_from_type($type);
}

sub get_items_class_from_type {
  my ($type) = @_;
  return 'SL::DB::' . get_object_name_from_type($type) . 'Item';
}

sub get_type_data_proxy_from_type {
  my ($type) = @_;
  return SL::DB::Helper::TypeDataProxy->new(
    get_class_from_type($type), $type
  );
}

1;

__END__

=encoding utf8

=head1 NAME

SL::DB::Helper::Record - Helper methods for record objects

=head1 SYNOPSIS

  use SL::DB::Helper::Record;

=head1 DESCRIPTION

This modul includes helper methods for the handling of record object.

=head1 FUNCTIONS

=over 4

=item C<get_object_name_from_type $type>

Returns the name string for corresponding record type:

  SL::DB::Helper::Record::get_class_from_type('sales_order');
  # Order

=item C<get_class_from_type $type>

Returns the class string for corresponding record type:

  SL::DB::Helper::Record::get_class_from_type('sales_order');
  # SL::DB::Order

=back

=head1 BUGS

nothing yet

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
