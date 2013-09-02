# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::AccTransaction;

use strict;

use SL::DB::MetaSetup::AccTransaction;

use SL::DB::GLTransaction;
require SL::DB::Invoice;
require SL::DB::PurchaseInvoice;

__PACKAGE__->meta->add_relationship(
  ar => {
    type         => 'many to one',
    class        => 'SL::DB::Invoice',
    column_map   => { trans_id => 'id' },
  },
  ap => {
    type         => 'many to one',
    class        => 'SL::DB::PurchaseInvoice',
    column_map   => { trans_id => 'id' },
  },
  gl => {
    type         => 'many to one',
    class        => 'SL::DB::GLTransaction',
    column_map   => { trans_id => 'id' },
  },
);

__PACKAGE__->meta->initialize;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

sub record {
  my ($self) = @_;

  my @classes = qw(Invoice PurchaseInvoice GLTransaction);

  foreach my $class ( @classes ) {
    $class = 'SL::DB::' . $class;
    my $record = $class->new(id => $self->trans_id);
    return $record if $record->load(speculative => 1);
  };

};

sub get_transaction {
  my ($self) = @_;

  my $transaction = SL::DB::Manager::GLTransaction->find_by(id => $self->trans_id);
  $transaction = SL::DB::Manager::Invoice->find_by(id => $self->trans_id)         if not defined $transaction;
  $transaction = SL::DB::Manager::PurchaseInvoice->find_by(id => $self->trans_id) if not defined $transaction;

  return $transaction;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::AccTransaction: Rose model for transactions (table "acc_trans")

=head1 FUNCTIONS

=over 4

=item C<record>

Returns the ar, ap or gl object of the current acc_trans object.

Example:
  my $acc_trans = SL::DB::Manager::AccTransaction->find_by( trans_id => '427' );
  my $record = $acc_trans->record;

Each acc_trans entry is associated with an ar, ap or gl record. If we only have
an acc_trans object, and we want to find out which kind of record it belongs
to, we have to look for its trans_id in the tables ar, ap and gl. C<record>
does this for you and returns an Invoice, PurchaseInvoice or GLTransaction
object.

We use the Rose::DB::Object load function with the C<speculative> parameter for
each record type, which returns true if the load was successful, so we don't
bother to check the ref of the object.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson E<lt>information@kivitendo-premium.deE<gt>

=cut
