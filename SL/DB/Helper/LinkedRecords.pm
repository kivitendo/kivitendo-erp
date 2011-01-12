package SL::DB::Helpers::LinkedRecords;

use strict;

require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(linked_records link_to_record linked_records_sorted);

use Carp;
use Sort::Naturally;

use SL::DB::Helpers::Mappings;
use SL::DB::RecordLink;

sub linked_records {
  my $self     = shift;
  my %params   = @_;

  my $wanted   = $params{direction} || croak("Missing parameter `direction'");

  if ($wanted eq 'both') {
    my $both       = delete($params{both});
    my %from_to    = ( from => delete($params{from}) || $both,
                       to   => delete($params{to})   || $both);

    my @records    = (@{ $self->linked_records(%params, direction => 'from', from => $from_to{from}) },
                      @{ $self->linked_records(%params, direction => 'to',   to   => $from_to{to}  ) });

    my %record_map = map { ( ref($_) . $_->id => $_ ) } @records;

    return [ values %record_map ];
  }

  my $myself   = $wanted eq 'from' ? 'to' : $wanted eq 'to' ? 'from' : croak("Invalid parameter `direction'");

  my $my_table = SL::DB::Helpers::Mappings::get_table_for_package(ref($self));

  my @query    = ( "${myself}_table" => $my_table,
                   "${myself}_id"    => $self->id );

  if ($params{$wanted}) {
    my $wanted_classes = ref($params{$wanted}) eq 'ARRAY' ? $params{$wanted} : [ $params{$wanted} ];
    my $wanted_tables  = [ map { SL::DB::Helpers::Mappings::get_table_for_package($_) || croak("Invalid parameter `${wanted}'") } @{ $wanted_classes } ];
    push @query, ("${wanted}_table" => $wanted_tables);
  }

  my $links            = SL::DB::Manager::RecordLink->get_all(query => [ and => \@query ]);

  my $sub_wanted_table = "${wanted}_table";
  my $sub_wanted_id    = "${wanted}_id";

  my $records          = [];
  @query               = ref($params{query}) eq 'ARRAY' ? @{ $params{query} } : ();

  foreach my $link (@{ $links }) {
    my $manager_class = SL::DB::Helpers::Mappings::get_manager_package_for_table($link->$sub_wanted_table);
    my $object_class  = SL::DB::Helpers::Mappings::get_package_for_table($link->$sub_wanted_table);
    eval "require " . $object_class . "; 1;";
    push @{ $records }, @{ $manager_class->get_all(query => [ id => $link->$sub_wanted_id, @query ]) };
  }

  return $records;
}

sub link_to_record {
  my $self   = shift;
  my $other  = shift;
  my %params = @_;

  croak "self has no id"  unless $self->id;
  croak "other has no id" unless $other->id;

  my @directions = ([ 'from', 'to' ]);
  push @directions, [ 'to', 'from' ] if $params{bidirectional};
  my @links;

  foreach my $direction (@directions) {
    my %params = ( $direction->[0] . "_table" => SL::DB::Helper::Mappings::get_table_for_package(ref($self)),
                   $direction->[0] . "_id"    => $self->id,
                   $direction->[1] . "_table" => SL::DB::Helper::Mappings::get_table_for_package(ref($other)),
                   $direction->[1] . "_id"    => $other->id,
                 );

    my $link = SL::DB::Manager::RecordLink->find_by(and => [ %params ]);
    push @links, $link ? $link : SL::DB::RecordLink->new(%params)->save unless $link;
  }

  return wantarray ? @links : $links[0];
}

sub linked_records_sorted {
  my ($self, $sort_by, $sort_dir, %params) = @_;

  return sort_linked_records($self, $sort_by, $sort_dir, $self->linked_records(%params));
}

