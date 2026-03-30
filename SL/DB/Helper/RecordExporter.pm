package SL::DB::Helper::RecordExporter;

use strict;

use parent qw(Exporter);
our @EXPORT = qw(export_as_csv_string);

use Carp;
use Text::CSV_XS;

use SL::Locale::String qw(t8);


my %columns_for = (
  'SL::DB::Order' => {
    record => {
      datatype                => { sub  => sub {t8('Order')} },
      amount                  => { text => t8('Amount'),
                                   sub  => sub {$_[0]->amount_as_number} },
      closed                  => { text => t8('Closed'), },
      currency                => { text => t8('Currency'),
                                   sub  => sub {$_[0]->currency ? $_[0]->currency->name : ''} },
      cusordnumber            => { text => t8('Customer Order Number') },
      delivered               => { text => t8('Delivered') },
      delivery_term           => { text => t8('Delivery terms (name)'),
                                   sub  => sub {$_[0]->delivery_term ? $_[0]->delivery_term->description : ''} },
      employee                => { text => t8('Employee'),
                                   sub  => sub {$_[0]->employee ? $_[0]->employee->safe_name : ''} },
      intnotes                => { text => t8('Internal Notes') },
      marge_percent           => { text => t8('Margepercent'),
                                   sub  => sub {$_[0]->marge_percent_as_percent} },
      marge_total             => { text => t8('Margetotal'),
                                   sub  => sub {$_[0]->marge_total_as_number} },
      netamount               => { text => t8('Net amount'),
                                   sub  => sub {$_[0]->netamount_as_number} },
      notes                   => { text => t8('Notes') },
      ordnumber               => { text => t8('Order Number') },
      quonumber               => { text => t8('Quotation Number') },
      reqdate                 => { text => t8('Reqdate'),
                                   sub  => sub {$_[0]->reqdate_as_date} },
      salesman                => { text => t8('Salesman'),
                                   sub  => sub {$_[0]->salesman ? $_[0]->salesman->safe_name : ''} },
      shippingpoint           => { text => t8('Shipping Point') },
      shipvia                 => { text => t8('Ship via') },
      transaction_description => { text => t8('Transaction description') },
      transdate               => { text => t8('Order Date'),
                                   sub  => sub {$_[0]->transdate_as_date} },
      taxincluded             => { text => t8('Tax Included') },
      customer                => { text => t8('Customer (name)'),
                                   sub  => sub {$_[0]->customer ? $_[0]->customer->name : ''} },
      customernumber          => { text => t8('Customer Number'),
                                   sub  => sub {$_[0]->customer ? $_[0]->customer->number : ''} },
      customer_gln            => { text => t8('Customer GLN'),
                                   sub  => sub {$_[0]->customer ? $_[0]->customer->gln : ''} },
      vendor                  => { text => t8('Vendor (name)'),
                                   sub  => sub {$_[0]->vendor ? $_[0]->vendor->name : ''} },
      vendornumber            => { text => t8('Vendor Number'),
                                   sub  => sub {$_[0]->vendor ? $_[0]->vendor->number: ''} },
      vendor_gln              => { text => t8('Vendor GLN'),
                                   sub  => sub {$_[0]->vendor ? $_[0]->vendor->gln : ''} },
      language                => { text => t8('Language (name)'),
                                   sub  => sub {$_[0]->language ? $_[0]->language->description : ''} },
      payment                 => { text => t8('Payment terms (name)'),
                                   sub  => sub {$_[0]->payment_terms ? $_[0]->payment_terms->description : ''} },
      taxzone                 => { text => t8('Tax zone (description)'),
                                   sub  => sub {$_[0]->taxzone ? $_[0]->taxzone->description : ''} },
      contact                 => { text => t8('Contact Person (name)'),
                                   sub  => sub {$_[0]->contact ? $_[0]->contact->full_name : ''} },
      department              => { text => t8('Department (description)'),
                                   sub  => sub {$_[0]->department ? $_[0]->department->description : ''} },
      globalprojectnumber     => { text => t8('Document Project (number)'),
                                   sub  => sub {$_[0]->globalproject ? $_[0]->globalproject->description : ''} },
      globalproject           => { text => t8('Document Project (description)'),
                                   sub  => sub {$_[0]->globalproject ? $_[0]->globalproject->projectnumber : ''} },
    },
    item   => {
      datatype                 => { sub  => sub {t8('OrderItem')} },
      cusordnumber             => { text => t8('Customer Order Number') },
      description              => { text => t8('Description') },
      discount                 => { text => t8('Discount'),
                                    sub => sub {$_[0]->discount_as_percent} },
      ean                      => { text => t8('EAN') },
      lastcost                 => { text => t8('Lastcost'),
                                    sub => sub {$_[0]->lastcost_as_number} },
      longdescription          => { text => t8('Long Description') },
      marge_percent            => { text => t8('Margepercent'),
                                    sub  => sub {$_[0]->marge_percent_as_percent} },
      marge_total              => { text => t8('Margetotal'),
                                    sub  => sub {$_[0]->marge_total_as_number} },
      ordnumber                => { text => t8('Order Number') },
      partnumber               => { text => t8('Part Number'),
                                    sub  => sub {$_[0]->part ? $_[0]->part->partnumber : ''} },
      position                 => { text => t8('position') },
      projectnumber            => { text => t8('Project (number)'),
                                    sub  => sub {$_[0]->project ? $_[0]->project->projectnumber : ''} },
      project                  => { text => t8('Project (description)'),
                                    sub  => sub {$_[0]->project ? $_[0]->project->description : ''} },
      price_factor             => { text => t8('Price factor (name)'),
                                    sub  => sub {$_[0]->price_factor_obj ? $_[0]->price_factor_obj->description : ''} },
      pricegroup               => { text => t8('Price group (name)'),
                                    sub  => sub {$_[0]->pricegroup ? $_[0]->pricegroup->pricegroup : ''} },
      qty                      => { text => t8('Quantity'),
                                    sub  => sub {$_[0]->qty_as_number} },
      reqdate                  => { text => t8('Reqdate'),
                                    sub  => sub {$_[0]->reqdate_as_date} },
      sellprice                => { text => t8('Sellprice'),
                                    sub  => sub {$_[0]->sellprice_as_number} },
      serialnumber             => { text => t8('Serial No.') },
      subtotal                 => { text => t8('Subtotal') },
      unit                     => { text => t8('Unit') },
    },
  }
);


