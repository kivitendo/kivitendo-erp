# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Invoice;

use strict;

use Carp;
use List::Util qw(first);

use SL::DB::MetaSetup::Invoice;
use SL::DB::Manager::Invoice;
use SL::DB::Helper::FlattenToForm;
use SL::DB::Helper::LinkedRecords;
use SL::DB::Helper::PriceTaxCalculator;
use SL::DB::Helper::PriceUpdater;
use SL::DB::Helper::TransNumberGenerator;

__PACKAGE__->meta->add_relationship(
  invoiceitems => {
    type         => 'one to many',
    class        => 'SL::DB::InvoiceItem',
    column_map   => { id => 'trans_id' },
    manager_args => {
      with_objects => [ 'part' ]
    }
  },
  storno_invoices => {
    type          => 'one to many',
    class         => 'SL::DB::Invoice',
    column_map    => { id => 'storno_id' },
  },
  sepa_export_items => {
    type            => 'one to many',
    class           => 'SL::DB::SepaExportItem',
    column_map      => { id => 'ar_id' },
    manager_args    => { with_objects => [ 'sepa_export' ] }
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->before_save('_before_save_set_invnumber');

# hooks

sub _before_save_set_invnumber {
  my ($self) = @_;

  $self->create_trans_number if !$self->invnumber;

  return 1;
}

# methods

sub items { goto &invoiceitems; }

sub items_sorted {
  my ($self) = @_;

  return [ sort {$a->id <=> $b->id } @{ $self->items } ];
}

sub is_sales {
  # For compatibility with Order, DeliveryOrder
  croak 'not an accessor' if @_ > 1;
  return 1;
}

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

  return ($self->amount || 0) - ($self->netamount || 0);
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

  require SL::DB::Employee;

  my $terms = $source->can('payment_id') && $source->payment_id ? $source->payment_terms->terms_netto : 0;

  my %args = ( map({ ( $_ => $source->$_ ) } qw(customer_id taxincluded shippingpoint shipvia notes intnotes salesman_id cusordnumber ordnumber quonumber
                                                department_id cp_id language_id payment_id delivery_customer_id delivery_vendor_id taxzone_id shipto_id
                                                globalproject_id transaction_description currency_id)),
               transdate   => DateTime->today_local,
               gldate      => DateTime->today_local,
               duedate     => DateTime->today_local->add(days => $terms * 1),
               invoice     => 1,
               type        => 'invoice',
               storno      => 0,
               paid        => 0,
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
                            deliverydate => $source_item->reqdate,
                            fxsellprice  => $source_item->sellprice,);
  } @{ $source->items_sorted };

  $invoice->invoiceitems(\@items);

  return $invoice;
}

sub post {
  my ($self, %params) = @_;

  require SL::DB::Chart;
  if (!$params{ar_id}) {
    my $chart = SL::DB::Manager::Chart->get_all(query   => [ SL::DB::Manager::Chart->link_filter('AR') ],
                                                sort_by => 'id ASC',
                                                limit   => 1)->[0];
    croak("No AR chart found and no parameter `ar_id' given") unless $chart;
    $params{ar_id} = $chart->id;
  }

  my $worker = sub {
    my %data = $self->calculate_prices_and_taxes;

    $self->_post_create_assemblyitem_entries($data{assembly_items});
    $self->save;

    $self->_post_add_acctrans($data{amounts_cogs});
    $self->_post_add_acctrans($data{amounts});
    $self->_post_add_acctrans($data{taxes});

    $self->_post_add_acctrans({ $params{ar_id} => $self->amount * -1 });

    $self->_post_update_allocated($data{allocated});
  };

  if ($self->db->in_transaction) {
    $worker->();
  } elsif (!$self->db->do_transaction($worker)) {
    $::lxdebug->message(LXDebug->WARN(), "convert_to_invoice failed: " . join("\n", (split(/\n/, $self->db->error))[0..2]));
    return undef;
  }

  return $self;
}

sub _post_add_acctrans {
  my ($self, $entries) = @_;

  my $default_tax_id = SL::DB::Manager::Tax->find_by(taxkey => 0)->id;
  my $chart_link;

  require SL::DB::AccTransaction;
  require SL::DB::Chart;
  while (my ($chart_id, $spec) = each %{ $entries }) {
    $spec = { taxkey => 0, tax_id => $default_tax_id, amount => $spec } unless ref $spec;
    $chart_link = SL::DB::Manager::Chart->find_by(id => $chart_id)->{'link'};
    $chart_link ||= '';

    SL::DB::AccTransaction->new(trans_id   => $self->id,
                                chart_id   => $chart_id,
                                amount     => $spec->{amount},
                                tax_id     => $spec->{tax_id},
                                taxkey     => $spec->{taxkey},
                                project_id => $self->globalproject_id,
                                transdate  => $self->transdate,
                                chart_link => $chart_link)->save;
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
    SL::DB::Manager::InvoiceItem->update_all(set   => { allocated => { sql => "allocated + $diff" } },
                                             where => [ id        => $invoice_id ]);
  }
}

sub invoice_type {
  my ($self) = @_;

  return 'ar_transaction'     if !$self->invoice;
  return 'credit_note'        if $self->type eq 'credit_note' && $self->amount < 0 && !$self->storno;
  return 'invoice_storno'     if $self->type ne 'credit_note' && $self->amount < 0 &&  $self->storno;
  return 'credit_note_storno' if $self->type eq 'credit_note' && $self->amount > 0 &&  $self->storno;
  return 'invoice';
}

sub displayable_state {
  my $self = shift;

  return $self->closed ? $::locale->text('closed') : $::locale->text('open');
}

sub date {
  goto &transdate;
}

1;

__END__

=pod

=head1 NAME

SL::DB::Invoice: Rose model for invoices (table "ar")

=head1 FUNCTIONS

=over 4

=item C<new_from $source>

Creates a new C<SL::DB::Invoice> instance and copies as much
information from C<$source> as possible. At the moment only sales
orders and sales quotations are supported as sources.

The conversion copies order items into invoice items. Dates are copied
as appropriate, e.g. the C<transdate> field from an order will be
copied into the invoice's C<orddate> field.

Amounts, prices and taxes are not
calculated. L<SL::DB::Helper::PriceTaxCalculator::calculate_prices_and_taxes>
can be used for this.

The object returned is not saved.

=item C<post %params>

Posts the invoice. Required parameters are:

=over 2

=item * C<ar_id>

The ID of the accounds receivable chart the invoices amounts are
posted to. If it is not set then the first chart configured for
accounts receivables is used.

=back

This function implements several steps:

=over 2

=item 1. It calculates all prices, amounts and taxes by calling
L<SL::DB::Helper::PriceTaxCalculator::calculate_prices_and_taxes>.

=item 2. A new and unique invoice number is created.

=item 3. All amounts for costs of goods sold are recorded in
C<acc_trans>.

=item 4. All amounts for parts, services and assemblies are recorded
in C<acc_trans> with their respective charts. This is determined by
the part's buchungsgruppen.

=item 5. The total amount is posted to the accounts receivable chart
and recorded in C<acc_trans>.

=item 6. Items in C<invoice> are updated according to their allocation
status (regarding for costs of goold sold). Will only be done if
kivitendo is not configured to use Einnahmenüberschussrechnungen.

=item 7. The invoice and its items are saved.

=back

Returns C<$self> on success and C<undef> on failure. The whole process
is run inside a transaction. If it fails then nothing is saved to or
changed in the database. A new transaction is only started if none is
active.

=item C<basic_info $field>

See L<SL::DB::Object::basic_info>.

=back

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
