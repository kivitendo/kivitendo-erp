package SL::DB::Manager::Project;

use strict;

use parent qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::Project' }

__PACKAGE__->make_manager_methods;

our %project_id_column_prefixes = (
  ar              => 'global',
  ap              => 'global',
  oe              => 'global',
  delivery_orders => 'global',
);

our @tables_with_project_id_cols = qw(acc_trans ap ar delivery_order_items delivery_orders invoice oe orderitems);

sub _sort_spec {
  return (
    default    => [ 'projectnumber', 1 ],
    columns    => {
      SIMPLE   => 'ALL',
      customer => 'customer.name',
    });
}

sub is_not_used_filter {
  my ($class, $prefix) = @_;

  my $query = join ' UNION ', map {
    my $column = $project_id_column_prefixes{$_} . 'project_id';
    qq|SELECT DISTINCT ${column} FROM ${_} WHERE ${column} IS NOT NULL|
  } @tables_with_project_id_cols;

  return ("!${prefix}id" => [ \"(${query})" ]);
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Manager::Project - Manager for models for the 'project' table

=head1 SYNOPSIS

This is a standard Rose::DB::Manager based model manager and can be
used as such.

=head1 FUNCTIONS

=over 4

=item C<is_not_used_filter>

Returns an array containing a partial filter suitable for the C<query>
parameter that limits to projects that are not referenced from any
other database table.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
