package SL::DB::Buchungsgruppe;

use strict;

use SL::DB::MetaSetup::Buchungsgruppe;
use SL::DB::Manager::Buchungsgruppe;

__PACKAGE__->meta->add_relationship(
  inventory_account => {
    type          => 'many to one',
    class         => 'SL::DB::Chart',
    column_map    => { income_accno_id_0 => 'id' },
  },
  income_account_0 => {
    type         => 'many to one',
    class        => 'SL::DB::Chart',
    column_map   => { income_accno_id_0 => 'id' },
  },
  income_account_1 => {
    type         => 'many to one',
    class        => 'SL::DB::Chart',
    column_map   => { income_accno_id_1 => 'id' },
  },
  income_account_2 => {
    type         => 'many to one',
    class        => 'SL::DB::Chart',
    column_map   => { income_accno_id_2 => 'id' },
  },
  income_account_3 => {
    type         => 'many to one',
    class        => 'SL::DB::Chart',
    column_map   => { income_accno_id_3 => 'id' },
  },
  expense_account_0 => {
    type         => 'many to one',
    class        => 'SL::DB::Chart',
    column_map   => { expense_accno_id_0 => 'id' },
  },
  expense_account_1 => {
    type         => 'many to one',
    class        => 'SL::DB::Chart',
    column_map   => { expense_accno_id_1 => 'id' },
  },
  expense_account_2 => {
    type         => 'many to one',
    class        => 'SL::DB::Chart',
    column_map   => { expense_accno_id_2 => 'id' },
  },
  expense_account_3 => {
    type         => 'many to one',
    class        => 'SL::DB::Chart',
    column_map   => { expense_accno_id_3 => 'id' },
  },
);

__PACKAGE__->meta->initialize;


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

sub income_account {
  my ($self, $taxzone) = @_;
  my $taxzone_id       = ref $taxzone && $taxzone->isa('SL::DB::TaxZone') ? $taxzone->id : $taxzone;
  my $method           = 'income_account_' . $taxzone_id;

  return $self->$method;
}

sub expense_account {
  my ($self, $taxzone) = @_;
  my $taxzone_id       = ref $taxzone && $taxzone->isa('SL::DB::TaxZone') ? $taxzone->id : $taxzone;
  my $method           = 'expense_account_' . $taxzone_id;

  return $self->$method;
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
