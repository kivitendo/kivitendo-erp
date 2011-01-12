package SL::DB::Helpers::LinkedRecords;

require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(linked_records);

use Carp;

use SL::DB::Helpers::Mappings;
use SL::DB::RecordLink;

sub linked_records {
  my $self     = shift;
  my %params   = @_;

  my $wanted   = $params{direction} || croak("Missing parameter `direction'");
  my $myself   = $wanted eq 'from' ? 'to' : $wanted eq 'to' ? 'from' : croak("Invalid parameter `direction'");

  my $my_table = SL::DB::Helpers::Mappings::get_table_for_package(ref($self));

  my @query    = ( "${myself}_table" => $my_table,
                   "${myself}_id"    => $self->id );

  if ($params{$wanted}) {
    my $wanted_table = SL::DB::Helpers::Mappings::get_table_for_package($params{$wanted}) || croak("Invalid parameter `${wanted}'");
    push @query, ("${wanted}_table" => $wanted_table);
  }

  my $links            = SL::DB::Manager::RecordLink->get_all(query => [ and => \@query ]);

  my $sub_wanted_table = "${wanted}_table";
  my $sub_wanted_id    = "${wanted}_id";

  my $records          = [];
  @query               = ref($params{query}) eq 'ARRAY' ? @{ $params{query} } : ();

  foreach my $link (@{ $links }) {
    my $class = SL::DB::Helpers::Mappings::get_manager_package_for_table($link->$sub_wanted_table);
    push @{ $records }, @{ $class->get_all(query => [ id => $link->$sub_wanted_id, @query ]) };
  }

  return $records;
}

1;

__END__

=encoding utf8

=head1 NAME

SL::DB::Helpers::LinkedRecords - Mixin for retrieving linked records via the table C<record_links>

=head1 FUNCTIONS

=over 4

=item C<linked_records %params>

Retrieves records linked from or to C<$self> via the table
C<record_links>. The mandatory parameter C<direction> (either C<from>
or C<to>) determines whether the function retrieves records that link
to C<$self> (for C<direction> = C<to>) or that are linked from
C<$self> (for C<direction> = C<from>).

The optional parameter C<from> or C<to> (same as C<direction>)
contains the package name of a Rose model for table limitation. If you
only need invoices created from an order C<$order> then the call could
look like this:

  my $invoices = $order->linked_records(direction => 'to',
                                        to        => 'SL::DB::Invoice');

The optional parameter C<query> can be used to limit the records
returned. The following call limits the earlier example to invoices
created today:

  my $invoices = $order->linked_records(direction => 'to',
                                        to        => 'SL::DB::Invoice',
                                        query     => [ transdate => DateTime->today_local ]);

Returns an array reference.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
