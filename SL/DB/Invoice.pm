# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Invoice;

use strict;

use Carp;
use List::Util qw(first);

use SL::DB::MetaSetup::Invoice;
use SL::DB::Manager::Invoice;
use SL::DB::Helper::LinkedRecords;
use SL::DB::Helper::PriceTaxCalculator;
use SL::DB::Helper::TransNumberGenerator;
use SL::DB::Employee;

__PACKAGE__->meta->add_relationship(
  invoiceitems => {
    type         => 'one to many',
    class        => 'SL::DB::InvoiceItem',
    column_map   => { id => 'trans_id' },
    manager_args => {
      with_objects => [ 'part' ]
    }
  },
  payment_term => {
    type       => 'one to one',
    class      => 'SL::DB::PaymentTerm',
    column_map => { payment_id => 'id' },
  },
);

__PACKAGE__->meta->initialize;

# methods

sub items { goto &invoiceitems; }

# it is assumed, that ordnumbers are unique here.
sub first_order_by_ordnumber {
  my $self = shift;

  my $orders = SL::DB::Manager::Order->get_all(
    query => [
      ordnumber => $self->ordnumber,

    ],
  );

  return first { $_->is_type('sales_order') } @{ $orders };
}

sub abschlag_percentage {
  my $self         = shift;
  my $order        = $self->first_order_by_ordnumber or return;
  my $order_amount = $order->netamount               or return;
  return $self->abschlag
    ? $self->netamount / $order_amount
    : undef;
}

sub taxamount {
  my $self = shift;
  die 'not a setter method' if @_;

  return $self->amount - $self->netamount;
}

__PACKAGE__->meta->make_attr_helpers(taxamount => 'numeric(15,5)');

sub closed {
  my ($self) = @_;
  return $self->paid >= $self->amount;
}

sub new_from {
  my ($class, $source, %params) = @_;

  croak("Unsupported source object type '" . ref($source) . "'") unless ref($source) =~ m/^ SL::DB:: (?: Order | DeliveryOrder ) $/x;
  croak("Cannot create invoices for purchase records")           unless $source->customer_id;

  my $terms = $source->can('payment_id') && $source->payment_id ? $source->payment_term->terms_netto : 0;

  my %args = ( map({ ( $_ => $source->$_ ) } qw(customer_id taxincluded shippingpoint shipvia notes intnotes curr salesman_id cusordnumber ordnumber quonumber
                                                department_id cp_id language_id payment_id delivery_customer_id delivery_vendor_id taxzone_id shipto_id
                                                globalproject_id transaction_description)),
               transdate   => DateTime->today_local,
               gldate      => DateTime->today_local,
               duedate     => DateTime->today_local->add(days => $terms * 1),
               invoice     => 1,
               type        => 'invoice',
               storno      => 0,
               employee_id => (SL::DB::Manager::Employee->current || SL::DB::Employee->new(id => $source->employee_id))->id,
            );

  if ($source->type =~ /_order$/) {
    $args{deliverydate} = $source->reqdate;
    $args{orddate}      = $source->transdate;
  } else {
    $args{quodate}      = $source->transdate;
  }

  my $invoice = $class->new(%args, %params);

  my @items = map {
    my $source_item = $_;
    SL::DB::InvoiceItem->new(map({ ( $_ => $source_item->$_ ) }
                                 qw(parts_id description qty sellprice discount project_id
                                    serialnumber pricegroup_id ordnumber transdate cusordnumber unit
                                    base_qty subtotal longdescription lastcost price_factor_id)),
                            deliverydate => $source_item->reqdate);
  } @{ $source->items };

  $invoice->invoiceitems(\@items);

  return $invoice;
}

sub post {
  my ($self, %params) = @_;

  croak("Missing parameter 'ar_id'") unless $params{ar_id};

  $self->db->do_transaction(sub {
    1;                          # dummy instruction for Emacs ;)

    my %data = $self->calculate_prices_and_taxes;

    $self->_post_create_assemblyitem_entries($data{assembly_items});

    $self->save;

    $self->_post_add_acctrans($data{amounts_cogs});
    $self->_post_add_acctrans($data{amounts});
    $self->_post_add_acctrans($data{taxes});

    $self->_post_add_acctrans({ $params{ar_id} => $self->amount * -1 });

    $self->_post_update_allocated($data{allocated});

    die;
  });
}

sub _post_add_acctrans {
  my ($self, $entries) = @_;

  while (my ($chart_id, $spec) = each %{ $entries }) {
    $spec = { taxkey => 0, amount => $spec } unless ref $spec;
    SL::DB::AccTrans->new(trans_id   => $self->id,
                          chart_id   => $chart_id,
                          amount     => $spec->{amount},
                          taxkey     => $spec->{taxkey},
                          project_id => $self->project_id,
                          transdate  => $self->transdate)->save;
  }
}

sub _post_create_assemblyitem_entries {
  my ($self, $assembly_entries) = @_;

  my $items = $self->invoiceitems;
  my @new_items;

  my $item_idx = 0;
  foreach my $item (@{ $items }) {
    next if $item->assemblyitem;

    push @new_items, $item;
    $item_idx++;

    foreach my $assembly_item (@{ $assembly_entries->[$item_idx] || [ ] }) {
      push @new_items, SL::DB::InvoiceItem->new(parts_id     => $assembly_item->{part},
                                                description  => $assembly_item->{part}->description,
                                                unit         => $assembly_item->{part}->unit,
                                                qty          => $assembly_item->{qty},
                                                allocated    => $assembly_item->{allocated},
                                                sellprice    => 0,
                                                fxsellprice  => 0,
                                                assemblyitem => 't');
    }
  }

  $self->invoiceitems(\@new_items);
}

sub _post_update_allocated {
  my ($self, $allocated) = @_;

  while (my ($invoice_id, $diff) = each %{ $allocated }) {
    SL::DB::Manager::InvoiceItem->update_all(set   => { allocated => { sql => [ 'allocated + ?', $diff ] } },
                                             where => [ id        => $invoice_id ]);
  }
}

>>>>>>> b6be290... Prototypisiertes Buchen von Rechnungen
1;