sub export_as_csv_string {
  my ($self, %params) = @_;

  _check_prerequisites($self);

  my $csv = Text::CSV_XS->new({
    sep_char => ';',
    eol      => "\n",
    binary   => 1,
  });

  my $csv_string;
  open(my $outfh, '>:encoding(UTF-8)', \$csv_string) or die "open for csv string failed";

  my $record_header = get_record_header($self, %params);
  my $item_header   = get_item_header($self, %params);

  $csv->print($outfh, $record_header);
  $csv->print($outfh, $item_header);

  $csv->print($outfh, get_record_entry($self, %params));

  $csv->print($outfh, $_) for @{get_item_entries($self, %params)};

  close($outfh);

  return $csv_string;
}

sub get_record_entry {
  my ($self, %params) = @_;

  my $columns = $columns_for{$_[0]->meta->class}->{record};
  my $keys    = get_record_keys($self);

  my $obj = $self;
  my @row = map {
    my $key = $_;
    my $map = $columns->{$key};
    my $val = !defined $map   ? ''
            : $map->{sub}     ? $map->{sub}->($obj)
            : $obj->can($key) ? $obj->$key
            : $obj->{$key};
    $val;
  } @$keys;

  return \@row;
}

sub get_item_entries {
  my ($self, %params) = @_;

  my $columns = $columns_for{$_[0]->meta->class}->{item};
  my $keys    = get_item_keys($self);
  my $items   = $self->items_sorted;

  my @rows = ();
  foreach my $obj (@$items) {
    my @row = map {
      my $key = $_;
      my $map = $columns->{$key};
      my $val = !defined $map ? ''
        : $map->{sub}         ? $map->{sub}->($obj)
        : $obj->can($key)     ? $obj->$key
        : $obj->{$key};
      $val;
    } @$keys;
    push @rows, \@row;
  }

  return \@rows;
}

sub _check_prerequisites {
  my ($self) = @_;

  croak "need a record with items" if ! $self->can('items_sorted');
}

sub get_record_keys {
  _get_keys($columns_for{$_[0]->meta->class}->{record});
}

sub get_item_keys {
  _get_keys($columns_for{$_[0]->meta->class}->{item});
}

sub _get_keys {
  my ($columns) = @_;

  # put datatype in front
  my @keys = sort grep { $_ ne 'datatype' } keys %{$columns};
  unshift @keys, 'datatype';

  return \@keys;
}

sub get_record_header {
  my ($self, %params) = @_;

  _get_header($columns_for{$self->meta->class}->{record}, %params);
}

sub get_item_header {
  my ($self, %params) = @_;

  _get_header($columns_for{$self->meta->class}->{item}, %params);
}

sub _get_header {
  my ($columns, %params) = @_;

  my $compatible_for_import = $params{compatible_for_import};
  my $keys                  = _get_keys($columns);

  my @header = map { $compatible_for_import ? $_ : $columns->{$_}->{text} || $_ } @$keys;

  return \@header;
}


__END__

=encoding utf-8

=head1 NAME

SL::DB::Helper::RecordExporter - a helper to export records as CSV.

=head1 SYNOPSIS

This is a mixin to export record objects as csv.
At the moment, it supports order records.

=head1 COLUMN DEFINITIONS

The column definitions are set in the global hash C<%columns_for>.
The main keys of the hash are the class names of the defined records
(i.e. C<SL::DB::Order> for now) and the values are hashrefs.

For each defined class, there is a hashref for C<record> and a hashref
for C<item>. These consists of the name of the column and a hasref with
the definiton of the column.
In the definition there can be following keys:

=over 2

=item <text>

The text will be the header description of the column. If it is missing, then
the key is used.

=item <sub>

This can be a anonymous subroutine which is called with the record or item
object to get the value if the columns.
If it is missing, a method with the name of the key is called on the record
or item object to get the value if the columns.

=back

=head1 CSV FORMAT

The csv format is a multiplexed format like that one for the csvimport
of orders in kivitendo.

The csv string is separated by semicolons. There are two header lines - one
for the record data and one for the item data.

In each dataline there is a column C<datatype> which descripes the type of the
data line (the translation of C<Order> for the record and the translation
of C<OrderItem> for the items).

=head1 FUNCTIONS

=over 4

=item C<export_as_csv_string %params>

Returns a csv string with the exported values of the record.
If the parameter C<compatible_for_import> is truish, then the key
of the column description is used as header and not the value of
the C<text> entry. The output should be compatible with the csv import
in this case.

=back

=head1 To do / to discuss / nice to have

=over 4

=item *

options for csv export settings (separator, number format, date format, ...)

=item *

option for none multiplex csv (i.e. one row per item,
record fields are repeated on each line)

=item *

params to set columns to export and to change column names

=item *

param to choose not to translate columns (compatible for import)

=back

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
