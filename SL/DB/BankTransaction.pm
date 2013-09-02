# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::BankTransaction;

use strict;

use SL::DB::MetaSetup::BankTransaction;
use SL::DB::Manager::BankTransaction;
use SL::DB::Helper::LinkedRecords;

__PACKAGE__->meta->initialize;

use SL::DB::Invoice;
use SL::DB::PurchaseInvoice;

use Data::Dumper;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
#__PACKAGE__->meta->make_manager_class;

sub compare_to {
  my ($self, $other) = @_;

  return  1 if  $self->transdate && !$other->transdate;
  return -1 if !$self->transdate &&  $other->transdate;

  my $result = 0;
  $result    = $self->transdate <=> $other->transdate if $self->transdate;
  return $result || ($self->id <=> $other->id);
}

sub linked_invoices {
  my ($self) = @_;

  #my $record_links = $self->linked_records(direction => 'both');

  my @linked_invoices;

  my $record_links = SL::DB::Manager::RecordLink->get_all(where => [ from_table => 'bank_transactions', from_id => $self->id ]);

  foreach my $record_link (@{ $record_links }) {
    push @linked_invoices, SL::DB::Manager::Invoice->find_by(id => $record_link->to_id)->invnumber         if $record_link->to_table eq 'ar';
    push @linked_invoices, SL::DB::Manager::PurchaseInvoice->find_by(id => $record_link->to_id)->invnumber if $record_link->to_table eq 'ap';
  }

#  $main::lxdebug->message(0, "linked invoices sind: " . Dumper(@linked_invoices));
#  $main::lxdebug->message(0, "record_links sind: " . Dumper($record_links));

  return [ @linked_invoices ];
}

1;
