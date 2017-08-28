package SL::Controller::TopQuickSearch::CustomerVendor;

use strict;
use parent qw(Rose::Object);

use SL::Locale::String qw(t8);
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
    controller => 'ct.pl',
    action     => 'list_names',
    db         => $_[0]->db,
    sortdir    => 0,
    status     => 'all',
    obsolete   => 'N',
    all        => $_[1],
    (map {; "l_$_" => 'Y' } $_[0]->db . "number", qw(name street contact phone zipcode email city country gln)),

  );
}

sub redirect_to_object {
  SL::Controller::Base->new->url_for(
    controller => 'CustomerVendor',
    action     => 'edit',
    db         => $_[0]->db,
    id         => $_[1],
  );
}

sub init_models {
  my ($self) = @_;

  my $cvnumber = $self->db eq 'customer' ? 'customernumber' : 'vendornumber';

  SL::Controller::Helper::GetModels->new(
    controller => $self,
    model      => $self->model,
    source     => {
      filter => {
        'all:substr:multi::ilike' => $::form->{term}, # all filter spec is set in SL::DB::Manager::Customer
        or => [ obsolete => undef, obsolete => 0 ],
      },
    },
    sorted     => {
      _default   => {
        by  => $cvnumber,
        dir => 0,
      },
      $cvnumber => $self->db eq 'customer' ? t8('Customer Number') : t8('Vendor Number'),
    },
    paginated  => {
      per_page => 10,
    },
  )
}

sub type {
  die 'must be overwritten'
}

sub cv {
  die 'must be overwritten'
}

sub model {
  die 'must be overwritten'
};

1;
