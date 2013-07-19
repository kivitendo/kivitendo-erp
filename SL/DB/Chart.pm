package SL::DB::Chart;

use strict;

use SL::DB::MetaSetup::Chart;
use SL::DB::Manager::Chart;

__PACKAGE__->meta->add_relationships(taxkeys => { type         => 'one to many',
                                                  class        => 'SL::DB::TaxKey',
                                                  column_map   => { id => 'chart_id' },
                                                },
                                    );

__PACKAGE__->meta->initialize;

sub get_active_taxkey {
  my ($self, $date) = @_;
  $date ||= DateTime->today_local;
  require SL::DB::TaxKey;
  return SL::DB::Manager::TaxKey->get_all(query   => [ and => [ chart_id  => $self->id,
                                                                startdate => { le => $date } ] ],
                                          sort_by => "startdate DESC")->[0];
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Chart - Rose database model for the "chart" table

=head1 FUNCTIONS

=over 4

=item C<get_active_taxkey $date>

Returns the active tax key object for a given date. C<$date> defaults
to the current date if undefined.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
