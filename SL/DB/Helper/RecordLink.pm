package SL::DB::Helper::RecordLink;

use strict;
use parent qw(Exporter);

use Carp qw(croak);

use SL::MoreCommon qw(listify);

use constant RECORD_ID            => 'converted_from_record_id';
use constant RECORD_TYPE_REF      => 'converted_from_record_type_ref';
use constant RECORD_ITEM_ID       => 'converted_from_record_item_id';
use constant RECORD_ITEM_TYPE_REF => 'converted_from_record_item_type_ref';

our @EXPORT_OK = qw(RECORD_ID RECORD_TYPE_REF RECORD_ITEM_ID RECORD_ITEM_TYPE_REF set_record_link_conversions);

sub link_records {
  my ($self, $allowed_linked_records, $allowed_linked_record_items) = @_;

  my %allowed_linked_records = map {$_ => 1} @$allowed_linked_records;
  my %allowed_linked_record_items = map {$_ => 1} @$allowed_linked_record_items;

  return 1 unless my $from_record_ids = $self->{RECORD_ID()};
  my @from_record_ids = split / /, $from_record_ids;

  my $from_record_type = $self->{RECORD_TYPE_REF()};
  unless ($allowed_linked_records{$from_record_type}) {
    croak("Not allowed @{[ RECORD_TYPE_REF ]}: $from_record_type");
  }

  for my $id (@from_record_ids) {
    my $from_record = $from_record_type->new(id => $id)->load;
    $from_record->link_to_record($self);
  }

  #clear converted_from;
  delete $self->{$_} for RECORD_ID, RECORD_TYPE_REF;

  for my $item (@{ $self->items_sorted }) {
    link_record_item($self, $item, \%allowed_linked_record_items);
  }

  1;
}

sub link_record_item {
  my ($self, $record_item, $allowed_linked_record_items) = @_;

  return 1 unless my $from_item_id = $record_item->{RECORD_ITEM_ID()};

  my $from_item_type = $record_item->{RECORD_ITEM_TYPE_REF()};
  unless ($allowed_linked_record_items->{$from_item_type}) {
    croak("Not allowed @{[ RECORD_ITEM_TYPE_REF() ]}: $from_item_type");
  }

  $from_item_type->new(id => $from_item_id)->load
    ->link_to_record($record_item);

  #clear converted_from;
  delete $record_item->{$_} for RECORD_ITEM_ID, RECORD_ITEM_TYPE_REF;
}


sub set_record_link_conversions {
  my ($record, $from_type, $from_ids, $item_types, $item_ids) = @_;

  return unless listify($from_ids);

  $record->{ RECORD_TYPE_REF() } = $from_type;
  $record->{ RECORD_ID() } = $from_ids;

  my $idx = 0;
  my $items = $record->items_sorted;

  $item_ids ||= [];
  croak "more item ids than items in record" if @$item_ids > @$items;

  for my $idx (0..$#$item_ids) {
    my $item = $items->[$idx];

    $item->{ RECORD_ITEM_TYPE_REF() } = $item_types->[$idx];
    $item->{ RECORD_ITEM_ID() }       = $item_ids->[$idx];
  }
}


1;

__END__

=encoding utf-8

=head1 NAME

SL::DB::Helper::RecordLink - creates record links that are stored in the gived objects

=head1 SYNOPSIS

    # in the consuming class
    __PACKAGE__->after_save_hook("link_records_hook");

    sub link_records_hook {
      my ($self) = @_;
      SL::DB::Helper::RecordLink::link_records(
        $self,
        [ qw(SL::DB::Order) ],        # list of allowed record sources
        [ qw(SL::DB::OrderItem) ],    # list of allowed record item sources
      )
    }

    # set conversion data in record
    sub prepare_linked_records {
      my @converted_from_ids      = @{ $::form->{converted_from_oe_ids} };
      my @converted_from_item_ids = @{ $::form->{converted_from_orderitem_ids} };

      set_record_link_conversion(
        $self->order,                                     # the record to modify
        'SL::DB::Order'     => \@converted_from_ids,      # singular or multiple source record ids
        'SL::DB::OrderItem' => \@converted_from_item_ids  # ids of items, each item will get one id
      );
    }

=head1 DESCRIPTION

This module implements reusable after save hooks for dealing with record links for records created from other records.

It reacts to non-rose attributes set in the underlying hashes of the given record:

=over 4

=item * C<converted_from_record_id>

=item * C<converted_from_record_type_ref>

=item * C<converted_from_record_item_id>

=item * C<converted_from_record_item_type_ref>

=back

If a typeref is given that is not explicitely whitelisted, an error will be thrown.

The older C<converted_from_oe_ids> etc forms can be converted with TODO

=head1 FUNCTIONS

=over 4

=item * C<set_record_link_conversions> $record, $record_type => \@ids, $item_type => \@item_ids

Register the given ids in the object to be linked after saving.

Item ids will be assigned one by one to sorted_items.

This function can be exported on demand to the calling package.

=item * C<link_records> $record, \@allowed_record_types, \@allowed_item_types

Intended as a post-save hook.
Evaluates the stored ids from L </set_record_link_conversions>
and links the creating objects to the given one.

=back

=head1 CONSTANTS

Aöll of these can be exported on demand if the calling code wants to set or read the markers in a record manually.

=over 4

=item * C<RECORD_ID> = C<converted_from_record_id>

=item * C<RECORD_TYPE_REF> = C<converted_from_record_type_ref>

=item * C<RECORD_ITEM_ID> = C<converted_from_record_item_id>

=item * C<RECORD_ITEM_TYPE_REF> = C<converted_from_record_item_type_ref>

=back

=head1 BUGS

None yet. :)

=head1 AUTHOR

Sven Schöling $<lt>s.schoeling@googlemail.comE<gt>

=cut
