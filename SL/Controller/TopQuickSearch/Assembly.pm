package SL::Controller::TopQuickSearch::Assembly;

use strict;
use parent qw(Rose::Object);

use SL::Locale::String qw(t8);
use SL::DB::Part;
use SL::Controller::Helper::GetModels;
use SL::Controller::Base;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(parts models part) ],
);

sub auth { 'part_service_assembly_edit' }

sub name { 'assembly' }

sub description_config { t8('Assemblies') }

sub description_field { t8('Assemblies') }

sub query_autocomplete {
  my ($self) = @_;

  my $objects = $self->models->get;

  [
    map {
     value       => $_->displayable_name,
     label       => $_->displayable_name,
     id          => $_->id,
    }, @$objects
  ];
}

sub select_autocomplete {
  redirect_to_part($::form->{id});
}

sub do_search {
  my ($self) = @_;

  my $objects = $self->models->get;

  return !@$objects     ? ()
       : @$objects == 1 ? redirect_to_part($objects->[0]->id)
       :                  redirect_to_search($::form->{term});
}

sub redirect_to_search {
  SL::Controller::Base->new->url_for(
    controller  => 'ic.pl',
    action      => 'generate_report',
    searchitems => 'assembly',
    all         => $_[0],
  );
}

sub redirect_to_part {
  SL::Controller::Base->new->url_for(
    controller => 'ic.pl',
    action     => 'edit',
    id         => $_[0],
  );
}

sub init_models {
  my ($self) = @_;

  SL::Controller::Helper::GetModels->new(
    controller => $self,
    model      => 'Part',
    source     => {
      filter => {
        type                      => 'assembly',
        'all:substr:multi::ilike' => $::form->{term},
      },
    },
    sorted     => {
      _default   => {
        by  => 'partnumber',
        dir => 1,
      },
      partnumber => t8('Partnumber'),
    },
    paginated  => {
      per_page => 10,
    },
  )
}

1;
