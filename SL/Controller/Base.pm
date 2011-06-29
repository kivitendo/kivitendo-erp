package SL::Controller::Base;

use strict;

use parent qw(Rose::Object);

use Carp;
use IO::File;
use List::Util qw(first);

#
# public/helper functions
#

sub url_for {
  my $self = shift;

  return $_[0] if (scalar(@_) == 1) && !ref($_[0]);

  my %params      = ref($_[0]) eq 'HASH' ? %{ $_[0] } : @_;
  my $controller  = delete($params{controller}) || $self->_controller_name;
  my $action      = delete($params{action})     || 'dispatch';
  $params{action} = "${controller}/${action}";
  my $query       = join('&', map { $::form->escape($_) . '=' . $::form->escape($params{$_}) } keys %params);

  return "controller.pl?${query}";
}

sub redirect_to {
  my $self = shift;
  my $url  = $self->url_for(@_);

  print $::cgi->redirect($url);
}

sub render {
  my $self               = shift;
  my $template           = shift;
  my ($options, %locals) = (@_ && ref($_[0])) ? @_ : ({ }, @_);

  $options->{type}       = lc($options->{type} || 'html');
  $options->{no_layout}  = 1 if $options->{type} eq 'js';

  my $source;
  if ($options->{inline}) {
    $source = \$template;

  } else {
    $source = "templates/webpages/${template}." . $options->{type};
    croak "Template file ${source} not found" unless -f $source;
  }

  if (!$options->{partial} && !$options->{inline} && !$::form->{header}) {
    if ($options->{no_layout}) {
      $::form->{header} = 1;
      my $content_type  = $options->{type} eq 'js' ? 'text/javascript' : 'text/html';

      print $::form->create_http_response(content_type => $content_type,
                                          charset      => $::lx_office_conf{system}->{dbcharset} || Common::DEFAULT_CHARSET());

    } else {
      $::form->{title} = $locals{title} if $locals{title};
      $::form->header;
    }
  }

  my %params = ( %locals,
                 AUTH          => $::auth,
                 FLASH         => $::form->{FLASH},
                 FORM          => $::form,
                 INSTANCE_CONF => $::instance_conf,
                 LOCALE        => $::locale,
                 LXCONFIG      => \%::lx_office_conf,
                 LXDEBUG       => $::lxdebug,
                 MYCONFIG      => \%::myconfig,
                 SELF          => $self,
               );

  my $output;
  my $parser = $self->_template_obj;
  $parser->process($source, \%params, \$output) || croak $parser->error;

  print $output unless $options->{inline} || $options->{no_output};

  return $output;
}

sub send_file {
  my ($self, $file_name, %params) = @_;

  my $file            = IO::File->new($file_name, 'r') || croak("Cannot open file '${file_name}'");
  my $content_type    =  $params{type} || 'application/octet_stream';
  my $attachment_name =  $params{name} || $file_name;
  $attachment_name    =~ s:.*//::g;

  print $::form->create_http_response(content_type        => $content_type,
                                      content_disposition => 'attachment; filename="' . $attachment_name . '"',
                                      content_length      => -s $file);

  $::locale->with_raw_io(\*STDOUT, sub { print while <$file> });
  $file->close;
}

#
# Before/after run hooks
#

sub run_before {
  _add_hook('before', @_);
}

sub run_after {
  _add_hook('after', @_);
}

my %hooks;

sub _add_hook {
  my ($when, $class, $sub, %params) = @_;

  foreach my $key (qw(only except)) {
    $params{$key} = { map { ( $_ => 1 ) } @{ $params{$key} } } if $params{$key};
  }

  my $idx = "${when}/${class}";
  $hooks{$idx} ||= [ ];
  push @{ $hooks{$idx} }, { %params, code => $sub };
}

sub _run_hooks {
  my ($self, $when, $action) = @_;

  my $idx = "${when}/" . ref($self);

  foreach my $hook (@{ $hooks{$idx} || [] }) {
    next if ($hook->{only  } && !$hook->{only  }->{$action})
         || ($hook->{except} &&  $hook->{except}->{$action});

    if (ref($hook->{code}) eq 'CODE') {
      $hook->{code}->($self);
    } else {
      my $sub = $hook->{code};
      $self->$sub;
    }
  }
}

#
# private functions -- for use in Base only
#

sub _run_action {
  my $self   = shift;
  my $action = shift;
  my $sub    = "action_${action}";

  return $self->_dispatch(@_) if $action eq 'dispatch';

  $::form->error("Invalid action '${action}' for controller " . ref($self)) if !$self->can($sub);

  $self->_run_hooks('before', $action);
  $self->$sub(@_);
  $self->_run_hooks('after', $action);
}

