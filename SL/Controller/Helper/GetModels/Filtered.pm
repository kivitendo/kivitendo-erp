package SL::Controller::Helper::GetModels::Filtered;

use strict;
use parent 'SL::Controller::Helper::GetModels::Base';

use Exporter qw(import);
use SL::Controller::Helper::ParseFilter ();
use List::MoreUtils qw(uniq);

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(filter_args filter_params orig_filter filter no_launder) ],
  'scalar --get_set_init' => [ qw(form_params laundered) ],
);

sub init {
  my ($self, %specs)             = @_;

  $self->set_get_models(delete $specs{get_models});
  $self->SUPER::init(%specs);

  $self->get_models->register_handlers(
    callback   => sub { shift; $self->_callback_handler_for_filtered(@_) },
  );

  # $::lxdebug->dump(0, "CONSPEC", \%specs);
}

sub read_params {
  my ($self, %params)   = @_;

  return %{ $self->filter_params } if $self->filter_params;
  my $source = $self->get_models->source;

  my $filter            = $self->filter // $source->{ $self->form_params } // {};
  $self->orig_filter($filter);

  my %filter_args       = $self->_get_filter_args;
  my %parse_filter_args = (
    class        => $self->get_models->manager,
    with_objects => $params{with_objects},
  );

  # Store laundered result in $self->laundered.

  if (!$self->no_launder) {
    $self->laundered({});
    $parse_filter_args{launder_to} = $self->laundered;
  } else {
    $self->laundered(undef);
    $parse_filter_args{no_launder} = 1;
  }

  my %calculated_params = SL::Controller::Helper::ParseFilter::parse_filter($filter, %parse_filter_args);
  %calculated_params = $self->merge_args(\%calculated_params, \%filter_args, \%params);

  # $::lxdebug->dump(0, "get_current_filter_params: ", \%calculated_params);

  $self->filter_params(\%calculated_params);

  return %calculated_params;
}

sub finalize {
  my ($self, %params) = @_;

  my %filter_params;
  %filter_params = $self->read_params(%params)  if $self->is_enabled;

  # $::lxdebug->dump(0, "GM handler for filtered; params nach modif (is_enabled? " . $self->is_enabled . ")", \%params);

  return $self->merge_args(\%params, \%filter_params);
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
    my ($flattened) = SL::Controller::Helper::ParseFilter::flatten($self->orig_filter, $self->form_params);
    %params         = (%params, @{ $flattened || [] });
  }

  # $::lxdebug->dump(0, "CB handler for filtered; params after flatten:", \%params);

  return %params;
}

sub init_form_params {
  'filter'
}

sub init_laundered {
  my ($self) = @_;

  $self->get_models->finalize;
  return $self->{laundered};
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::Helper::GetModels::Filtered - Filter handling plugin for GetModels

=head1 SYNOPSIS

In a controller:

  SL::Controller::Helper::GetModels->new(
    ...
    filtered => {
      filter      => HASHREF,
      no_launder  => 0 | 1,
    }

    OR

    filtered => 0,
  );

=head1 OVERVIEW

This C<GetModels> plugin enables use of the
L<SL::Controller::Helper::ParseFilter> methods. Additional filters can be
defined in the database models and filtering can be reduced to a minimum of
work.

The underlying functionality that enables the use of more than just
the paginate helper is provided by the controller helper
C<GetModels>. See the documentation for L<SL::Controller::Helper::GetModels> for
more information on it.

=head1 OPTIONS

=over 4

=item * C<filter>

Optional. Indicates a key in C<source> to be used as filter.

Defaults to the value C<filter> if missing.

=item * C<no_launder>

Optional. If given and trueish then laundering is disabled.

=back

=head1 FILTER FORMAT

See L<SL::Controller::Helper::ParseFilter> for a description of the filter format.

=head1 CUSTOM FILTERS

C<Filtered> will honor custom filters defined in RDBO managers. See
L<SL::DB::Helper::Filtered> for an explanation of those.

=head1 FUNCTIONS

=over 4

=item C<laundered>

Finalizes the object (which causes laundering of the filter structure)
and returns a hashref of the laundered filter. If the plugin is
configured not to launder then C<undef> will be returned.

=back

=head1 BUGS

=over 4

=item * There is currently no easy way to filter for CVars.

=back

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
