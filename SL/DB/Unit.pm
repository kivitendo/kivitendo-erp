package SL::DB::Unit;

use List::MoreUtils qw(any);
use List::Util qw(first);

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
  translations => {
    type         => 'one to many',
    class        => 'SL::DB::UnitsLanguage',
    column_map   => { name => 'unit' },
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
  my $all_units = scalar(@_) && (ref($_[0]) eq 'ARRAY') ? $_[0] : [ @_ ];
  $all_units    = SL::DB::Manager::Unit->all_units if ! @{ $all_units };
  return [
    sort { $a->sortkey <=> $b->sortkey }
    grep { $_->unit_class->name eq $self->unit_class->name }
    @{ $all_units }
  ];
}

sub base_factor {
  my ($self) = @_;

  my $cache = $::request->cache('base_factor');

  if (!defined $cache->{$self->id}) {
    $cache->{$self->id} = !$self->base_unit || !$self->factor || ($self->name eq $self->base_unit) ? 1 : $self->factor * $self->base->base_factor;
  }

  return $cache->{$self->id};
}

sub convert_to {
  my ($self, $qty, $other_unit) = @_;

  my $my_base_factor    = $self->base_factor       || 1;
  my $other_base_factor = $other_unit->base_factor || 1;

  return ($qty // 0) * $my_base_factor / $other_base_factor;
}

sub is_time_based {
  my ($self) = @_;

  return any { $_->id == $self->id } @{ SL::DB::Manager::Unit->time_based_units };
}

sub get_translation_obj {
  my ($self, $language) = @_;

  my $language_id = (ref($language) eq 'SL::DB::Language' ? $language->id : $language) || undef;

  return first { $_->language_id => $language_id } @{ $self->translations || [] };
}

sub get_translation {
  my ($self, $language, $qty) = @_;

  my $translation     = $self->name; # fallback, if no translation found
  my $translation_obj = $self->get_translation_obj(language => $language);
  if ($translation_obj) {
    $translation = (($qty // 0) > 1 || ($qty // 0) == 0) ? $translation_obj->localized_plural : $translation_obj->localized;
  }
  return $translation;
}

1;
