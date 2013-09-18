package SL::Controller::Helper::GetModels;

use strict;

use parent 'Rose::Object';
use SL::Controller::Helper::GetModels::Filtered;
use SL::Controller::Helper::GetModels::Sorted;
use SL::Controller::Helper::GetModels::Paginated;

use Scalar::Util qw(weaken);

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(controller model query with_objects filtered sorted paginated finalized final_params) ],
  'scalar --get_set_init' => [ qw(handlers source) ],
  array => [ qw(plugins) ],
);

use constant PRIV => '__getmodelshelperpriv';


# official interface

sub get {
  my ($self) = @_;
  my %params = $self->finalize;

  return $self->manager->get_all(%params);
}

sub disable_plugin {
  my ($self, $plugin) = @_;
  die 'cannot change internal state after finalize was called' if $self->finalized;
  die 'unsupported plugin' unless $self->can($plugin) && $self->$plugin && $self->$plugin->isa('SL::Controller::Helper::GetModels::Base');

  $self->$plugin->disabled(1);
}

sub enable_plugin {
  my ($self, $plugin) = @_;
  die 'cannot change internal state after finalize was called' if $self->finalized;
  die 'unsupported plugin' unless $self->can($plugin) && $self->$plugin && $self->$plugin->isa('SL::Controller::Helper::GetModels::Base');
  $self->$plugin->disabled(0);
}

sub is_enabled_plugin {
  my ($self, $plugin) = @_;
  die 'unsupported plugin' unless $self->can($plugin) && $self->$plugin && $self->$plugin->isa('SL::Controller::Helper::GetModels::Base');
  $self->$plugin->is_enabled;
}

# TODO: get better delegation
sub set_report_generator_sort_options {
  my ($self, %params) = @_;
  $self->finalize;

  $self->sorted->set_report_generator_sort_options(%params);
}

sub get_paginate_args {
  my ($self) = @_;
  my %params = $self->finalize;

  $self->paginated->get_current_paginate_params(%params);
}

sub init {
  my ($self, %params) = @_;

  # TODO: default model
  $self->model(delete $params{model});

  my @plugins;
  for my $plugin (qw(filtered sorted paginated)) {
    next unless my $spec = delete $params{$plugin} // {};
    my $plugin_class = "SL::Controller::Helper::GetModels::" . ucfirst $plugin;
    push @plugins, $self->$plugin($plugin_class->new(%$spec, get_models => $self));
  }
  $self->plugins(@plugins);

  $self->SUPER::init(%params);

  $_->read_params for $self->plugins;

  weaken $self->controller if $self->controller;
}

sub finalize {
  my ($self, %params) = @_;

  return %{ $self->final_params } if $self->finalized;

  push @{ $params{query}        ||= [] }, @{ $self->query || [] };
  push @{ $params{with_objects} ||= [] }, @{ $self->with_objects || [] };

  %params = $_->finalize(%params) for $self->plugins;

  $self->finalized(1);
  $self->final_params(\%params);

  return %params;
}

sub register_handlers {
  my ($self, %additional_handlers) = @_;

  my $handlers    = $self->handlers;
  map { push @{ $handlers->{$_} }, $additional_handlers{$_} if $additional_handlers{$_} } keys %$handlers;
}

# TODO fix this
sub get_models_url_params {
  my ($class, $sub_name_or_code) = @_;

  my $code     = (ref($sub_name_or_code) || '') eq 'CODE' ? $sub_name_or_code : sub { shift->$sub_name_or_code(@_) };
  my $callback = sub {
    my ($self, %params)   = @_;
    my @additional_params = $code->($self);
    return (
      %params,
      (scalar(@additional_params) == 1) && (ref($additional_params[0]) eq 'HASH') ? %{ $additional_params[0] } : @additional_params,
    );
  };

  push @{ _registered_handlers($class)->{callback} }, $callback;
}

