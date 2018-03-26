package SL::DB::Helper::LinkedRecords;

use strict;

require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(linked_records link_to_record);

use Carp;
use List::MoreUtils qw(any);
use List::UtilsBy qw(uniq_by);
use Sort::Naturally;
use SL::DBUtils;

use SL::DB::Helper::Mappings;
use SL::DB::RecordLink;

sub linked_records {
  my ($self, %params) = @_;

  my %sort_spec       = ( by  => delete($params{sort_by}),
                          dir => delete($params{sort_dir}) );
  my $filter          =  delete $params{filter};

  my $records         = _linked_records_implementation($self, %params);
  $records            = filter_linked_records($self, $filter, @{ $records })                       if $filter;
  $records            = sort_linked_records($self, $sort_spec{by}, $sort_spec{dir}, @{ $records }) if $sort_spec{by};

  return $records;
}

sub _linked_records_implementation {
  my $self     = shift;
  my %params   = @_;

  my $wanted   = $params{direction};

  if (!$wanted) {
    if ($params{to} && $params{from}) {
      $wanted = 'both';
    } elsif ($params{to}) {
      $wanted = 'to';
    } elsif ($params{from}) {
      $wanted = 'from';
    } else {
      $wanted = 'both';
    }
  }

  if ($wanted eq 'both') {
    my $both       = delete($params{both});
    my %from_to    = ( from => delete($params{from}) || $both,
                       to   => delete($params{to})   || $both);

    if ($params{batch} && $params{by_id}) {
      my %results;
      my @links = (
        _linked_records_implementation($self, %params, direction => 'from', from => $from_to{from}),
        _linked_records_implementation($self, %params, direction => 'to',   to   => $from_to{to}  ),
      );

      for my $by_id (@links) {
        for (keys %$by_id) {
          $results{$_} = defined $results{$_}
                       ? [ uniq_by { $_->id } @{ $results{$_} }, @{ $by_id->{$_} } ]
                       : $by_id->{$_};
        }
      }

      return \%results;
    } else {
      my @records    = (@{ _linked_records_implementation($self, %params, direction => 'from', from => $from_to{from}) },
                        @{ _linked_records_implementation($self, %params, direction => 'to',   to   => $from_to{to}  ) });

      my %record_map = map { ( ref($_) . $_->id => $_ ) } @records;

      return [ values %record_map ];
    }
  }

  if ($params{via}) {
    croak("Cannot use 'via' without '${wanted}_table'")             if !$params{$wanted};
    croak("Cannot use 'via' with '${wanted}_table' being an array") if ref $params{$wanted};
  }

  my $myself           = $wanted eq 'from' ? 'to' : $wanted eq 'to' ? 'from' : croak("Invalid parameter `direction'");
  my $my_table         = SL::DB::Helper::Mappings::get_table_for_package(ref($self));

  my $sub_wanted_table = "${wanted}_table";
  my $sub_wanted_id    = "${wanted}_id";
  my $sub_myself_id    = "${myself}_id";

  my ($wanted_classes, $wanted_tables);
  if ($params{$wanted}) {
    $wanted_classes = ref($params{$wanted}) eq 'ARRAY' ? $params{$wanted} : [ $params{$wanted} ];
    $wanted_tables  = [ map { SL::DB::Helper::Mappings::get_table_for_package($_) || croak("Invalid parameter `${wanted}'") } @{ $wanted_classes } ];
  }

  my @get_objects_query = ref($params{query}) eq 'ARRAY' ? @{ $params{query} } : ();
  my $get_objects       = sub {
    my ($links)        = @_;
    return [] unless @$links;

    my %classes;
    push @{ $classes{ $_->$sub_wanted_table } //= [] }, $_->$sub_wanted_id for @$links;

    my @objs;
    for (keys %classes) {
      my $manager_class = SL::DB::Helper::Mappings::get_manager_package_for_table($_);
      my $object_class  = SL::DB::Helper::Mappings::get_package_for_table($_);
      eval "require " . $object_class . "; 1;";

      push @objs, @{ $manager_class->get_all(
        query         => [ id => $classes{$_}, @get_objects_query ],
        (with_objects => $params{with_objects}) x !!$params{with_objects},
        inject_results => 1,
      ) };
    }

    my %objs_by_id = map { $_->id => $_ } @objs;

    for (@$links) {
      if ('ARRAY' eq ref $objs_by_id{$_->$sub_wanted_id}->{_record_link}) {
        push @{ $objs_by_id{$_->$sub_wanted_id}->{_record_link_direction} }, $wanted;
        push @{ $objs_by_id{$_->$sub_wanted_id}->{_record_link          } }, $_;
      } elsif ($objs_by_id{$_->$sub_wanted_id}->{_record_link}) {
        $objs_by_id{$_->$sub_wanted_id}->{_record_link_direction} = [
          $objs_by_id{$_->$sub_wanted_id}->{_record_link_direction},
          $wanted,
        ];
        $objs_by_id{$_->$sub_wanted_id}->{_record_link}           = [
          $objs_by_id{$_->$sub_wanted_id}->{_record_link},
          $_,
        ];
      } else {
        $objs_by_id{$_->$sub_wanted_id}->{_record_link_direction} = $wanted;
        $objs_by_id{$_->$sub_wanted_id}->{_record_link}           = $_;
      }
    }

    return \@objs;
  };

  # If no 'via' is given then use a simple(r) method for querying the wanted objects.
  if (!$params{via} && !$params{recursive}) {
    my @query = ( "${myself}_table" => $my_table,
                  "${myself}_id"    => $params{batch} ? $params{batch} : $self->id );
    push @query, ( "${wanted}_table" => $wanted_tables ) if $wanted_tables;

    my $links = SL::DB::Manager::RecordLink->get_all(query => [ and => \@query ]);
    my $objs  = $get_objects->($links);

    if ($params{batch} && $params{by_id}) {
      return {
        map {
          my $id = $_;
          $_ => [
            grep {
              $_->{_record_link}->$sub_myself_id == $id
            } @$objs
          ]
        } @{ $params{batch} }
      }
    } else {
      return $objs;
    }
  }

  # More complex handling for the 'via' case.
  if ($params{via}) {
    die 'batch mode is not supported with via' if $params{batch};

    my @sources = ( $self );
    my @targets = map { SL::DB::Helper::Mappings::get_table_for_package($_) } @{ ref($params{via}) ? $params{via} : [ $params{via} ] };
    push @targets, @{ $wanted_tables } if $wanted_tables;

    my %seen = map { ($_->meta->table . $_->id => 1) } @sources;

    while (@targets) {
      my @new_sources = @sources;
      foreach my $src (@sources) {
        my @query = ( "${myself}_table" => $src->meta->table,
                      "${myself}_id"    => $src->id,
                      "${wanted}_table" => \@targets );
        push @new_sources,
             @{ $get_objects->([
               grep { !$seen{$_->$sub_wanted_table . $_->$sub_wanted_id} }
               @{ SL::DB::Manager::RecordLink->get_all(query => [ and => \@query ]) }
             ]) };
      }

      @sources = @new_sources;
      %seen    = map { ($_->meta->table . $_->id => 1) } @sources;
      shift @targets;
    }

    my %wanted_tables_map = map  { ($_ => 1) } @{ $wanted_tables };
    return [ grep { $wanted_tables_map{$_->meta->table} } @sources ];
  }

  # And lastly recursive mode
  if ($params{recursive}) {
    my ($id_token, @ids);
    if ($params{batch}) {
      $id_token = sprintf 'IN (%s)', join ', ', ('?') x @{ $params{batch} };
      @ids      = @{ $params{batch} };
    } else {
      $id_token = '= ?';
      @ids      = ($self->id);
    }

    # don't use rose retrieval here. too slow.
    # instead use recursive sql to get all the linked record_links entries and retrieve the objects from there
    my $query = <<"";
      WITH RECURSIVE record_links_rec_${wanted}(id, from_table, from_id, to_table, to_id, depth, path, cycle) AS (
        SELECT id, from_table, from_id, to_table, to_id,
          1, ARRAY[id], false
        FROM record_links
        WHERE ${myself}_id $id_token and ${myself}_table = ?
      UNION ALL
        SELECT rl.id, rl.from_table, rl.from_id, rl.to_table, rl.to_id,
          rlr.depth + 1, path || rl.id, rl.id = ANY(path)
        FROM record_links rl, record_links_rec_${wanted} rlr
        WHERE rlr.${wanted}_id = rl.${myself}_id AND rlr.${wanted}_table = rl.${myself}_table AND NOT cycle
      )
      SELECT DISTINCT ON (${wanted}_table, ${wanted}_id)
        id, from_table, from_id, to_table, to_id, path, depth FROM record_links_rec_${wanted}
      WHERE NOT cycle
      ORDER BY ${wanted}_table, ${wanted}_id, depth ASC;

    my $links     = selectall_hashref_query($::form, $::form->get_standard_dbh, $query, @ids, $self->meta->table);

    if (!@$links) {
      return $params{by_id} ? {} : [];
    }

    my $link_objs = SL::DB::Manager::RecordLink->get_all(query => [ id => [ map { $_->{id} } @$links ] ]);
    my $objects = $get_objects->($link_objs);

    my %links_by_id = map { $_->{id} => $_ } @$links;

    if ($params{save_path}) {
       for (@$objects) {
         for my $record_link ('ARRAY' eq ref $_->{_record_link} ? @{ $_->{_record_link} } : $_->{_record_link}) {
           my $link = $links_by_id{$record_link->id};
           my $intermediate_links = SL::DB::Manager::RecordLink->get_all(query => [ id => $link->{path} ]);
           $_->{_record_link_path}     = $link->{path};
           $_->{_record_link_obj_path} = $get_objects->($intermediate_links);
           $_->{_record_link_depth}    = $link->{depth};
         }
       }
    }

    if ($params{batch} && $params{by_id}) {
      my %link_obj_by_id = map { $_->id => $_ } @$link_objs;
      return +{
        map {
         my $id = $_;
         $id => [
           grep {
             any {
               $link_obj_by_id{
                 $links_by_id{$_->id}->{path}->[0]
                }->$sub_myself_id == $id
             } 'ARRAY' eq $_->{_record_link} ? @{ $_->{_record_link} } : $_->{_record_link}
           } @$objects
         ]
        } @{ $params{batch} }
      };
    } else {
      return $objects;
    }
  }
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
    my %data = ( $direction->[0] . "_table" => SL::DB::Helper::Mappings::get_table_for_package(ref($self)),
                 $direction->[0] . "_id"    => $self->id,
                 $direction->[1] . "_table" => SL::DB::Helper::Mappings::get_table_for_package(ref($other)),
                 $direction->[1] . "_id"    => $other->id,
               );

    my $link = SL::DB::Manager::RecordLink->find_by(and => [ %data ]);
    push @links, $link ? $link : SL::DB::RecordLink->new(%data)->save;
  }

  return wantarray ? @links : $links[0];
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
                  'SL::DB::RequirementSpec' => sub { $_[0]->id },
                  'SL::DB::Letter'          => sub { $_[0]->letternumber },
                  'SL::DB::ShopOrder'       => sub { $_[0]->shop_ordernumber },
                  'SL::DB::EmailJournal'    => sub { $_[0]->id },
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
              'SL::DB::RequirementSpec' =>  15,
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
              'SL::DB::PurchaseInvoice' => 150,
              'SL::DB::Letter'          => 200,
              'SL::DB::ShopOrder'       => 250,
              'SL::DB::EmailJournal'    => 300,
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
      $_[0]->can('transdate_as_date') ? $_[0]->transdate
    : $_[0]->can('itime_as_date')     ? $_[0]->itime->clone->truncate(to => 'day')
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

sub filter_linked_records {
  my ($self_or_class, $filter, @records) = @_;

  if ($filter eq 'accessible') {
    my $employee = SL::DB::Manager::Employee->current;
    @records     = grep { !$_->can('may_be_accessed') || $_->may_be_accessed($employee) } @records;
  } else {
    croak "Unsupported filter parameter '${filter}'";
  }

  return \@records;
}

1;

__END__

=encoding utf8

=head1 NAME

SL::DB::Helper::LinkedRecords - Mixin for retrieving linked records via the table C<record_links>

SYNOPSIS

  # In SL::DB::<Object>
  use SL::DB::Helper::LinkedRecords;

  # later in consumer code
  # retrieve all links in both directions
  my @linked_objects = $order->linked_records;

  # only links to Invoices
  my @linked_objects = $order->linked_records(
    to        => 'Invoice',
  );

  # more than one target
  my @linked_objects = $order->linked_records(
    to        => [ 'Invoice', 'Order' ],
  );

  # more than one direction
  my @linked_objects = $order->linked_records(
    both      => 'Invoice',
  );

  # more than one direction and different targets
  my @linked_objects = $order->linked_records(
    to        => 'Invoice',
    from      => 'Order',
  );

  # via over known classes
  my @linked_objects = $order->linked_records(
    to        => 'Invoice',
    via       => 'DeliveryOrder',
  );
  my @linked_objects = $order->linked_records(
    to        => 'Invoice',
    via       => [ 'Order', 'DeliveryOrder' ],
  );

  # recursive
  my @linked_objects = $order->linked_records(
    recursive => 1,
  );


  # limit direction when further params contain additional keys
  my %params = (to => 'Invoice', from => 'Order');
  my @linked_objects = $order->linked_records(
    direction => 'to',
    %params,
  );

  # add a new link
  $order->link_to_record($invoice);
  $order->link_to_record($purchase_order, bidirectional => 1);


=head1 FUNCTIONS

=over 4

=item C<linked_records %params>

Retrieves records linked from or to C<$self> via the table C<record_links>.

The optional parameter C<direction> (either C<from>, C<to> or C<both>)
determines whether the function retrieves records that link to C<$self> (for
C<direction> = C<to>) or that are linked from C<$self> (for C<direction> =
C<from>). For C<direction = both> all records linked from or to C<$self> are
returned.

The optional parameter C<from> or C<to> (same as C<direction>) contains the
package names of Rose models for table limitation (the prefix C<SL::DB::> is
optional). It can be a single model name as a single scalar or multiple model
names in an array reference in which case all links matching any of the model
names will be returned.

If no parameter C<direction> is given, but any of C<to>, C<from> or C<both>,
then C<direction> is inferred accordingly. If neither are given, C<direction> is
set to C<both>.

The optional parameter C<via> can be used to retrieve all documents that may
have intermediate documents inbetween. It is an array reference of Rose package
names for the models that may be intermediate link targets. One example is
retrieving all invoices for a given quotation no matter whether or not orders
and delivery orders have been created. If C<via> is given then C<from> or C<to>
(depending on C<direction>) must be given as well, and it must then not be an
array reference.

Examples:

If you only need invoices created directly from an order C<$order> (no
delivery orders in between) then the call could look like this:

  my $invoices = $order->linked_records(
    direction => 'to',
    to        => 'Invoice',
  );

Retrieving all invoices from a quotation no matter whether or not
orders or delivery orders were created:

  my $invoices = $quotation->linked_records(
    direction => 'to',
    to        => 'Invoice',
    via       => [ 'Order', 'DeliveryOrder' ],
  );

The optional parameter C<query> can be used to limit the records
returned. The following call limits the earlier example to invoices
created today:

  my $invoices = $order->linked_records(
    direction => 'to',
    to        => 'Invoice',
    query     => [ transdate => DateTime->today_local ],
  );

In case you don't know or care which or how many objects are visited the flag
C<recursive> can be used. It searches all reachable objects in the given direction:

  my $records = $order->linked_records(
    direction => 'to',
    recursive => 1,
  );

Only link chains of the same type will be considered. So even with direction
both, this

  order 1 ---> invoice <--- order 2

started from order 1 will only find invoice. If an object is found both in each
direction, only one copy will be returned. The recursion is cycle protected,
and will not recurse infinitely. Cycles are defined by the same link being
visited twice, so this


  order 1 ---> order 2 <--> delivery order
                 |
                 `--------> invoice

will find the path o1 -> o2 -> do -> o2 -> i without considering it a cycle.

The optional extra flag C<save_path> will give you extra information saved in
the returned objects:

  my $records = $order->linked_records(
    direction => 'to',
    recursive => 1,
    save_path => 1,
  );

Every record will have two fields set:

=over 2

=item C<_record_link_path>

An array with the ids of the visited links. The shortest paths will be
preferred, so in the previous example this would contain the ids of o1-o2 and
o2-i.

=item C<_record_link_depth>

Recursion depth when this object was found. Equal to the number of ids in
C<_record_link_path>

=back

Since record_links is comparatively expensive to call, you will want to cache
the results for multiple objects if you know in advance you'll need them.

You can pass the optional argument C<batch> with an array ref of ids which will
be used instead of the id of the invocant. You still need to call it as a
method on a valid object, because table information is inferred from there.

C<batch> mode will currenty not work with C<via>.

The optional flag C<by_id> will return the objects sorted into a hash instead
of a plain array. Calling C<<recursive => 1, batch => [1,2], by_id => 1>> on
 order 1:

  order 1 --> delivery order 1 --> invoice 1
  order 2 --> delivery order 2 --> invoice 2

will give you:

  { 1 => [ delivery order 1, invoice 1 ],
    2 => [ delivery order 2, invoice 1 ], }

you may then cache these as you see fit.


The optional parameters C<$params{sort_by}> and C<$params{sort_dir}>
can be used in order to sort the result. If C<$params{sort_by}> is
trueish then the result is sorted by calling L</sort_linked_records>.

The optional parameter C<$params{filter}> controls whether or not the
result is filtered. Supported values are:

=over 2

=item C<accessible>

Removes all objects for which the function C<may_be_accessed> from the
mixin L<SL::DB::Helper::MayBeAccessed> exists and returns falsish for
the current employee.

=back

Returns an array reference. Each element returned is a Rose::DB
instance. Additionally several elements in the element returned are
set to special values:

=over 2

=item C<_record_link_direction>

Either C<from> or C<to> indicating the direction. C<from> means that
this object is the source in the link.

=item C<_record_link>

The actual database link object (an instance of L<SL::DB::RecordLink>).

=back

=item C<link_to_record $record, %params>

Will create an entry in the table C<record_links> with the C<from>
side being C<$self> and the C<to> side being C<$record>. Will only
insert a new entry if such a link does not already exist.

If C<$params{bidirectional}> is trueish then another link will be
created with the roles of C<from> and C<to> reversed. This link will
also only be created if it doesn't exist already.

In scalar context returns either the existing link or the newly
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

Sort by the transdate of the record was created or applies to.

Note: If the latter has a default setting it will always mask the creation time.

=back

Returns an array reference.

Can only be called both as a class function since it is not exported.

=back

=head1 EXPORTS

This mixin exports the functions L</linked_records> and
L</link_to_record>.

=head1 BUGS

Nothing here yet.

=head1 TODO

 * C<recursive> should take a query param depth and cut off there
 * C<recursive> uses partial distinct which is known to be not terribly fast on
   a million entry table. replace with a better statement if this ever becomes
   an issue.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>
Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
