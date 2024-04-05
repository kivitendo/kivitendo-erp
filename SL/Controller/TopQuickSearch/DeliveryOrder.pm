package SL::Controller::TopQuickSearch::DeliveryOrder;

use strict;
use parent qw(Rose::Object);

use SL::Locale::String qw(t8);
use SL::DB::DeliveryOrder;
use SL::Controller::Helper::GetModels;
use SL::Controller::Base;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(models) ],
);

# nope. this is only for subclassing
sub auth { 'NOT ALLOWED' }

sub name { die 'must be overwritten' }

sub description_config { die 'must be overwritten' }

sub description_field { die 'must be overwritten' }

sub type { die 'must be overwritten' }

sub cv { die 'must be overwritten' }

sub query_autocomplete {
  my ($self) = @_;

  my $objects = $self->models->get;

  [
    map {
     value       => $_->digest,
     label       => $_->digest,
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
  SL::Controller::Base->new->url_for(
    controller   => 'do.pl',
    action       => 'orders',
    type         => $_[0]->type,
    vc           => $_[0]->vc,
    all          => $_[1],
    open         => 1,
    closed       => 1,
    delivered    => 1,
    notdelivered => 1,
    sortdir      => 0,
    (map {; "l_$_" => 'Y' } qw(donumber transdate cusordnumber reqdate name employee transaction_description)),
  );
}

sub redirect_to_object {
  SL::Controller::Base->new->url_for(
    controller => 'controller.pl',
    action     => 'DeliveryOrder/edit',
    id         => $_[1],
    type       => $_[0]->type,
  );
}

sub init_models {
  my ($self) = @_;

  SL::Controller::Helper::GetModels->new(
    controller => $self,
    model      => 'DeliveryOrder',
    source     => {
      filter => {
        type => $self->type,
        'all:substr:multi::ilike' => $::form->{term},
      },
    },
    sorted     => {
      _default   => {
        by  => 'transdate',
        dir => 0,
      },
      transdate => t8('Date'),
    },
    paginated  => {
      per_page => 10,
    },
    with_objects => [ qw(customer vendor orderitems) ]
  )
}

1;
