package SL::DB::Manager::Part;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use Carp;
use SL::DBUtils;
use SL::MoreCommon qw(listify);

sub object_class { 'SL::DB::Part' }

__PACKAGE__->make_manager_methods;

sub type_filter {
  my ($class, $type) = @_;

  return () unless $type;

  my @types = listify($type);
  my @filter;

  for my $type (@types) {
    if ($type =~ m/^part/) {
      push @filter, (and => [ or                    => [ assembly => 0, assembly => undef ],
                       '!inventory_accno_id' => 0,
                       '!inventory_accno_id' => undef,
                     ]);
    } elsif ($type =~ m/^service/) {
      push @filter, (and => [ or => [ assembly           => 0, assembly           => undef ],
                       or => [ inventory_accno_id => 0, inventory_accno_id => undef ],
                     ]);
    } elsif ($type =~ m/^assembl/) {
      push @filter, (assembly => 1);
    }
  }

  return @filter ? (or => \@filter) : ();
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
      AND (NOT COALESCE(oe.quotation, FALSE))
      AND (NOT COALESCE(oe.closed,    FALSE))
      AND (NOT COALESCE(oe.delivered, FALSE))
      AND (COALESCE(oe.vendor_id, 0) <> 0)
    GROUP BY oi.parts_id
SQL

  my %qty_by_id = map { $_->{parts_id} => $_->{qty} * 1 } @{ selectall_hashref_query($::form, $class->object_class->init_db->dbh, $query, @part_ids) };
  map { $qty_by_id{$_} ||= 0 } @part_ids;

  return %qty_by_id;
}

1;
