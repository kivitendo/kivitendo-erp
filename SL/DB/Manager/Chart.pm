package SL::DB::Manager::Chart;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;
use DateTime;
use SL::DBUtils;

sub object_class { 'SL::DB::Chart' }

__PACKAGE__->make_manager_methods;

sub link_filter {
  my ($class, $link) = @_;

  return (or => [ link => $link,
                  link => { like => "${link}:\%"    },
                  link => { like => "\%:${link}"    },
                  link => { like => "\%:${link}:\%" } ]);
}

sub cache_taxkeys {
  my ($self, %params) = @_;

  my $date  = $params{date} || DateTime->today;
  my $cache = $::request->cache('::SL::DB::Chart::get_active_taxkey')->{$date} //= {};

  require SL::DB::TaxKey;
  my $tks = SL::DB::Manager::TaxKey->get_all;
  my %tks_by_id = map { $_->id => $_ } @$tks;

  my $rows = selectall_hashref_query($::form, $::form->get_standard_dbh, <<"", $date);
    SELECT DISTINCT ON (chart_id) chart_id, startdate, id
    FROM taxkeys
    WHERE startdate < ?
    ORDER BY chart_id, startdate DESC;

  for (@$rows) {
    $cache->{$_->{chart_id}} = $tks_by_id{$_->{id}};
  }
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
