package SL::DB::Manager::Part;

use strict;

use SL::DB::Helper::Manager;
use SL::DB::Helper::Sorted;
use SL::DB::Helper::Paginated;
use SL::DB::Helper::Filtered;
use base qw(SL::DB::Helper::Manager);

use Carp;
use SL::DBUtils;
use SL::MoreCommon qw(listify);

sub object_class { 'SL::DB::Part' }

__PACKAGE__->make_manager_methods;
__PACKAGE__->add_filter_specs(
  part_type => sub {
    my ($key, $value, $prefix) = @_;
    return __PACKAGE__->type_filter($value, $prefix);
  },
  all => sub {
    my ($key, $value, $prefix) = @_;
    return or => [ map { $prefix . $_ => $value } qw(partnumber description ean) ]
  },
  all_with_makemodel => sub {
    my ($key, $value, $prefix) = @_;
    return or => [ map { $prefix . $_ => $value } qw(partnumber description ean makemodels.model) ],
      $prefix . 'makemodels';
  },
  all_with_customer_partnumber => sub {
    my ($key, $value, $prefix) = @_;
    return or => [ map { $prefix . $_ => $value } qw(partnumber description ean customerprices.customer_partnumber) ],
      $prefix . 'customerprices';
  },
);

sub type_filter {
  my ($class, $type, $prefix) = @_;

  return () unless $type;

  $prefix //= '';

  # this is to make selections like part_type => { part => 1, service => 1 } work
  if ('HASH' eq ref $type) {
    $type = [ grep { $type->{$_} } keys %$type ];
  }

  my @types = grep { $_ } listify($type);
  my @filter;

  for my $type (@types) {
    if ($type =~ m/^part/) {
      push @filter, ($prefix . part_type => 'part');
    } elsif ($type =~ m/^service/) {
      push @filter, ($prefix . part_type => 'service');
    } elsif ($type =~ m/^assembly/) {
      push @filter, ($prefix . part_type => 'assembly');
    } elsif ($type =~ m/^assortment/) {
      push @filter, ($prefix . part_type => 'assortment');
    }
  }

  return @filter > 2 ? (or => \@filter) : @filter;
}

sub get_ordered_qty {
  my $class    = shift;
  my @part_ids = @_;

  return () unless @part_ids;

  my $placeholders = join ',', ('?') x @part_ids;
  my $query        = <<SQL;
    SELECT oi.parts_id, SUM(oi.base_qty) AS qty
    FROM orderitems oi
    LEFT JOIN oe ON (oi.trans_id = oe.id)
    WHERE (oi.parts_id IN ($placeholders))
      AND oe.record_type = 'purchase_order'
      AND (NOT COALESCE(oe.closed,    FALSE))
      AND (NOT COALESCE(oe.delivered, FALSE))
    GROUP BY oi.parts_id
SQL

  my %qty_by_id = map { $_->{parts_id} => $_->{qty} * 1 } @{ selectall_hashref_query($::form, $class->object_class->init_db->dbh, $query, @part_ids) };
  map { $qty_by_id{$_} ||= 0 } @part_ids;

  return %qty_by_id;
}

sub get_open_ordered_qty {
  my $class    = shift;
  my $part_id  = shift;
  return () unless $part_id;

  my $query = <<SQL;
WITH
open_qty AS (
  SELECT parts_id, sum(oi.qty) as sum
  FROM orderitems oi
  LEFT OUTER JOIN oe o ON (oi.trans_id = o.id)
  WHERE
    oi.parts_id = ?
    AND (NOT COALESCE(o.quotation, FALSE))
    AND (NOT COALESCE(o.closed,    FALSE))
    AND (NOT COALESCE(o.delivered, FALSE))
    AND (COALESCE(o.vendor_id, 0) <> 0)
  GROUP BY oi.parts_id
),

open_orderitems_ids AS (
  SELECT oi.id, parts_id
  FROM orderitems oi
  LEFT OUTER JOIN oe o ON (oi.trans_id = o.id)
  WHERE
    oi.parts_id = ?
    AND (NOT COALESCE(o.quotation, FALSE))
    AND (NOT COALESCE(o.closed,    FALSE))
    AND (NOT COALESCE(o.delivered, FALSE))
    AND (o.vendor_id is not null)
),

delivered_qty AS (
  SELECT parts_id, sum(qty) AS sum
  FROM delivery_order_items
  WHERE id IN (
    SELECT to_id from record_links
    WHERE
      from_id IN ( SELECT id FROM open_orderitems_ids)
      AND from_table = 'orderitems'
      AND to_table = 'delivery_order_items'
  ) AND parts_id = ?
  GROUP BY parts_id
),

open_ordered_qty AS (
  SELECT
    oq.parts_id,
    oq.sum AS ordered_sum,
    COALESCE(dq.sum,0.00) AS sum,
    sum(COALESCE(oq.sum,0.00) - COALESCE(dq.sum,0.00)) AS open_qty
  FROM open_qty oq
  LEFT JOIN delivered_qty dq ON dq.parts_id = oq.parts_id
  GROUP BY oq.parts_id, oq.sum, dq.sum
)

SELECT open_qty FROM open_ordered_qty

SQL

  my ($open_qty) = selectfirst_array_query(
    $::form, $class->object_class->init_db->dbh,
    $query, $part_id, $part_id, $part_id
  );

  $open_qty ||= 0;
  return $open_qty
}

sub _sort_spec {
  (
    default  => [ 'partnumber', 1 ],
    columns  => {
      SIMPLE => 'ALL',
    },
    nulls    => {},
  );
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Manager::Part - RDBO manager for the C<parts> table

=head1 FUNCTIONS

=over 4

=item C<get_ordered_qty @part_ids>

For each of the given part IDs the ordered quantity is
calculated. This is done by summing over all open purchase orders.

Returns a hash with the part IDs being the keys and the ordered
quantities being the values.

=item C<type_filter @types>

Constructs a partial filter for matching any of the article types
given with C<@types>. The returned partial filter is suitable for a
Rose manager query.

Each type can be either 'C<part>', 'C<service>' or 'C<assembly>'
(their plurals are recognized as well). If multiple types are given
then they're combined with C<OR>.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>,
Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
