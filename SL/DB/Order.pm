package SL::DB::Order;

use utf8;
use strict;

use SL::RecordLinks;

use SL::DB::MetaSetup::Order;
use SL::DB::Manager::Order;
use SL::DB::Invoice;

__PACKAGE__->meta->add_relationship(
  orderitems => {
    type         => 'one to many',
    class        => 'SL::DB::OrderItem',
    column_map   => { id => 'trans_id' },
    manager_args => {
      with_objects => [ 'part' ]
    }
  }
);

__PACKAGE__->meta->initialize;

# methods

sub type {
  my $self = shift;

  return 'sales_order'       if $self->customer_id && ! $self->quotation;
  return 'purchase_order'    if $self->vendor_id   && ! $self->quotation;
  return 'sales_quotation'   if $self->customer_id &&   $self->quotation;
  return 'request_quotation' if $self->vendor_id   &&   $self->quotation;

  return;
}

sub is_type {
  return shift->type eq shift;
}

sub invoices {
  my $self   = shift;
  my %params = @_;

  if ($self->quotation) {
    return [];
  } else {
    return SL::DB::Manager::Invoice->get_all(
      query => [
        ordnumber => $self->ordnumber,
        @{ $params{query} || [] },
      ]
    );
  }
}

sub abschlag_invoices {
  return shift()->invoices(query => [ abschlag => 1 ]);
}

sub end_invoice {
  return shift()->invoices(query => [ abschlag => 0 ]);
}

1;

__END__

=head1 NAME

SL::DB::Order - Order Datenbank Objekt.

=head1 FUNCTIONS

=head2 type

Returns one of the following string types:

=over 4

=item saes_order

=item purchase_order

=item sales_quotation

=item request_quotation

=back

=head2 is_type TYPE

Rreturns true if the order is of the given type.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Sven Schöling <s.schoeling@linet-services.de>

=cut
