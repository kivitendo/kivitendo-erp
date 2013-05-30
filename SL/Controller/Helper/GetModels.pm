package SL::Controller::Helper::GetModels;

use strict;

use Exporter qw(import);
our @EXPORT = qw(get_models_url_params get_callback get_models);

use constant PRIV => '__getmodelshelperpriv';

my $registered_handlers = {};

sub register_get_models_handlers {
  my ($class, %additional_handlers) = @_;

  my $only        = delete($additional_handlers{ONLY}) || [];
  $only           = [ $only ] if !ref $only;
  my %hook_params = @{ $only } ? ( only => $only ) : ();

  $class->run_before(sub { $_[0]->{PRIV()} = { current_action => $_[1] }; }, %hook_params);

  my $handlers    = _registered_handlers($class);
  map { push @{ $handlers->{$_} }, $additional_handlers{$_} if $additional_handlers{$_} } keys %$handlers;
}

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

  my %default_params = _run_handlers($self, 'callback', action => ($self->{PRIV()} || {})->{current_action});

  return $self->url_for(%default_params, %override_params);
}

sub get_models {
  my ($self, %override_params) = @_;

  my %params                   = _run_handlers($self, 'get_models', %override_params);

  my $model                    = delete($params{model}) || die "No 'model' to work on";

  return "SL::DB::Manager::${model}"->get_all(%params);
}

#
# private/internal functions
#

sub _run_handlers {
  my ($self, $handler_type, %params) = @_;

  foreach my $sub (@{ _registered_handlers(ref $self)->{$handler_type} }) {
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

sub _registered_handlers {
  $registered_handlers->{$_[0]} //= { callback => [], get_models => [] }
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
