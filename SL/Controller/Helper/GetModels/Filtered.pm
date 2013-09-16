package SL::Controller::Helper::GetModels::Filtered;

use strict;
use parent 'SL::Controller::Helper::GetModels::Base';

use Exporter qw(import);
use SL::Controller::Helper::ParseFilter ();
use List::MoreUtils qw(uniq);

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(disabled filter_args filter_params) ],
  'scalar --get_set_init' => [ qw(form_params launder_to) ],
);

sub init {
  my ($self, %specs)             = @_;

  $self->set_get_models(delete $specs{get_models});
  $self->SUPER::init(%specs);

  $self->get_models->register_handlers(
    callback   => sub { shift; $self->_callback_handler_for_filtered(@_) },
    get_models => sub { shift; $self->_get_models_handler_for_filtered(@_) },
  );

  # $::lxdebug->dump(0, "CONSPEC", \%specs);
}

sub get_current_filter_params {
  my ($self)   = @_;

  return $self->filter_params if $self->filter_params;

  require Carp;
  Carp::confess('It seems a GetModels plugin tries to access filter params before they got calculated. Make sure your make_filtered call comes first.');
}

sub _make_current_filter_params {
  my ($self, %params)   = @_;

#  my $spec              = $self->get_filter_spec;
  my $filter            = $params{filter} // $::form->{ $self->form_params } // {},
  my %filter_args       = $self->_get_filter_args;
  my %parse_filter_args = (
    class        => $self->get_models->manager,
    with_objects => $params{with_objects},
  );
  my $laundered;
  if ($self->launder_to eq '__INPLACE__') {
    # nothing to do
  } elsif ($self->launder_to) {
    $laundered = {};
    $parse_filter_args{launder_to} = $laundered;
  } else {
    $parse_filter_args{no_launder} = 1;
  }

  my %calculated_params = SL::Controller::Helper::ParseFilter::parse_filter($filter, %parse_filter_args);
  %calculated_params = $self->merge_args(\%calculated_params, \%filter_args, \%params);

#  $calculated_params{query} = [
#    @{ $calculated_params{query} || [] },
#    @{ $filter_args{      query} || [] },
#    @{ $params{           query} || [] },
#  ];
#
#  $calculated_params{with_objects} = [
#    uniq
#    @{ $calculated_params{with_objects} || [] },
#    @{ $filter_args{      with_objects} || [] },
#    @{ $params{           with_objects} || [] },
#  ];

  if ($laundered) {
    if ($self->get_models->controller->can($self->launder_to)) {
      $self->get_models->controller->${\ $self->launder_to }($laundered);
    } else {
      $self->get_models->controller->{$self->launder_to} = $laundered;
    }
  }

  # $::lxdebug->dump(0, "get_current_filter_params: ", \%calculated_params);

  $self->filter_params(\%calculated_params);

  return %calculated_params;
}

sub disable_filtering {
  my ($self)               = @_;
  $self->disabled(1);
}

#
# private functions
#

sub _get_filter_args {
  my ($self, $spec) = @_;

  my %filter_args   = ref($self->filter_args) eq 'CODE' ? %{ $self->filter_args->($self) }
                    :     $self->filter_args            ? do { my $sub = $self->filter_args; %{ $self->get_models->controller->$sub() } }
                    :                                       ();
}

sub _callback_handler_for_filtered {
  my ($self, %params) = @_;

  if ($self->is_enabled) {
    my ($flattened) = SL::Controller::Helper::ParseFilter::flatten($::form->{ $self->form_params }, $self->form_params);
    %params         = (%params, @{ $flattened || [] });
  }

  # $::lxdebug->dump(0, "CB handler for filtered; params after flatten:", \%params);

  return %params;
}

sub _get_models_handler_for_filtered {
  my ($self, %params)    = @_;

  # $::lxdebug->dump(0,  "params in get_models_for_filtered", \%params);

  my %filter_params;
  %filter_params = $self->_make_current_filter_params(%params)  if $self->is_enabled;

  # $::lxdebug->dump(0, "GM handler for filtered; params nach modif (is_enabled? " . $self->is_enabled . ")", \%params);

  return (%params, %filter_params);
}

sub is_enabled {
  !$_[0]->disabled;
}

sub init_form_params {
  'filter'
}

sub init_launder_to {
  'filter'
}


1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::Helper::Filtered - A helper for semi-automatic handling
of filtered lists of database models in a controller

=head1 SYNOPSIS

In a controller:

  use SL::Controller::Helper::GetModels;
  use SL::Controller::Helper::Filtered;

  __PACKAGE__->make_filter(
    MODEL       => 'Part',
    ONLY        => [ qw(list) ],
    FORM_PARAMS => [ qw(filter) ],
  );

  sub action_list {
    my ($self) = @_;

    my $filtered_models = $self->get_models(%addition_filters);
    $self->render('controller/list', ENTRIES => $filtered_models);
  }


=head1 OVERVIEW

This helper module enables use of the L<SL::Controller::Helper::ParseFilter>
methods in conjunction with the L<SL::Controller::Helper::GetModels> style of
plugins. Additional filters can be defined in the database models and filtering
can be reduced to a minimum of work.

This plugin can be combined with L<SL::Controller::Sorted> and
L<SL::Controller::Paginated> for filtered, sorted and paginated lists.

The controller has to provive information where to look for filter information
at compile time. This call is L<make_filtered>.

The underlying functionality that enables the use of more than just
the paginate helper is provided by the controller helper
C<GetModels>. See the documentation for L<SL::Controller::Sorted> for
more information on it.

=head1 PACKAGE FUNCTIONS

=over 4

=item C<make_filtered %filter_spec>

This function must be called by a controller at compile time. It is
uesd to set the various parameters required for this helper to do its
magic.

Careful: If you want to use this in conjunction with
L<SL:Controller::Helper::Paginated>, you need to call C<make_filtered> first,
or the paginating will not get all the relevant information to estimate the
number of pages correctly. To ensure this does not happen, this module will
croak when it detects such a scenario.

The hash C<%filter_spec> can include the following parameters:

=over 4

=item * C<MODEL>

Optional. A string: the name of the Rose database model that is used
as a default in certain cases. If this parameter is missing then it is
derived from the controller's package (e.g. for the controller
C<SL::Controller::BackgroundJobHistory> the C<MODEL> would default to
C<BackgroundJobHistory>).

=item * C<FORM_PARAMS>

Optional. Indicates a key in C<$::form> to be used as filter.

Defaults to the values C<filter> if missing.

=item * C<LAUNDER_TO>

Option. Indicates a target for laundered filter arguments in the controller.
Can be set to C<undef> to disable laundering, and can be set to method named or
hash keys of the controller. In the latter case the laundered structure will be
put there.

Defaults to inplace laundering which is not normally settable.

=item * C<ONLY>

Optional. An array reference containing a list of action names for
which the paginate parameters should be saved. If missing or empty then
all actions invoked on the controller are monitored.

=back

=back

=head1 INSTANCE FUNCTIONS

These functions are called on a controller instance.

=over 4

=item C<get_current_filter_params>

Returns a hash to be used in manager C<get_all> calls or to be passed on to
GetModels. Will only work if the get_models chain has been called at least
once, because only then the full parameters can get parsed and stored. Will
croak otherwise.

=item C<disable_filtering>

Disable filtering for the duration of the current action. Can be used
when using the attribute C<ONLY> to L<make_filtered> does not
cover all cases.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
