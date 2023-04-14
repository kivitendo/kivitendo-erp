package SL::DB::Helper::Record;

use strict;
use warnings;
use Carp;
use Exporter qw(import);
use SL::DB::Order::TypeData;
use SL::DB::DeliveryOrder::TypeData;
use SL::DB::Reclamation::TypeData;

my @export_subs = qw(get_object_name_from_type get_class_from_type);

our @EXPORT_OK = (@export_subs);
our %EXPORT_TAGS = (subs => \@export_subs);

my %type_to_object_name = ();
$type_to_object_name{$_} = 'Order'         for (@{(SL::DB::Order::TypeData::valid_types)});
$type_to_object_name{$_} = 'DeliveryOrder' for (@{(SL::DB::DeliveryOrder::TypeData::valid_types)});
$type_to_object_name{$_} = 'Reclamation'   for (@{(SL::DB::Reclamation::TypeData::valid_types)});
# TODO: rewrite when invoice type data is available
$type_to_object_name{invoice}                     = 'Invoice';
$type_to_object_name{invoice_for_advance_payment} = 'Invoice';
$type_to_object_name{final_invoice}               = 'Invoice';
$type_to_object_name{credit_note}                 = 'Invoice';
$type_to_object_name{purchase_invoice}            = 'PurchaseInvoice';

sub get_object_name_from_type {
  my ($type) = @_;
  return $type_to_object_name{$type} // croak "invalid type '$type'";
}

sub get_class_from_type {
  my ($type) = @_;
  return 'SL::DB::' . get_object_name_from_type($type);
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