sub _controller_name {
  return (split(/::/, ref($_[0])))[-1];
}

sub _dispatch {
  my $self    = shift;

  no strict 'refs';
  my @actions = map { s/^action_//; $_ } grep { m/^action_/ } keys %{ ref($self) . "::" };
  my $action  = first { $::form->{"action_${_}"} } @actions;
  my $sub     = "action_${action}";

  if ($self->can($sub)) {
    $self->_run_hooks('before', $action);
    $self->$sub(@_);
    $self->_run_hooks('after', $action);
  } else {
    $::form->error($::locale->text('Oops. No valid action found to dispatch. Please report this case to the Lx-Office team.'));
  }
}

sub _template_obj {
  my ($self) = @_;

  $self->{__basepriv_template_obj} ||=
    Template->new({ INTERPOLATE  => 0,
                    EVAL_PERL    => 0,
                    ABSOLUTE     => 1,
                    CACHE_SIZE   => 0,
                    PLUGIN_BASE  => 'SL::Template::Plugin',
                    INCLUDE_PATH => '.:templates/webpages',
                    COMPILE_EXT  => '.tcc',
                    COMPILE_DIR  => $::lx_office_conf{paths}->{userspath} . '/templates-cache',
                  }) || croak;

  return $self->{__basepriv_template_obj};
}

1;

__END__

=head1 NAME

SL::Controller::Base - base class for all action controllers

=head1 SYNOPSIS

=head2 OVERVIEW

This is a base class for all action controllers. Action controllers
provide subs that are callable by special URLs.

For each request made to the web server an instance of the controller
will be created. After the request has been served that instance will
handed over to garbage collection.

This base class is derived from L<Rose::Object>.

=head2 CONVENTIONS

The URLs have the following properties:

=over 2

=item *

The script part of the URL must be C<controller.pl>.

=item *

There must be a GET or POST parameter named C<action> containing the
name of the controller and the sub to call separated by C</>,
e.g. C<Message/list>.

=item *

The controller name is the package's name without the
C<SL::Controller::> prefix. At the moment only packages in the
C<SL::Controller> namespace are valid; sub-namespaces are not
allowed. The package name must start with an upper-case letter.

=item *

The sub part of the C<action> parameter is the name of the sub to
call. However, the sub's name is automatically prefixed with
C<action_>. Therefore for the example C<Message/list> the sub
C<SL::DB::Message::action_list> would be called. This in turn means
that subs whose name does not start with C<action_> cannot be invoked
directly via the URL.

=back

=head2 INDIRECT DISPATCHING

In the case that there are several submit buttons on a page it is
often impractical to have a single C<action> parameter match up
properly. For such a case a special dispatcher method is available. In
that case the C<action> parameter of the URL must be
C<Controller/dispatch>.

The C<SL::Controller::Base::_dispatch> method will iterate over all
subs in the controller package whose names start with C<action_>. The
first one for which there's a GET or POST parameter with the same name
and that's trueish is called.

Usage from a template usually looks like this:

  <form method="POST" action="controller.pl">
    ...
    <input type="hidden" name="action" value="Message/dispatch">
    <input type="submit" name="action_mark_as_read" value="Mark messages as read">
    <input type="submit" name="action_delete" value="Delete messages">
  </form>

The dispatching is handled by the function L</_dispatch>.

=head2 HOOKS

Hooks are functions that are called before or after the controller's
action is called. The controller package defines the hooks, and those
hooks themselves are run as instance methods.

Hooks are run in the order they're added.

The return value of the hooks is discarded.

Hooks can be defined to run for all actions, for only specific actions
or for all actions except a list of actions. Each entry is the action
name, not the sub's name. Therefore in order to run a hook before one
of the subs C<action_edit> or C<action_save> is called the following
code can be used:

  __PACKAGE__->run_before('things_to_do_before_edit_and_save', only => [ 'edit', 'save' ]);

=head1 FUNCTIONS

=head2 PUBLIC HELPER FUNCTIONS

These functions are supposed to be called by sub-classed controllers.

=over 4

=item C<render $template, [ $options, ] %locals>

Renders the template C<$template>. Provides other variables than
C<Form::parse_html_template> does.

C<$options>, if present, must be a hash reference. All remaining
parameters are slurped into C<%locals>.

What is rendered and how C<$template> is interpreted is determined by
the options I<type>, I<inline>, I<partial> and I<no_layout>.

If C<< $options->{inline} >> is trueish then C<$template> is a string
containing the template code to interprete. Additionally the output
will not be sent to the browser. Instead it is only returned to the
caller.

If C<< $options->{inline} >> is falsish then C<$template> is
interpreted as the name of a template file. It is prefixed with
"templates/webpages/" and postfixed with a file extension based on
C<< $options->{type} >>. C<< $options->{type} >> can be either C<html>
or C<js> and defaults to C<html>. An exception will be thrown if that
file does not exist.

If C<< $options->{partial} >> or C<< $options->{inline} >> is trueish
then neither the HTTP response header nor the standard HTML header is
generated.

Otherwise at least the HTTP response header will be generated based on
the template type (C<< $options->{type} >>).

If the template type is C<html> then the standard HTML header will be
output via C<< $::form->header >> with C<< $::form->{title} >> set to
C<$locals{title}> (the latter only if C<$locals{title}> is
trueish). Setting C<< $options->{no_layout} >> to trueish will prevent
this.

The template itself has access to the following variables:

=over 2

=item * C<AUTH> -- C<$::auth>

=item * C<FORM> -- C<$::form>

=item * C<LOCALE> -- C<$::locale>

=item * C<LXCONFIG> -- all parameters from C<config/lx_office.conf>
with the same name they appear in the file (first level is the
section, second the actual variable, e.g. C<system.dbcharset>,
C<features.webdav> etc)

=item * C<LXDEBUG> -- C<$::lxdebug>

=item * C<MYCONFIG> -- C<%::myconfig>

=item * C<SELF> -- the controller instance

=item * All items from C<%locals>

=back

Unless C<< $options->{inline} >> is trueish the function will send the
output to the browser.

The function will always return the output.

Example: Render a HTML template with a certain title and a few locals

  $self->render('todo/list',
                title      => 'List TODO items',
                TODO_ITEMS => SL::DB::Manager::Todo->get_all_sorted);

Example: Render a string and return its content for further processing
by the calling function. No header is generated due to C<inline>.

  my $content = $self->render('[% USE JavaScript %][% JavaScript.replace_with("#someid", "js/something") %]',
                              { type => 'js', inline => 1 });

Example: Render a JavaScript template and send it to the
browser. Typical use for actions called via AJAX:

  $self->render('todo/single_item', { type => 'js' },
                item => $employee->most_important_todo_item);

=item C<send_file $file_name, [%params]>

Sends the file C<$file_name> to the browser including appropriate HTTP
headers for a download. C<%params> can include the following:

=over 2

=item * C<type> -- the file's content type; defaults to
'application/octet_stream'

=item * C<name> -- the name presented to the browser; defaults to
C<$file_name>

=back

=item C<url_for $url>

=item C<url_for $params>

=item C<url_for %params>

Creates an URL for the given parameters suitable for calling an action
controller. If there's only one scalar parameter then it is returned
verbatim.

Otherwise the parameters are given either as a single hash ref
parameter or as a normal hash.

The controller to call is given by C<$params{controller}>. It defaults
to the current controller as returned by
L</_controller_name>.

The action to call is given by C<$params{action}>. It defaults to
C<dispatch>.

All other key/value pairs in C<%params> are appended as GET parameters
to the URL.

Usage from a template might look like this:

  <a href="[% SELF.url_for(controller => 'Message', action => 'new', recipient_id => 42) %]">create new message</a>

=item C<redirect_to %url_params>

Redirects the browser to a new URL by outputting a HTTP redirect
header. The URL is generated by calling L</url_for> with
C<%url_params>.

=item C<run_before $sub, %params>

=item C<run_after $sub, %params>

Adds a hook to run before or after certain actions are run for the
current package. The code to run is C<$sub> which is either the name
of an instance method or a code reference. If it's the latter then the
first parameter will be C<$self>.

C<%params> can contain two possible values that restrict the code to
be run only for certain actions:

=over 2

=item C<< only => \@list >>

Only run the code for actions given in C<@list>. The entries are the
action names, not the names of the sub (so it's C<list> instead of
C<action_list>).

=item C<< except => \@list >>

Run the code for all actions but for those given in C<@list>. The
entries are the action names, not the names of the sub (so it's
C<list> instead of C<action_list>).

=back

If neither restriction is used then the code will be run for any
action.

The hook's return values are discarded.

=back

=head2 PRIVATE FUNCTIONS

These functions are supposed to be used from this base class only.

=over 4

=item C<_controller_name>

Returns the name of the curernt controller package without the
C<SL::Controller::> prefix.

=item C<_dispatch>

Implements the method lookup for indirect dispatching mentioned in the
section L</INDIRECT DISPATCHING>.

=item C<_run_action $action>

Executes a sub based on the value of C<$action>. C<$action> is the sub
name part of the C<action> GET or POST parameter as described in
L</CONVENTIONS>.

If C<$action> equals C<dispatch> then the sub L</_dispatch> in this
base class is called for L</INDIRECT DISPATCHING>. Otherwise
C<$action> is prefixed with C<action_>, and that sub is called on the
current controller instance.

=back

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
