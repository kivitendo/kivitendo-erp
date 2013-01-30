package SL::DB::Unit;

use strict;

use SL::DB::MetaSetup::Unit;
use SL::DB::Manager::Unit;
use SL::DB::Helper::ActsAsList;

__PACKAGE__->meta->add_relationships(
  base => {
    type         => 'many to one',
    class        => 'SL::DB::Unit',
    column_map   => { base_unit => 'name' },
  },
);

__PACKAGE__->meta->initialize;

#methods

sub unit_class {
  my $self   = shift;

  return $self if !$self->base_unit || $self->name eq $self->base_unit;
  return $self->base->unit_class;
}

sub convertible_units {
  my $self = shift;
  return [
    sort { $a->sortkey <=> $b->sortkey }
    grep { $_->unit_class->name eq $self->unit_class->name }
    @{ SL::DB::Manager::Unit->get_all }
  ];
}

sub base_factor {
  my ($self) = @_;

  if (!defined $self->{__base_factor}) {
    $self->{__base_factor} = !$self->base_unit || !$self->factor || ($self->name eq $self->base_unit) ? 1 : $self->factor * $self->base->base_factor;
  }

  return $self->{__base_factor};
}

sub convert_to {
  my ($self, $qty, $other_unit) = @_;

  my $my_base_factor    = $self->base_factor       || 1;
  my $other_base_factor = $other_unit->base_factor || 1;

  return $qty * $my_base_factor / $other_base_factor;
}

1;
