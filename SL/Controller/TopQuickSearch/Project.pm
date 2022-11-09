package SL::Controller::TopQuickSearch::Project;

use strict;
use parent qw(Rose::Object);

use SL::Locale::String qw(t8);
use SL::DB::Project;
use SL::Controller::Helper::GetModels;
use SL::Controller::Base;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(models) ],
);

sub auth { 'project_edit' }

sub name { 'project' }

sub description_config { t8('Projects') }

sub description_field { t8('Projects') }

sub query_autocomplete {
  my ($self) = @_;

  my $objects = $self->models->get;

  [
    map {
     value       => $_->full_description,
     label       => $_->full_description,
     id          => $_->id,
    }, @$objects
  ];
}

sub select_autocomplete {
  $_[0]->redirect_to_object($::form->{id});
}

sub do_search {
  my ($self) = @_;

  my $objects = $self->models->get;

  return !@$objects     ? ()
       : @$objects == 1 ? $self->redirect_to_object($objects->[0]->id)
       :                  $self->redirect_to_search($::form->{term});
}

sub redirect_to_search {
  my ($self, $term) = @_;

  SL::Controller::Base->new->url_for(
    controller => 'controller.pl',
    action     => 'Project/list',
    all        => $term,
  );

}

sub redirect_to_object {
  my ($self, $term) = @_;
  SL::Controller::Base->new->url_for(
    controller => 'controller.pl',
    action     => 'Project/edit',
    id         => $term,
  );
}

sub init_models {
  my ($self) = @_;

  SL::Controller::Helper::GetModels->new(
    controller => $self,
    model      => 'Project',
    source     => {
      filter => {
        'all:substr:multi::ilike' => $::form->{term},
      },
    },
    sorted     => {
      _default   => {
        by  => 'itime',
        dir => 0,
      },
      itime => t8('Date'),
    },
    paginated  => {
      per_page => 10,
    },
    with_objects => [ qw(customer) ]
  )
}

1;
