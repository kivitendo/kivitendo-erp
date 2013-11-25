package SL::Controller::Helper::GetModels::Filtered;

use strict;
use parent 'SL::Controller::Helper::GetModels::Base';

use Exporter qw(import);
use SL::Controller::Helper::ParseFilter ();
use List::MoreUtils qw(uniq);

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(filter_args filter_params orig_filter) ],
  'scalar --get_set_init' => [ qw(form_params launder_to) ],
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

  my $filter            = $params{filter} // $source->{ $self->form_params } // {};
  $self->orig_filter($filter);

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

sub init_launder_to {
  'filter'
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
      launder_to  => HASHREF | SUBNAME | '__INPLACE__',
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

=item * C<launder_to>

Optional. Indicates a target for laundered filter arguments in the controller.
Can be set to C<undef> to disable laundering, and can be set to method named or
hash keys of the controller. In the latter case the laundered structure will be
put there.

Defaults to the controller. Laundered values will end up in C<SELF.filter> for
template purposes.

Setting this to the special value C<__INPLACE__> will cause inplace laundering.

=back

=head1 FILTER FORMAT

See L<SL::Controller::Helper::ParseFilter> for a description of the filter format.

=head1 CUSTOM FILTERS

C<Filtered> will honor custom filters defined in RDBO managers. See
L<SL::DB::Helper::Filtered> for an explanation fo those.

=head1 BUGS

=over 4

=item * There is currently no easy way to filter for CVars.

=back

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