sub get_callback {
  my ($self, %override_params) = @_;

  my %default_params = $self->_run_handlers('callback', action => $self->controller->action_name);

  return $self->controller->url_for(%default_params, %override_params);
}

sub manager {
  die "No 'model' to work on" unless $_[0]->model;
  "SL::DB::Manager::" . $_[0]->model;
}

#
# private/internal functions
#

sub _run_handlers {
  my ($self, $handler_type, %params) = @_;

  foreach my $sub (@{ $self->handlers->{$handler_type} }) {
    if (ref $sub eq 'CODE') {
      %params = $sub->($self, %params);
    } elsif ($self->can($sub)) {
      %params = $self->$sub(%params);
    } else {
      die "SL::Controller::Helper::GetModels::get_callback: Cannot call $sub on " . ref($self) . ")";
    }
  }

  return %params;
}

sub init_handlers {
  {
    callback => [],
  }
}

sub init_source {
  $::form
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::Helper::GetModels - Base mixin for controller helpers
dealing with semi-automatic handling of sorting and paginating lists

=head1 SYNOPSIS

For a proper synopsis see L<SL::Controller::Helper::Sorted>.

=head1 OVERVIEW

For a generic overview see L<SL::Controller::Helper::Sorted>.

This base module is the interface between a controller and specialized
helper modules that handle things like sorting and paginating. The
specialized helpers register themselves with this module via a call to
L<register_get_models_handlers> during compilation time (e.g. in the
case of C<Sorted> this happens when the controller calls
L<SL::Controller::Helper::Sorted::make_sorted>).

A controller will later usually call the L<get_models>
function. Templates will call the L<get_callback> function. Both
functions run the registered handlers handing over control to the
specialized helpers so that they may inject their parameters into the
call chain.

The C<GetModels> helper hooks into the controller call to the action
via a C<run_before> hook. This is done so that it can remember the
action called by the user. This is used for constructing the callback
in L<get_callback>.

=head1 PACKAGE FUNCTIONS

=over 4

=item C<get_models_url_params $class, $sub>

Register one of the controller's subs to be called whenever an URL has
to be generated (e.g. for sort and pagination links). This is a way
for the controller to add additional parameters to the URL (e.g. for
filter parameters).

The C<$sub> parameter can be either a code reference or the name of
one of the controller's functions.

The value returned by this C<$sub> must be either a single hash
reference or a hash of key/value pairs to add to the URL.

=item C<register_get_models_handlers $class, %handlers>

This function should only be called from other controller helpers like
C<Sorted> or C<Paginated>. It is not exported and must therefore be
called its full name. The first parameter C<$class> must be the actual
controller's class name.

If C<%handlers> contains a key C<ONLY> then it is passed to the hook
registration in L<SL::Controller::Base::run_before>.

The C<%handlers> register callback functions in the specialized
controller helpers that are called during invocation of
L<get_callback> or L<get_models>. Possible keys are C<callback> and
C<models>.

Each handler (the value in the hash) can be either a code reference
(in which case it is called directly) or the name of an instance
function callable on a controller instance. In both cases the handler
receives a hash of parameters built during this very call to
L<get_callback> or L<get_models> respectively. The handler's return
value must be the new hash to be used in calls to further handlers and
to the actual database model functions later on.

=back

=head1 INSTANCE FUNCTIONS

=over 4

=item C<get_callback [%params]>

Return an URL suitable for use as a callback parameter. It maps to the
current controller and action. All registered handlers of type
'callback' (e.g. the ones by C<Sorted> and C<Paginated>) can inject
the parameters they need so that the same list view as is currently
visible can be re-rendered.

Optional C<%params> passed to this function may override any parameter
set by the registered handlers.

=item C<get_models [%params]>

Query the model manager via C<get_all> and return its result. The
parameters to C<get_all> are constructed by calling all registered
handlers of type 'models' (e.g. the ones by C<Sorted> and
C<Paginated>).

Optional C<%params> passed to this function may override any parameter
set by the registered handlers.

The return value is the an array reference of C<Rose> models.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
