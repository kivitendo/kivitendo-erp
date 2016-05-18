package SL::DB::Buchungsgruppe;

use strict;

use SL::DB::MetaSetup::Buchungsgruppe;
use SL::DB::Manager::Buchungsgruppe;
use SL::DB::Helper::ActsAsList;

__PACKAGE__->meta->initialize;

sub inventory_account { goto &inventory_accno; }

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The description is missing.') if !$self->description;
  if( $self->inventory_accno_id ) {
    require SL::DB::Chart;
    my $inventory_accno = SL::DB::Manager::Chart->find_by( id => $self->inventory_accno_id );
    push(@errors, $::locale->text('Booking group #1 needs a valid inventory account', $self->description)) unless $inventory_accno;
  } else {
    push @errors, $::locale->text('The booking group needs an inventory account.');
  };

  return @errors;
}

sub income_accno_id {
  my ($self, $taxzone) = @_;

  require SL::DB::TaxZone;
  require SL::DB::TaxzoneChart;

  my $taxzone_id = ref $taxzone && $taxzone->isa('SL::DB::TaxZone') ? $taxzone->id : $taxzone;
  my $taxzone_chart = SL::DB::Manager::TaxzoneChart->find_by(taxzone_id => $taxzone_id, buchungsgruppen_id => $self->id);
  return $taxzone_chart->income_accno_id if $taxzone_chart;
}

sub expense_accno_id {
  my ($self, $taxzone) = @_;
  require SL::DB::TaxZone;
  require SL::DB::TaxzoneChart;

  my $taxzone_id = ref $taxzone && $taxzone->isa('SL::DB::TaxZone') ? $taxzone->id : $taxzone;
  my $taxzone_chart = SL::DB::Manager::TaxzoneChart->find_by(taxzone_id => $taxzone_id, buchungsgruppen_id => $self->id);
  return $taxzone_chart->expense_accno_id if $taxzone_chart;
}

sub income_account {
  my ($self, $taxzone) = @_;

  require SL::DB::TaxZone;
  require SL::DB::TaxzoneChart;

  my $taxzone_id       = ref $taxzone && $taxzone->isa('SL::DB::TaxZone') ? $taxzone->id : $taxzone;
  my $taxzone_chart = SL::DB::Manager::TaxzoneChart->find_by(taxzone_id => $taxzone_id, buchungsgruppen_id => $self->id);
  return $taxzone_chart->income_accno if $taxzone_chart;
}

sub expense_account {
  my ($self, $taxzone) = @_;

  require SL::DB::TaxZone;
  require SL::DB::TaxzoneChart;

  my $taxzone_id       = ref $taxzone && $taxzone->isa('SL::DB::TaxZone') ? $taxzone->id : $taxzone;
  my $taxzone_chart = SL::DB::Manager::TaxzoneChart->find_by(taxzone_id => $taxzone_id, buchungsgruppen_id => $self->id);
  return $taxzone_chart->expense_accno if $taxzone_chart;
}

sub taxzonecharts {
  my ($self) = @_;
  return SL::DB::Manager::TaxzoneChart->get_all(where => [ buchungsgruppen_id => $self->id ]);
}

sub orphaned {
  my ($self) = @_;
  die 'not an accessor' if @_ > 1;

  require SL::DB::Part;
  return 0 if SL::DB::Manager::Part->get_all_count(query => [ buchungsgruppen_id => $self->id ]);
  return 1;
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
(either the DB id or an instance of L<SL::DB::TaxZone>).

=item C<expense_account>

Return the chart (an instance of L<SL::DB::Chart>) for the expense
account for the given taxzone (either the DB id or an instance of
L<SL::DB::TaxZone>).

=item C<income_accno_id>

Return the chart ID for the income account for the given taxzone
(either the DB id or an instance of L<SL::DB::TaxZone>).
L<SL::DB::TaxZone>).

=item C<income_account>

Return the chart (an instance of L<SL::DB::Chart>) for the income
account for the given taxzone (either the DB id or an instance of
L<SL::DB::TaxZone>).

=item C<orphaned>

Checks whether this Buchungsgruppe is assigned to any parts.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>,
Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
