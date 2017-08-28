package SL::Controller::TopQuickSearch::Article;

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

sub name { 'article' }

sub description_config { t8('Articles') }

sub description_field { t8('Articles') }

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
  my ($self) = @_;
  $self->redirect_to_part($::form->{id});
}

sub do_search {
  my ($self) = @_;

  my $objects = $self->models->get;

  return !@$objects     ? ()
       : @$objects == 1 ? $self->redirect_to_part($objects->[0]->id)
       :                  $self->redirect_to_search($::form->{term});
}

sub redirect_to_search {
  my ($self, $term) = @_;

  SL::Controller::Base->new->url_for(
    controller   => 'ic.pl',
    action       => 'generate_report',
    all          => $term,
    (searchitems => $self->part_type) x!!$self->part_type,
  );
}

sub redirect_to_part {
  my ($self, $term) = @_;

  SL::Controller::Base->new->url_for(
    controller => 'controller.pl',
    action     => 'Part/edit',
    'part.id'  => $term,
  );
}

sub part_type {
  ()
}

sub init_models {
  my ($self) = @_;

  SL::Controller::Helper::GetModels->new(
    controller => $self,
    model      => 'Part',
    source     => {
      filter => {
        (part_type => $self->part_type) x!!$self->part_type,
        or => [ obsolete => undef, obsolete => 0 ],
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
