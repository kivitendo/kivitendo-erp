package SL::DB::Manager::TaxZone;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::TaxZone' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'sortkey', 1 ],
           columns => { SIMPLE => 'ALL' } );
}

sub get_default {
    return $_[0]->get_first(where => [ obsolete => 0 ], sort_by => 'sortkey');
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Manager::TaxZone - RDBO manager for the C<tax_zones> table

=head1 FUNCTIONS

=over 4

=item C<get_default>

Returns an RDBO instance corresponding to the default taxzone. The default
taxzone is defined as the taxzone with the highest sort order (usually 1) that
is not set to obsolete.

Example:

  my $default_taxzone_id = SL::DB::Manager::TaxZone->get_default->id;


=back

=cut
