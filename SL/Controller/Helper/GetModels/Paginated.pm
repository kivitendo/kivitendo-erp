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
    get_models => sub { shift; $self->_get_models_handler_for_paginated(@_) },
  );

  # $::lxdebug->dump(0, "CONSPEC", \%specs);
}

sub read_params {
  my ($self, %params)      = @_;

  return %{ $self->form_data } if $self->form_data;
  my $source = $self->get_models->source;

  my $from_form = {
    page            => $source->{ $self->form_params->[0] } || 1,
    per_page        => $source->{ $self->form_params->[1] } * 1,
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
#  return () unless $self->is_enabled;
  my %paginate_params = $self->read_params;

  # try to use Filtered if available and nothing else is configured, but don't
  # blow up if the controller does not use Filtered
  my %paginate_args     = ref($self->paginate_args) eq 'CODE'       ? %{ $self->paginate_args->($self) }
                        :     $self->paginate_args  eq '__FILTER__'
                           && $self->get_models->filtered ? $self->get_models->filtered->read_params
                        :     $self->paginate_args  ne '__FILTER__' ? do { my $sub = $self->paginate_args; %{ $self->get_models->controller->$sub() } }
                        :                                               ();

  %args = $self->merge_args(\%args, \%paginate_args);

  my $calculated_params = $self->get_models->manager->paginate(%paginate_params, args => \%args);

  $self->paginated_args(\%args);
  $self->calculated_params($calculated_params);

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

  use SL::Controller::Helper::GetModels;
  use SL::Controller::Helper::Paginated;

  __PACKAGE__->make_paginated(
    MODEL       => 'BackgroundJobHistory',
    ONLY        => [ qw(list) ],
    FORM_PARAMS => [ qw(page per_page) ],
  );

  sub action_list {
    my ($self) = @_;

    my $paginated_models = $self->get_models;
    $self->render('controller/list', ENTRIES => $paginated_models);
  }

In said template:

  [% USE L %]

  <table>
   <thead>
    <tr>
     ...
    </tr>
   </thead>

   <tbody>
    [% FOREACH entry = ENTRIES %]
     <tr>
      ...
     </tr>
    [% END %]
   </tbody>
  </table>

  [% L.paginate_controls %]

=head1 OVERVIEW

This specialized helper module enables controllers to display a
paginatable list of database models with as few lines as possible. It
can also be combined trivially with the L<SL::Controller::Sorted>
helper for sortable lists.

For this to work the controller has to provide the information which
indexes are eligible for paginateing etc. by a call to
L<make_paginated> at compile time.

The underlying functionality that enables the use of more than just
the paginate helper is provided by the controller helper
C<GetModels>. See the documentation for L<SL::Controller::Sorted> for
more information on it.

A template can use the method C<paginate_controls> from the layout
helper module C<L> which renders the links for navigation between the
pages.

This module requires that the Rose model managers use their C<Paginated>
helper.

The C<Paginated> helper hooks into the controller call to the action via
a C<run_before> hook. This is done so that it can remember the paginate
parameters that were used in the current view.

=head1 PACKAGE FUNCTIONS

=over 4

=item C<make_paginated %paginate_spec>

This function must be called by a controller at compile time. It is
uesd to set the various parameters required for this helper to do its
magic.

The hash C<%paginate_spec> can include the following parameters:

=over 4

=item * C<MODEL>

Optional. A string: the name of the Rose database model that is used
as a default in certain cases. If this parameter is missing then it is
derived from the controller's package (e.g. for the controller
C<SL::Controller::BackgroundJobHistory> the C<MODEL> would default to
C<BackgroundJobHistory>).

=item * C<PAGINATE_ARGS>

Optional. Either a code reference or the name of function to be called
on the controller importing this helper.

If this funciton is given then the paginate helper calls it whenever
it has to count the total number of models for calculating the number
of pages to display. The function must return a hash reference with
elements suitable for passing to a Rose model manager's C<get_all>
function.

This can be used e.g. when filtering is used.

=item * C<PER_PAGE>

Optional. An integer: the number of models to return per page.

Defaults to the underlying database model's default number of models
per page.

=item * C<FORM_PARAMS>

Optional. An array reference with exactly two strings that name the
indexes in C<$::form> in which the current page's number (the first
element in the array) and the number of models per page (the second
element in the array) are stored.

Defaults to the values C<page> and C<per_page> if missing.

=item * C<ONLY>

Optional. An array reference containing a list of action names for
which the paginate parameters should be saved. If missing or empty then
all actions invoked on the controller are monitored.

=back

=back

=head1 INSTANCE FUNCTIONS

These functions are called on a controller instance.

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

Returns a hash reference to the paginate spec structure given in the call
to L<make_paginated> after normalization (hash reference construction,
applying default parameters etc).

=item C<disable_pagination>

Disable pagination for the duration of the current action. Can be used
when using the attribute C<ONLY> to L<make_paginated> does not
cover all cases.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
