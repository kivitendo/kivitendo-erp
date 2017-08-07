package SL::Controller::Helper::GetModels::Paginated;

use strict;
use parent 'SL::Controller::Helper::GetModels::Base';

use List::Util qw(min);

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(per_page form_data paginated_args calculated_params) ],
  'scalar --get_set_init' => [ qw(form_params paginate_args) ],
);

sub init {
  my ($self, %specs)               = @_;

  $self->set_get_models(delete $specs{get_models});
  $self->SUPER::init(%specs);

  $self->per_page($self->get_models->manager->default_objects_per_page) unless $self->per_page;

  $self->get_models->register_handlers(
    callback   => sub { shift; $self->_callback_handler_for_paginated(@_) },
  );

  # $::lxdebug->dump(0, "CONSPEC", \%specs);
}

sub read_params {
  my ($self, %params)      = @_;

  return %{ $self->form_data } if $self->form_data;
  my $source = $self->get_models->source;

  my $from_form = {
    page            =>  $source->{ $self->form_params->[0] } || 1,
    per_page        => ($source->{ $self->form_params->[1] } // 0) * 1,
  };

#  my $priv              = _priv($self);
  $params{page}         = $from_form->{page}     unless defined $params{page};
  $params{per_page}     = $from_form->{per_page} unless defined $params{per_page};

  $params{page}         = ($params{page} * 1) || 1;
  $params{per_page}     = ($params{per_page} * 1) || $self->per_page;

  $self->form_data(\%params);

  %params;
}

sub finalize {
  my ($self, %args)   = @_;

  if ($self->is_enabled) {
    my %paginate_params = $self->read_params;

    # try to use Filtered if available and nothing else is configured, but don't
    # blow up if the controller does not use Filtered
    my %paginate_args     = ref($self->paginate_args) eq 'CODE'       ? %{ $self->paginate_args->($self) }
                          :     $self->paginate_args  ne '__FILTER__' ? do { my $sub = $self->paginate_args; %{ $self->get_models->controller->$sub() } }
                          :                                               ();

    %args = $self->merge_args(\%args, \%paginate_args);

    my $calculated_params = $self->get_models->manager->paginate(%paginate_params, args => \%args);

    $self->calculated_params($calculated_params);
  }

  $self->paginated_args(\%args);

  return %args;
}

sub get_current_paginate_params {
  my ($self, %args)   = @_;
  return () unless $self->is_enabled;
  %{ $self->calculated_params };
}

#
# private functions
#

sub _callback_handler_for_paginated {
  my ($self, %params) = @_;
  my %form_params = $self->read_params;

  if ($self->is_enabled && $form_params{page}) {
    $params{ $self->form_params->[0] } = $form_params{page};
    $params{ $self->form_params->[1] } = $form_params{per_page} if $form_params{per_page};
  }

  # $::lxdebug->dump(0, "CB handler for paginated; params nach modif:", \%params);

  return %params;
}

sub init_form_params {
  [ qw(page per_page) ]
}

sub init_paginate_args {
  '__FILTER__'
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::Helper::Paginated - A helper for semi-automatic handling
of paginating lists of database models in a controller

=head1 SYNOPSIS

In a controller:

  SL::Controller::Helper::GetModels->new(
    ..
    paginated => {
      form_params => [ qw(page per_page) ],
      per_page    => 20,
    }
  );

In said template:

  [% L.paginate_controls %]

=head1 OVERVIEW

This C<GetModels> plugin enables controllers to display a
paginatable list of database models with as few lines as possible.

For this to work the controller has to provide the information which
indexes are eligible for paginateing etc. during C<GetModels> creation.

The underlying functionality that enables the use of more than just
the paginate helper is provided by the controller helper
C<GetModels>. See the documentation for L<SL::Controller::Helper::GetModels>
for more information on it.

A template can use the method C<paginate_controls> from the layout
helper module C<L> which renders the links for navigation between the
pages.

This module requires that the Rose model managers use their C<Paginated>
helper.

=head1 OPTIONS

=over 4

=item * C<per_page>

Optional. The number of models to return per page.

Defaults to the underlying database model's default number of models
per page.

=item * C<form_params>

Optional. An array reference with exactly two strings that name the
indexes in C<$::form> in which the current page's number (the first
element in the array) and the number of models per page (the second
element in the array) are stored.

Defaults to the values C<page> and C<per_page> if missing.

=back

=head1 INSTANCE FUNCTIONS

These functions are called on a C<GetModels> instance and delegated here.

=over 4

=item C<get_paginate_spec>

Returns a hash containing the currently active paginate
parameters. The following keys are returned:

=over 4

=item * C<page>

The currently active page number (numbering starts at 1).

=item * C<per_page>

Number of models per page (at least 1).

=item * C<num_pages>

Number of pages to display (at least 1).

=item * C<common_pages>

An array reference with one hash reference for each possible
page. Each hash ref contains the keys C<active> (C<1> if that page is
the currently active page), C<page> (the page number this hash
reference describes) and C<visible> (whether or not it should be
displayed).

=back

=item C<get_current_paginate_params>

Returns a hash reference to the paginate spec structure given in the
configuration after normalization (hash reference construction,
applying default parameters etc).

=back

=head1 BUGS

C<common_pages> generates an array with an entry for every page, which gets
slow if there are a lot of entries. Current observation holds that up to about
1000 pages there is no noticable slowdown, but at about 10000 it gets
noticable. At 100k-500k pages it's takes way too long and should be remodelled.

This case currently only applies for databases with very large amounts of parts
that get paginated, but BackgroundJobHistory can also accumulate.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
