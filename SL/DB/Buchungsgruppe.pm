package SL::DB::Buchungsgruppe;

use strict;

use SL::DB::MetaSetup::Buchungsgruppe;
use SL::DB::Manager::Buchungsgruppe;

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
