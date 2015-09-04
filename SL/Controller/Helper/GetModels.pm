package SL::Controller::Helper::GetModels;

use strict;

use parent 'Rose::Object';
use SL::Controller::Helper::GetModels::Filtered;
use SL::Controller::Helper::GetModels::Sorted;
use SL::Controller::Helper::GetModels::Paginated;

use Scalar::Util qw(weaken);

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(controller model query with_objects filtered sorted paginated finalized final_params) ],
  'scalar --get_set_init' => [ qw(handlers source list_action additional_url_params) ],
  array => [ qw(plugins) ],
);

use constant PRIV => '__getmodelshelperpriv';


# official interface

sub get {
  my ($self) = @_;
  my %params = $self->finalize;

  return $self->manager->get_all(%params);
}

sub count {
  my ($self) = @_;
  my %params = $self->finalize;

  return $self->manager->get_all_count(%params);
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

sub get_sort_spec {
  my ($self) = @_;

  $self->sorted->specs;
}

sub get_current_sort_params {
  my ($self) = @_;

  $self->sorted->read_params;
}

sub init {
  my ($self, %params) = @_;

  my $model = delete $params{model};
  if (!$model && $params{controller} && ref $params{controller}) {
    $model = ref $params{controller};
    $model =~ s/.*:://;
    die 'Need a valid model' unless $model;
  }
  $self->model($model);

  my @plugins;
  for my $plugin (qw(filtered sorted paginated)) {
    next if exists($params{$plugin}) && !$params{$plugin};

    my $spec         = delete $params{$plugin} // {};
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

  $self->register_handlers(callback => sub { shift; (@_, %{ $self->additional_url_params }) }) if %{ $self->additional_url_params };

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

sub add_additional_url_params {
  my ($self, %params) = @_;

  $self->additional_url_params({ %{ $self->additional_url_params }, %params });

  return $self;
}

sub get_models_url_params {
  my ($self, $sub_name_or_code) = @_;

  my $code     = (ref($sub_name_or_code) || '') eq 'CODE' ? $sub_name_or_code : sub { shift->controller->$sub_name_or_code(@_) };
  my $callback = sub {
    my ($self, %params)   = @_;
    my @additional_params = $code->($self);
    return (
      %params,
      (scalar(@additional_params) == 1) && (ref($additional_params[0]) eq 'HASH') ? %{ $additional_params[0] } : @additional_params,
    );
  };

  $self->register_handlers('callback' => $callback);
}

sub get_callback_params {
  my ($self, %override_params) = @_;

  my %default_params = $self->_run_handlers('callback', action => $self->list_action);
}

sub get_callback {
  my ($self, %override_params) = @_;

  my %default_params = $self->get_callback_params(%override_params);

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

sub init_list_action {
  $_[0]->controller->action_name
}

sub init_additional_url_params { +{} }

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::Helper::GetModels - Base class for the GetModels system.

=head1 SYNOPSIS

In controller:

  use SL::Controller::Helper::GetModels;

  my $get_models = SL::Controller::Helper::GetModels->new(
    controller   => $self,
  );

  my $models = $self->get_models->get;

=head1 OVERVIEW

Building a CRUD controller would be easy, were it not for those stupid
list actions. People unreasonably expect stuff like filtering, sorting,
paginating, exporting etc simply to work. Well, lets try to make it simply work
a little.

This class is a proxy between a controller and specialized
helper modules that handle these things (sorting, paginating etc) and gives you
the means to retrieve the information when needed to display sort headers or
paginating footers.

Information about the requested data query can be stored in the object up to
a certain point, from which on the object becomes locked and can only be
accessed for information. (See C<STATES>).

=head1 INTERFACE METHODS

=over 4

=item new PARAMS

Create a new GetModels object. Params must have at least an entry
C<controller>, other than that, see C<CONFIGURATION> for options.

=item get

Retrieve all models for the current configuration. Will finalize the object.

=item get_models_url_params SUB

Register a sub to be called whenever an URL has to be generated (e.g. for sort
and pagination links). This is a way for the controller to add additional
parameters to the URL (e.g. for filter parameters).

The parameter can be either a code reference or the name of
one of the controller's functions.

The value returned by C<SUB> must be either a single hash
reference or a hash of key/value pairs to add to the URL.

=item add_additional_url_params C<%params>

Sets additional parameters that will be added to each URL generated by
this model (e.g. for pagination/sorting). This is just sugar for a
proper call to L<get_models_url_params> with an anonymous sub adding
those parameters.

=item get_callback

Returns a URL suitable for use as a callback parameter. It maps to the
current controller and action. All registered handlers of type
'callback' (e.g. the ones by C<Sorted> and C<Paginated>) can inject
the parameters they need so that the same list view as is currently
visible can be re-rendered.

Optional C<%params> passed to this function may override any parameter
set by the registered handlers.

=item enable_plugin PLUGIN

=item disable_plugin PLUGIN

=item is_enabled_plugin PLUGIN

Enable or disable the specified plugin. Useful to disable paginating for
exports for example. C<is_enabled_plugin> can be used to check the current
state of a plugin.

Must not be finalized to use this.

=item finalize

Forces finalized state. Can be used on finalized objects without error.

Note that most higher functions will call this themselves to force a finalized
state. If you do use it it must come before any other finalizing methods, and
will most likely function as a reminder for maintainers where your code
switches from configuration to finalized state.

=item source HASHREF

The source for user supplied information. Defaults to $::form. Changing it
after C<Base> phase has no effect.

=item controller CONTROLLER

A weakened link to the controller that created the GetModels object. Needed for
certain plugin methods.

=back

=head1 DELEGATION METHODS

All of these finalize.

Methods delegating to C<Sorted>:

=over 4

=item *

set_report_generator_sort_options

=item *

get_sort_spec

=item *

get_current_sort_params

=back

Methods delegating to C<Paginated>:

=over 4

=item *

get_paginate_args

=back

=head1 STATES

A GetModels object is in one of 3 states at any given time. Their purpose is to
make a class of bugs impossible that orginated from changing the configuration
of a GetModels object halfway during the request. This was a huge problem in
the old implementation.

=over 4

=item Base

This is the state after creating a new object.

=item Init

In this state all the information needed from the source ($::form) has been read
and subsequent changes to the source have no effect. In the current
implementation this will happen during creation, so that the return value of
C<new> is already in state C<Init>.

=item Finalized

In this state no new configuration will be accepted so that information gotten
through the various methods is consistent. Every information retrieval method
will trigger finalize.

=back


=head1 CONFIGURATION

Most of the configuration will be handed to GetModels on creation via C<new>.
This is a list of accepted params.

=over 4

=item controller SELF

The creating controller. Currently this is mandatory.

=item model MODEL

The name of the model for this GetModels instance. If none is given, the model
is inferred from the name of the controller class.

=item list_action ACTION

If callbacks are generated, use this action instead of the current action.
Usually you can omit this. In case the reporting is done without redirecting
from a mutating action, this is necessary to have callbacks for paginating and
sorting point to the correct action.

=item sorted PARAMS

=item paginated PARAMS

=item filtered PARAMS

Configuration for plugins. If the option for any plugin is omitted, it defaults
to enabled and is configured by default. Giving a falsish value as first argument
will disable the plugin.

If the value is a hashref, it will be passed to the plugin's C<init> method.

=item query

=item with_objects

Additional static parts for Rose to include into the final query.

=item source

Source for plugins to pull their data from. Defaults to $::form.

=back

=head1 BUGS AND CAVEATS

=over 4

=item *

Delegation is not as clean as it should be. Most of the methods rely on action
at a distance and should be moved out.

=back

=head1 AUTHORS

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
