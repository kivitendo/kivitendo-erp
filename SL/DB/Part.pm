package SL::DB::Part;

use strict;

use Carp;
use SL::DBUtils;
use SL::DB::MetaSetup::Part;
use SL::DB::Manager::Part;

__PACKAGE__->meta->add_relationships(
  unit_obj                     => {
    type         => 'one to one',
    class        => 'SL::DB::Unit',
    column_map   => { unit => 'name' },
  },
  assemblies                     => {
    type         => 'one to many',
    class        => 'SL::DB::Assembly',
    column_map   => { id => 'id' },
  },
);

__PACKAGE__->meta->initialize;

sub is_type {
  my $self = shift;
  my $type  = lc(shift || '');

  if ($type =~ m/^part/) {
    return !$self->assembly && $self->inventory_accno_id  ? 1 : 0;

  } elsif ($type =~ m/^service/) {
    return !$self->inventory_accno_id && !$self->assembly ? 1 : 0;

  } elsif ($type =~ m/^assembl/) {
    return $self->assembly                                ? 1 : 0;

  }

  confess "Unknown type parameter '$type'";
}

sub get_sellprice_info {
  my $self   = shift;
  my %params = @_;

  confess "Missing part id" unless $self->id;

  my $object = $self->load;

  return { sellprice       => $object->sellprice,
           price_factor_id => $object->price_factor_id };
}

sub get_ordered_qty {
  my $self   = shift;
  my %result = SL::DB::Manager::Part->get_ordered_qty($self->id);

  return $result{ $self->id };
}

sub available_units {
  shift->unit_obj->convertible_units;
}

1;

__END__

=pod

=head1 NAME

SL::DB::Part: Model for the 'parts' table

=head1 SYNOPSIS

This is a standard Rose::DB::Object based model and can be used as one.

=head1 FUNCTIONS

=over 4

=item is_type $type

Tests if the current object is a part, a service or an
assembly. C<$type> must be one of the words 'part', 'service' or
'assembly' (their plurals are ok, too).

Returns 1 if the requested type matches, 0 if it doesn't and
C<confess>es if an unknown C<$type> parameter is encountered.

=item get_sellprice_info %params

Retrieves the C<sellprice> and C<price_factor_id> for a part under
different conditions and returns a hash reference with those two keys.

If C<%params> contains a key C<project_id> then a project price list
will be consulted if one exists for that project. In this case the
parameter C<country_id> is evaluated as well: if a price list entry
has been created for this country then it will be used. Otherwise an
entry without a country set will be used.

If none of the above conditions is met then the information from
C<$self> is used.

=item get_ordered_qty %params

Retrieves the quantity that has been ordered from a vendor but that
has not been delivered yet. Only open purchase orders are considered.

=item get_uncommissioned_qty %params

Retrieves the quantity that has been ordered by a customer but that
has not been commissioned yet. Only open sales orders are considered.

=back

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
