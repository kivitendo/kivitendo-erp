# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Buchungsgruppe;

use strict;

use SL::DB::MetaSetup::Buchungsgruppe;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

sub income_accno_id {
  my ($self, $taxzone) = @_;
  my $taxzone_id = ref $taxzone && $taxzone->isa('SL::DB::TaxZone') ? $taxzone->id : $taxzone;
  my $method = 'income_accno_id_' . $taxzone_id;

  return $self->$method;
}

sub expense_accno_id {
  my ($self, $taxzone) = @_;
  my $taxzone_id = ref $taxzone && $taxzone->isa('SL::DB::TaxZone') ? $taxzone->id : $taxzone;
  my $method = 'expense_accno_id_' . $taxzone_id;

  return $self->$method;
}

1;