sub sort_linked_records {
  my ($self_or_class, $sort_by, $sort_dir, @records) = @_;

  @records  = @{ $records[0] } if (1 == scalar(@records)) && (ref($records[0]) eq 'ARRAY');
  $sort_dir = $sort_dir * 1 ? 1 : -1;

  my %numbers = ( 'SL::DB::SalesProcess'    => sub { $_[0]->id },
                  'SL::DB::Order'           => sub { $_[0]->quotation ? $_[0]->quonumber : $_[0]->ordnumber },
                  'SL::DB::DeliveryOrder'   => sub { $_[0]->donumber },
                  'SL::DB::Invoice'         => sub { $_[0]->invnumber },
                  'SL::DB::PurchaseInvoice' => sub { $_[0]->invnumber },
                  UNKNOWN                   => '9999999999999999',
                );
  my $number_xtor = sub {
    my $number = $numbers{ ref($_[0]) };
    $number    = $number->($_[0]) if ref($number) eq 'CODE';
    return $number || $numbers{UNKNOWN};
  };
  my $number_comparator = sub {
    my $number_a = $number_xtor->($a);
    my $number_b = $number_xtor->($b);

    ncmp($number_a, $number_b) * $sort_dir;
  };

  my %scores;
  %scores = ( 'SL::DB::SalesProcess'    =>  10,
              'SL::DB::Order'           =>  sub { $scores{ $_[0]->type } },
              sales_quotation           =>  20,
              sales_order               =>  30,
              sales_delivery_order      =>  40,
              'SL::DB::DeliveryOrder'   =>  sub { $scores{ $_[0]->type } },
              'SL::DB::Invoice'         =>  50,
              request_quotation         => 120,
              purchase_order            => 130,
              purchase_delivery_order   => 140,
              'SL::DB::PurchaseInvoice' => 150,
              UNKNOWN                   => 999,
            );
  my $score_xtor = sub {
    my $score = $scores{ ref($_[0]) };
    $score    = $score->($_[0]) if ref($score) eq 'CODE';
    return $score || $scores{UNKNOWN};
  };
  my $type_comparator = sub {
    my $score_a = $score_xtor->($a);
    my $score_b = $score_xtor->($b);

    $score_a == $score_b ? $number_comparator->() : ($score_a <=> $score_b) * $sort_dir;
  };

  my $today     = DateTime->today_local;
  my $date_xtor = sub {
      $_[0]->can('transdate_as_date') ? $_[0]->transdate_as_date
    : $_[0]->can('itime_as_date')     ? $_[0]->itime_as_date
    :                                   $today;
  };
  my $date_comparator = sub {
    my $date_a = $date_xtor->($a);
    my $date_b = $date_xtor->($b);

    ($date_a <=> $date_b) * $sort_dir;
  };

  my $comparator = $sort_by eq 'number' ? $number_comparator
                 : $sort_by eq 'date'   ? $date_comparator
                 :                        $type_comparator;

  return [ sort($comparator @records) ];
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
C<record_links>. The mandatory parameter C<direction> (either C<from>,
C<to> or C<both>) determines whether the function retrieves records
that link to C<$self> (for C<direction> = C<to>) or that are linked
from C<$self> (for C<direction> = C<from>). For C<direction = both>
all records linked from or to C<$self> are returned.

The optional parameter C<from> or C<to> (same as C<direction>)
contains the package names of Rose models for table limitation. It can
be a single model name as a single scalar or multiple model names in
an array reference in which case all links matching any of the model
names will be returned.

If you only need invoices created from an order C<$order> then the
call could look like this:

  my $invoices = $order->linked_records(direction => 'to',
                                        to        => 'SL::DB::Invoice');

The optional parameter C<query> can be used to limit the records
returned. The following call limits the earlier example to invoices
created today:

  my $invoices = $order->linked_records(direction => 'to',
                                        to        => 'SL::DB::Invoice',
                                        query     => [ transdate => DateTime->today_local ]);

Returns an array reference.

=item C<link_to_record $record, %params>

Will create an entry in the table C<record_links> with the C<from>
side being C<$self> and the C<to> side being C<$record>. Will only
insert a new entry if such a link does not already exist.

If C<$params{bidirectional}> is trueish then another link will be
created with the roles of C<from> and C<to> reversed. This link will
also only be created if it doesn't exist already.

In scalar contenxt returns either the existing link or the newly
created one as an instance of C<SL::DB::RecordLink>. In array context
it returns an array of links (one entry if C<$params{bidirectional}>
is falsish and two entries if it is trueish).

=item C<sort_linked_records $sort_by, $sort_dir, @records>

Sorts linked records by C<$sort_by> in the direction given by
C<$sort_dir> (trueish = ascending, falsish = descending). C<@records>
can be either a single array reference or or normal array.

C<$sort_by> can be one of the following strings:

=over 2

=item * C<type>

Sort by type first and by record number second. The type order
reflects the order in which records are usually processed by the
employees: sales processes, sales quotations, sales orders, sales
delivery orders, invoices; requests for quotation, purchase orders,
purchase delivery orders, purchase invoices.

=item * C<number>

Sort by the record's running number.

=item * C<date>

Sort by the date the record was created or applies to.

=back

Returns a hash reference.

Can be called both as a class or as an instance function.

This function is not exported.

=item C<linked_records_sorted $sort_by, $sort_dir, %params>

Returns the result of L</linked_records> sorted by
L</sort_linked_records>. C<%params> is passed to
L</linked_records>. C<$sort_by> and C<$sort_dir> are passed to
L</sort_linked_records>.

=back

=head1 EXPORTS

This mixin exports the functions L</linked_records>,
L</link_to_record> and L</linked_records_sorted>.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
