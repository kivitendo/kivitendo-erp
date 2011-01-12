package SL::DB::Order;

use utf8;
use strict;

use Carp;
use DateTime;
use List::Util qw(max);

use SL::DB::MetaSetup::Order;
use SL::DB::Manager::Order;
use SL::DB::Invoice;
use SL::DB::Helper::LinkedRecords;
use SL::DB::Helper::PriceTaxCalculator;
use SL::DB::Helper::TransNumberGenerator;
use SL::RecordLinks;

__PACKAGE__->meta->add_relationship(
  orderitems => {
    type         => 'one to many',
    class        => 'SL::DB::OrderItem',
    column_map   => { id => 'trans_id' },
    manager_args => {
      with_objects => [ 'part' ]
    }
  },
  periodic_invoices_config => {
    type                   => 'one to one',
    class                  => 'SL::DB::PeriodicInvoicesConfig',
    column_map             => { id => 'oe_id' },
  },
  periodic_invoices        => {
    type                   => 'one to many',
    class                  => 'SL::DB::PeriodicInvoice',
    column_map             => { id => 'oe_id' },
  },
  payment_term => {
    type       => 'one to one',
    class      => 'SL::DB::PaymentTerm',
    column_map => { payment_id => 'id' },
  },
);

__PACKAGE__->meta->initialize;

# methods

sub items { goto &orderitems; }

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

sub convert_to {
  my ($self, %params) = @_;

  my $destination_type = lc(delete $params{destination_type});

  if ($destination_type eq 'invoice') {
    $self->convert_to_invoice(%params);
  } else {
    croak("Unsupported destination type `$destination_type'");
  }
}

sub convert_to_invoice {
  my ($self, %params) = @_;

  if (!$params{ar_id}) {
    my $chart = SL::DB::Manager::Chart->get_all(query   => [ SL::DB::Manager::Chart->link_filter('AR') ],
                                                sort_by => 'id ASC',
                                                limit   => 1)->[0];
    croak("No AR chart found and no parameter `ar_id' given") unless $chart;
    $params{ar_id} = $chart->id;
  }

  my $invoice;
  if (!$self->db->do_transaction(sub {
    $invoice = SL::DB::Invoice->new_from($self)->post(%params) || die;
    $self->link_to_record($invoice);
    $self->update_attributes(closed => 1);
    # die;
  })) {
    return undef;
  }

  return $invoice;
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
