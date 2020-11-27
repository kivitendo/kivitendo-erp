package SL::Helper::Inventory::Allocation;

use strict;

my @attributes = qw(parts_id qty bin_id warehouse_id chargenumber bestbefore comment for_object_id);
my %attributes = map { $_ => 1 } @attributes;
my %mapped_attributes = (
  for_object_id => 'oe_id',
);

for my $name (@attributes) {
  no strict 'refs';
  *{"SL::Helper::Inventory::Allocation::$name"} = sub { $_[0]{$name} };
}

sub new {
  my ($class, %params) = @_;

  Carp::croak("missing attribute $_") for grep { !exists $params{$_}     } @attributes;
  Carp::croak("unknown attribute $_") for grep { !exists $attributes{$_} } keys %params;
  Carp::croak("$_ must be set")       for grep { !$params{$_} } qw(parts_id qty bin_id);
  Carp::croak("$_ must be positive")  for grep { !($params{$_} > 0) } qw(parts_id qty bin_id);

  bless { %params }, $class;
}

sub transfer_object {
  my ($self, %params) = @_;

  SL::DB::Inventory->new(
    (map {
      my $attr = $mapped_attributes{$_} // $_;
      $attr => $self->{$attr}
    } @attributes),
    %params,
  );
}

1;

=encoding utf-8

=head1 NAME

SL::Helper::Inventory::Allocation - Inventory API allocation data structure

=head1 SYNOPSIS

  # all of these need to be present
  my $allocation = SL::Helper::Inventory::Allocation->new(
    part_id           => $part->id,
    qty               => 15,
    bin_id            => $bin_obj->id,
    warehouse_id      => $bin_obj->warehouse_id,
    chargenumber      => '1823772365',           # can be undef
    bestbefore        => undef,                  # can be undef
    for_object_id     => $order->id,             # can be undef
  );


=head1 SEE ALSO

The full documentation can be found in L<SL::Helper::Inventory>

=cut
