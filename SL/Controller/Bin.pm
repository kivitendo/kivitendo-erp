package SL::Controller::Bin;

use strict;

use parent qw(SL::Controller::Base);

use SL::Controller::Helper::GetModels;
use SL::DB::Bin;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(bin) ],
 'scalar --get_set_init' => [ qw(bins models) ],
);

sub action_ajax_autocomplete {
  my ($self, %params) = @_;
  $::form->{filter}{'all:substr:multi::ilike'} =~ s{[\(\)]+}{}g;

  # if someone types something, and hits enter, assume he entered the full name.
  # if something matches, treat that as sole match
  # unfortunately get_models can't do more than one per package atm, so we d it
  # the oldfashioned way.
  if ($::form->{prefer_exact}) {
    my $exact_matches;
    if (1 == scalar @{ $exact_matches = SL::DB::Manager::Bin->get_all(
      query => [
        description   => { ilike => $::form->{filter}{'all:substr:multi::ilike'} },
        warehouse_id  => $::form->{filter}{'warehouse_id'},
      ],
      limit => 2,
    ) }) {
      $self->bins($exact_matches);
    }
  }

  $::form->{sort_by} = 'description';

  my @hashes = map {
   +{
     value         => $_->full_description,
     label         => $_->full_description,
     id            => $_->id,
     description   => $_->description,
    }
  } @{ $self->bins }; # neato: if exact match triggers we don't even need the init_bin

  $self->render(\ SL::JSON::to_json(\@hashes), { layout => 0, type => 'json', process => 0 });
}

sub init_bins {
  if ($::form->{no_paginate}) {
    $_[0]->models->disable_plugin('paginated');
  }

  $_[0]->models->get;
}

sub init_models {
  my ($self) = @_;

  SL::Controller::Helper::GetModels->new(
    controller => $self,
    sorted => {
      _default => {
        by    => 'description',
        dir   => 1,
      },
      description    => t8('Description'),
    },
    query => [ warehouse_id  => $::form->{filter}{'warehouse_id'}, ],
  );
}
1;

__END__
