package SL::DB::Manager::Chart;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::Chart' }

__PACKAGE__->make_manager_methods;

sub link_filter {
  my ($class, $link) = @_;

  return (or => [ link => $link,
                  link => { like => "${link}:\%"    },
                  link => { like => "\%:${link}"    },
                  link => { like => "\%:${link}:\%" } ]);
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Manager::Chart - Manager class for the model for the C<chart> table

=head1 FUNCTIONS

=over 4

=item C<link_filter $link>

Returns a query builder filter that matches charts whose 'C<link>'
field contains C<$link>. Matching is done so that the exact value of
C<$link> matches but not if C<$link> is only a substring of a
match. Therefore C<$link = 'AR'> will match the column content 'C<AR>'
or 'C<AR_paid:AR>' but not 'C<AR_amount>'.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
