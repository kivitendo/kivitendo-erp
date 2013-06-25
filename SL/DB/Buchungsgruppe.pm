package SL::DB::Buchungsgruppe;

use strict;

use SL::DB::MetaSetup::Buchungsgruppe;
use SL::DB::Manager::Buchungsgruppe;

__PACKAGE__->meta->add_relationship(
  inventory_account => {
    type          => 'many to one',
    class         => 'SL::DB::Chart',
    column_map    => { inventory_accno_id => 'id' },
  },
);

__PACKAGE__->meta->initialize;


sub income_accno_id {
  my ($self, $taxzone) = @_;
  my $taxzone_id = ref $taxzone && $taxzone->isa('SL::DB::TaxZone') ? $taxzone->id : $taxzone;
  my $taxzone_chart = SL::DB::Manager::TaxzoneChart->find_by(taxzone_id => $taxzone_id, buchungsgruppen_id => $self->id);
  return $taxzone_chart->income_accno_id if $taxzone_chart;
}

sub expense_accno_id {
  my ($self, $taxzone) = @_;
  my $taxzone_id = ref $taxzone && $taxzone->isa('SL::DB::TaxZone') ? $taxzone->id : $taxzone;
  my $taxzone_chart = SL::DB::Manager::TaxzoneChart->find_by(taxzone_id => $taxzone_id, buchungsgruppen_id => $self->id);
  return $taxzone_chart->expense_accno_id if $taxzone_chart;
}

sub income_account {
  my ($self, $taxzone) = @_;
  my $taxzone_id       = ref $taxzone && $taxzone->isa('SL::DB::TaxZone') ? $taxzone->id : $taxzone;
  my $taxzone_chart = SL::DB::Manager::TaxzoneChart->find_by(taxzone_id => $taxzone_id, buchungsgruppen_id => $self->id);
  return $taxzone_chart->income_accno if $taxzone_chart;
}

sub expense_account {
  my ($self, $taxzone) = @_;
  my $taxzone_id       = ref $taxzone && $taxzone->isa('SL::DB::TaxZone') ? $taxzone->id : $taxzone;
  my $taxzone_chart = SL::DB::Manager::TaxzoneChart->find_by(taxzone_id => $taxzone_id, buchungsgruppen_id => $self->id);
  return $taxzone_chart->expense_accno if $taxzone_chart;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Buchungsgruppe - RDBO wrapper for the C<buchungsgruppen> table

=head1 FUNCTIONS

=over 4

=item C<expense_accno_id $taxzone>

Return the chart ID for the expense account for the given taxzone
(either an integer between 0 and 3 inclusively or an instance of
L<SL::DB::TaxZone>).

=item C<expense_account>

Return the chart (an instance of L<SL::DB::Chart>) for the expense
account for the given taxzone (either an integer between 0 and 3
inclusively or an instance of L<SL::DB::TaxZone>).

=item C<income_accno_id>

Return the chart ID for the income account for the given taxzone
(either an integer between 0 and 3 inclusively or an instance of
L<SL::DB::TaxZone>).

=item C<income_account>

Return the chart (an instance of L<SL::DB::Chart>) for the income
account for the given taxzone (either an integer between 0 and 3
inclusively or an instance of L<SL::DB::TaxZone>).

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>,
Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
