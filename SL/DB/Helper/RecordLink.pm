package SL::DB::Helper::RecordLink;

use strict;
use parent qw(Exporter);

use Carp qw(croak);

use SL::MoreCommon qw(listify);

use constant RECORD_ID            => 'converted_from_record_id';
use constant RECORD_TYPE_REF      => 'converted_from_record_type_ref';
use constant RECORD_ITEM_ID       => 'converted_from_record_item_id';
use constant RECORD_ITEM_TYPE_REF => 'converted_from_record_item_type_ref';

our @EXPORT_OK = qw(RECORD_ID RECORD_TYPE_REF RECORD_ITEM_ID RECORD_ITEM_TYPE_REF);


sub link_records {
  my ($self, $allowed_linked_records, $allowed_linked_record_items, %flags) = @_;

  my %allowed_linked_records = map {$_ => 1} @$allowed_linked_records;
  my %allowed_linked_record_items = map {$_ => 1} @$allowed_linked_record_items;

  return 1 unless my $from_record_ids = $self->{RECORD_ID()};

  my $from_record_type = $self->{RECORD_TYPE_REF()};
  unless ($allowed_linked_records{$from_record_type}) {
    croak("Not allowed @{[ RECORD_TYPE_REF ]}: $from_record_type");
  }

  for my $id (listify($from_record_ids)) {
    my $from_record = $from_record_type->new(id => $id)->load;
    $from_record->link_to_record($self);

    close_quotations($from_record, %flags);
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


sub close_quotations {
  my ($from_record, %flags) = @_;

  return unless $flags{close_source_quotations};
  return unless 'SL::DB::Order' eq  ref $from_record;
  return unless $from_record->type =~ /quotation/;

  $from_record->update_attributes(closed => 1);
}


1;

__END__

=encoding utf-8

=head1 NAME

SL::DB::Helper::RecordLink - creates record links that are stored in the gived objects

=head1 SYNOPSIS

    # in the consuming class
    __PCAKAGE__->after_save_hook("link_records_hook");

    sub link_records_hook {
      my ($self) = @_;
      SL::DB::Helper::RecordLink::link_records(
        $self,
        qw(SL::DB::Order),     # list of allowed record sources
        qw(SL::DB::OrderItem), # list of allowed record item sources
      )
    }

=head1 DESCRIPTION

...

=head1 METHODS

...

=head1 BUGS

None yet. :)

=head1 AUTHOR

Sven Schöling $<lt>s.schoeling@googlemail.comE<gt>

=cut
