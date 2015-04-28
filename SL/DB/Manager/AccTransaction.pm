package SL::DB::Manager::AccTransaction;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;
use SL::DBUtils;

sub object_class { 'SL::DB::AccTransaction' }

__PACKAGE__->make_manager_methods;

sub chart_link_filter {
  my ($class, $link) = @_;

  return (or => [ chart_link => $link,
                  chart_link => { like => "${link}:\%"    },
                  chart_link => { like => "\%:${link}"    },
                  chart_link => { like => "\%:${link}:\%" } ]);
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Manager::AccTransaction - Manager class for the model for the C<acc_trans> table

=head1 FUNCTIONS

=over 4

=item C<chart_link_filter $link>

Returns a query builder filter that matches acc_trans lines whose 'C<chart_link>'
field contains C<$chart_link>. Matching is done so that the exact value of
C<$chart_link> matches but not if C<$chart_link> is only a substring of a
match. Therefore C<$chart_link = 'AR'> will match the column content 'C<AR>'
or 'C<AR_paid:AR>' but not 'C<AR_amount>'.

The code and functionality was copied from the function link_filter in
SL::DB::Manager::Chart.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.de<gt>

=cut
