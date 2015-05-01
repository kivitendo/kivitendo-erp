# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::AccTransaction;

use strict;

use SL::DB::MetaSetup::AccTransaction;
use SL::DB::Manager::AccTransaction;
use SL::Locale::String qw(t8);

require SL::DB::GLTransaction;
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

sub record {
  my ($self) = @_;

  my @classes = qw(Invoice PurchaseInvoice GLTransaction);

  foreach my $class ( @classes ) {
    $class = 'SL::DB::' . $class;
    my $record = $class->new(id => $self->trans_id);
    return $record if $record->load(speculative => 1);
  };

};

sub get_type {
  my $self = shift;

  my $ref = ref $self->record;

  return "ar" if $ref->isa('SL::DB::Invoice');
  return "ap" if $ref->isa('SL::DB::PurchaseInvoice');
  return "gl" if $ref->isa('SL::DB::GLTransaction');

  die "Can't find trans_id " . $self->trans_id . " in ar, ap or gl" unless $ref;

};

sub transaction_name {
  my $self = shift;

  my $ref = ref $self->record;
  my $name = "trans_id: " . $self->trans_id;
  if ( $self->get_type eq 'ar' ) {
    $name .= " (" . $self->record->abbreviation . " " . t8("AR") . ") " . t8("Invoice Number") . ": " . $self->record->invnumber;
  } elsif ( $self->get_type eq 'ap' ) {
    $name .= " (" . $self->record->abbreviation . " " . t8("AP") . ") " . t8("Invoice Number") . ": " . $self->record->invnumber;
  } elsif ( $self->get_type eq 'gl' ) {
    $name = "trans_id: " . $self->trans_id . " (" . $self->record->abbreviation . ") " . $self->record->reference . " - " . $self->record->description;
  } else {
    die "can't determine type of acc_trans line with trans_id " . $self->trans_id;
  };

  $name .= "   " . t8("Date") . ": " . $self->transdate->to_kivitendo;

  return $name;

};

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

=item C<get_type>

Returns the type of transaction the acc_trans entry belongs to: ar, ap or gl.

Example:
 my $acc = SL::DB::Manager::AccTransaction->get_first();
 my $type = $acc->get_type;

=item C<transaction_name>

Generate a meaningful transaction name for an acc_trans line from the
corresponding ar/ap/gl object, a combination of trans_id,
invnumber/description, abbreviation. Can be used for better error output of the
DATEV export and contains some database information, e.g. the trans_id, and is
a kind of displayable_name for debugging or in the console.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson E<lt>information@kivitendo-premium.deE<gt>

=cut
