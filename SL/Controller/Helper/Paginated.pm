package SL::Controller::Helper::Paginated;

use strict;

use Exporter qw(import);
our @EXPORT = qw(make_paginated get_paginate_spec get_current_paginate_params _save_current_paginate_params _get_models_handler_for_paginated _callback_handler_for_paginated);

my ($controller_paginate_spec, $current_page, $current_per_page);

sub make_paginated {
  my ($class, %specs)       = @_;

  $specs{MODEL}           ||=  $class->_controller_name;
  $specs{MODEL}             =~ s{ ^ SL::DB:: (?: .* :: )? }{}x;
  $specs{PER_PAGE}        ||= "SL::DB::Manager::$specs{MODEL}"->default_objects_per_page;
  $specs{FORM_PARAMS}     ||= [ qw(page per_page) ];
  $specs{ONLY}            ||= [];
  $specs{ONLY}              = [ $specs{ONLY} ] if !ref $specs{ONLY};

  $controller_paginate_spec = \%specs;

  my %hook_params           = @{ $specs{ONLY} } ? ( only => $specs{ONLY} ) : ();
  $class->run_before('_save_current_paginate_params', %hook_params);

  SL::Controller::Helper::GetModels::register_get_models_handlers(
    $class,
    callback   => '_callback_handler_for_paginated',
    get_models => '_get_models_handler_for_paginated',
    ONLY       => $specs{ONLY},
  );

  # $::lxdebug->dump(0, "CONSPEC", \%specs);
}

sub get_paginate_spec {
  my ($class_or_self) = @_;

  return $controller_paginate_spec;
}

sub get_current_paginate_params {
  my ($self, %params)   = @_;

  my $spec              = $self->get_paginate_spec;

  $params{page}         = $current_page     unless defined $params{page};
  $params{per_page}     = $current_per_page unless defined $params{per_page};

  my %paginate_params   =  (
    page                => ($params{page}     * 1) || 1,
    per_page            => ($params{per_page} * 1) || $spec->{PER_PAGE},
  );

  my $calculated_params = "SL::DB::Manager::$spec->{MODEL}"->paginate(%paginate_params, args => {});
  %paginate_params      = (
    %paginate_params,
    num_pages    => $calculated_params->{max},
    common_pages => $calculated_params->{common},
  );

  # $::lxdebug->dump(0, "get_current_paginate_params: ", \%paginate_params);

  return %paginate_params;
}

#
# private functions
#

sub _save_current_paginate_params {
  my ($self)        = @_;

  my $paginate_spec = $self->get_paginate_spec;
  $current_page     = $::form->{ $paginate_spec->{FORM_PARAMS}->[0] } || 1;
  $current_per_page = $::form->{ $paginate_spec->{FORM_PARAMS}->[1] } * 1;

  # $::lxdebug->message(0, "saving current paginate params to $current_page / $current_per_page");
}

sub _callback_handler_for_paginated {
  my ($self, %params) = @_;

  if ($current_page) {
    my $paginate_spec                             = $self->get_paginate_spec;
    $params{ $paginate_spec->{FORM_PARAMS}->[0] } = $current_page;
    $params{ $paginate_spec->{FORM_PARAMS}->[1] } = $current_per_page if $current_per_page;
  }

  # $::lxdebug->dump(0, "CB handler for paginated; params nach modif:", \%params);

  return %params;
}

sub _get_models_handler_for_paginated {
  my ($self, %params)    = @_;
  $params{model}       ||= $self->get_paginate_spec->{MODEL};

  "SL::DB::Manager::$params{model}"->paginate($self->get_current_paginate_params, args => \%params);

  # $::lxdebug->dump(0, "GM handler for paginated; params nach modif:", \%params);

  return %params;
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

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
