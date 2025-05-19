package SL::Controller::Base;

use strict;

use parent qw(Rose::Object);

use Carp;
use IO::File;
use List::Util qw(first);
use MIME::Base64;
use SL::Request qw(flatten);
use SL::MoreCommon qw(uri_encode);
use SL::Presenter;

use Rose::Object::MakeMethods::Generic
(
  scalar                  => [ qw(action_name) ],
  'scalar --get_set_init' => [ qw(js p) ],
);

#
# public/helper functions
#

sub url_for {
  my $self = shift;

  return $_[0] if (scalar(@_) == 1) && !ref($_[0]);

  my %params      = ref($_[0]) eq 'HASH' ? %{ $_[0] } : @_;
  my $controller  = delete($params{controller}) || $self->controller_name;
  my $action      = $params{action}             || 'dispatch';
  my $fragment    = delete $params{fragment};

  my $script;
  if ($controller =~ m/\.pl$/) {
    # Old-style controller
    $script = $controller;
  } else {
    $params{action} = "${controller}/${action}";
    $script         = "controller.pl";
  }

  my $query       = join '&', map { uri_encode($_->[0]) . '=' . uri_encode($_->[1]) } @{ flatten(\%params) };

  return "${script}?${query}" . (defined $fragment ? "#$fragment" : '');
}

sub redirect_to {
  my $self = shift;
  my $url  = $self->url_for(@_);

  if ($self->delay_flash_on_redirect) {
    require SL::Helper::Flash;
    SL::Helper::Flash::delay_flash();
  }

  return $self->render(SL::ClientJS->new->redirect_to($url)) if $::request->is_ajax;

  print $::request->{cgi}->redirect($url);
}

sub render {
  my $self               = shift;
  my $template           = shift;
  my ($options, %locals) = (@_ && ref($_[0])) ? @_ : ({ }, @_);

  # Special handling/shortcut for an instance of SL::ClientJS:
  return $self->render(\$template->to_json, { type => 'json' }) if ref($template) eq 'SL::ClientJS';

  # Set defaults for all available options.
  my %defaults = (
    type       => 'html',
    output     => 1,
    header     => 1,
    layout     => 1,
    process    => 1,
    status     => '200 ok',
  );
  $options->{$_} //= $defaults{$_} for keys %defaults;
  $options->{type} = lc $options->{type};

  # Check supplied options for validity.
  foreach (keys %{ $options }) {
    croak "Unsupported option: $_" unless $defaults{$_};
  }

  # Only certain types are supported.
  croak "Unsupported type: " . $options->{type} unless $options->{type} =~ m/^(?:html|js|json|text)$/;

  # The "template" argument must be a string or a reference to one.
  $template = ${ $template }                                       if ((ref($template) || '') eq 'REF') && (ref(${ $template }) eq 'SL::Presenter::EscapedText');
  croak "Unsupported 'template' reference type: " . ref($template) if ref($template) && (ref($template) !~ m/^(?:SCALAR|SL::Presenter::EscapedText)$/);

  # If all output is turned off then don't output the header either.
  if (!$options->{output}) {
    $options->{header} = 0;
    $options->{layout} = 0;

  } else {
    # Layout only makes sense if we're outputting HTML.
    $options->{layout} = 0 if $options->{type} ne 'html';
  }

  # Let the presenter do the rest of the work.
  my $output;
  {
    local $::form->{title} = $locals{title} if $locals{title};
    $output = $self->presenter->render(
      $template,
      { type => $options->{type}, process => $options->{process} },
      %locals,
      SELF => $self,
    );
  }

  if ($options->{header}) {
    # Output the HTTP response and the layout in case of HTML output.

    if ($options->{layout}) {
      $::form->{title} = $locals{title} if $locals{title};
      $::form->header;

    } else {
      # No layout: just the standard HTTP response. Also notify
      # $::form that the header has already been output so that
      # $::form->header() won't output it again.
      $::form->{header} = 1;
      my $content_type  = $options->{type} eq 'html' ? 'text/html'
                        : $options->{type} eq 'js'   ? 'text/javascript'
                        : $options->{type} eq 'text' ? 'text/plain'
                        :                              'application/json';

      print $::form->create_http_response(content_type => $content_type,
                                          charset      => 'UTF-8',
                                          (status      => $options->{status}) x !!$options->{status});
    }
  }

  # Print the output if wanted.
  print $output if $options->{output};

  return $output;
}

sub send_file {
  my ($self, $file_name_or_content, %params) = @_;

  my ($file, $size);

  if (!ref $file_name_or_content) {
    $file = IO::File->new($file_name_or_content, 'r') || croak("Cannot open file '${file_name_or_content}'");
    $size = -s $file_name_or_content;
  } else {
    $size = length $$file_name_or_content;
  }

  my $content_type    =  $params{type} || 'application/octet_stream';
  my $content_disposition = $params{content_disposition} || 'attachment';
  my $attachment_name =  $params{name} || (!ref($file_name_or_content) ? $file_name_or_content : '');
  $attachment_name    =~ s:.*//::g;

  if ($::request->is_ajax || $params{ajax}) {
    my $octets = ref $file_name_or_content ? $file_name_or_content : \ do { local $/ = undef; <$file> };
    $self->js->save_file(MIME::Base64::encode_base64($$octets), $content_type, $size, $attachment_name);
    $self->js->render unless $params{js_no_render};
  } else {
    print $::form->create_http_response(content_type        => $content_type,
                                        content_disposition => $content_disposition . '; filename="' . $attachment_name . '"',
                                        content_length      => $size);

    if (!ref $file_name_or_content) {
      $::locale->with_raw_io(\*STDOUT, sub { print while <$file> });
      $file->close;
      unlink $file_name_or_content if $params{unlink};
    } else {
      $::locale->with_raw_io(\*STDOUT, sub { print $$file_name_or_content });
    }
  }

  return 1;
}

sub presenter {
  return SL::Presenter->get;
}

sub init_p {
  return SL::Presenter->get;
}

sub controller_name {
  my $class = ref($_[0]) || $_[0];
  $class    =~ s/^SL::Controller:://;
  return $class;
}

sub init_js {
  SL::ClientJS->new(controller => $_[0])
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
      $hook->{code}->($self, $action);
    } else {
      my $sub = $hook->{code};
      $self->$sub($action);
    }
  }
}

#
#  behaviour. override these
#

sub delay_flash_on_redirect {
  0;
}

sub get_auth_level {
  # Ignore the 'action' parameter.
  return 'user';
}

sub keep_auth_vars_in_form {
  return 0;
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

  $self->action_name($action);
  $self->_run_hooks('before', $action);
  $self->$sub(@_);
  $self->_run_hooks('after', $action);
}

sub _dispatch {
  my $self    = shift;

  no strict 'refs';
  my @actions = map { s/^action_//; $_ } grep { m/^action_/ } keys %{ ref($self) . "::" };
  my $action  = first { $::form->{"action_${_}"} } @actions;
  my $sub     = "action_${action}";

  if ($self->can($sub)) {
    $self->action_name($action);
    $self->_run_hooks('before', $action);
    $self->$sub(@_);
    $self->_run_hooks('after', $action);
  } else {
    $::form->error($::locale->text('Oops. No valid action found to dispatch. Please report this case to the kivitendo team.'));
  }
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

The hooks receive a single parameter: the name of the action that is
about to be called (for C<before> hooks) / was called (for C<after>
hooks).

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

What is rendered and how C<$template> is interpreted is determined
both by C<$template>'s reference type and by the supplied options. The
actual rendering is handled by L<SL::Presenter/render>.

If C<$template> is a normal scalar (not a reference) then it is meant
to be a template file name relative to the C<templates/design40_webpages>
directory. The file name to use is determined by the C<type> option.

If C<$template> is a reference to a scalar then the referenced
scalar's content is used as the content to process. The C<type> option
is not considered in this case.

C<$template> can also be an instance of L<SL::Presenter::EscapedText>
or a reference to such an instance. Both of these cases are handled
the same way as if C<$template> were a reference to a scalar: its
content is processed, and C<type> is not considered.

Other reference types, unknown options and unknown arguments to the
C<type> option cause the function to L<croak>.

The following options are available (defaults: C<type> = 'html',
C<process> = 1, C<output> = 1, C<header> = 1, C<layout> = 1):

=over 2

=item C<type>

The template type. Can be C<html> (the default), C<js> for JavaScript,
C<json> for JSON and C<text> for plain text content. Affects the
extension that's added to the file name given with a non-reference
C<$template> argument, the content type HTTP header that is output and
whether or not the layout will be output as well (see description of
C<layout> below).

=item C<process>

If trueish (which is also the default) it causes the template/content
to be processed by the Template toolkit. Otherwise the
template/content is output as-is.

=item C<output>

If trueish (the default) then the generated output will be sent to the
browser in addition to being returned. If falsish then the options
C<header> and C<layout> are set to 0 as well.

=item C<header>

Determines whether or not to output the HTTP response
headers. Defaults to the same value that C<output> is set to. If set
to falsish then the layout is not output either.

=item C<layout>

Determines whether or not the basic HTML layout structure should be
output (HTML header, common JavaScript and stylesheet inclusions, menu
etc.). Defaults to 0 if C<type> is not C<html> and to the same value
C<header> is set to otherwise.

=back

The template itself has access to several variables. These are listed
in the documentation to L<SL::Presenter/render>.

The function will always return the output.

Example: Render a HTML template with a certain title and a few locals

  $self->render('todo/list',
                title      => 'List TODO items',
                TODO_ITEMS => SL::DB::Manager::Todo->get_all_sorted);

Example: Render a string and return its content for further processing
by the calling function. No header is generated due to C<output>.

  my $content = $self->render(\'[% USE JavaScript %][% JavaScript.replace_with("#someid", "js/something") %]',
                              { output => 0 });

Example: Render a JavaScript template
"templates/design40_webpages/todo/single_item.js" and send it to the
browser. Typical use for actions called via AJAX:

  $self->render('todo/single_item', { type => 'js' },
                item => $employee->most_important_todo_item);

=item C<send_file $file_name_or_content, [%params]>

Sends the file C<$file_name_or_content> to the browser including
appropriate HTTP headers for a download. If C<$file_name_or_content>
is a scalar then it is interpreted as a file name which is opened and
whose content is sent. Otherwise (C<$file_name_or_content> being a
reference) the referenced scalar's data itself is sent.

C<%params> can include the following:

=over 2

=item * C<type> -- the file's content type; defaults to
'application/octet_stream'

=item * C<name> -- the name presented to the browser; defaults to
C<$file_name>; mandatory if C<$file_name_or_content> is a reference

=item * C<unlink> -- if trueish and C<$file_name_or_content> refers to
a file name then unlink the file after it has been sent to the browser
(e.g. for temporary files)

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
L</controller_name>.

The action to call is given by C<$params{action}>. It defaults to
C<dispatch>.

If C<$params{fragment}> is present, it's used as the fragment of the resulting
URL.

All other key/value pairs in C<%params> are appended as GET parameters
to the URL.

Usage from a template might look like this:

  <a href="[% SELF.url_for(controller => 'Message', action => 'new', recipient_id => 42) %]">create new message</a>

=item C<redirect_to %url_params>

Redirects the browser to a new URL. The URL is generated by calling
L</url_for> with C<%url_params>.

This function implements the redirection depending on whether or not
the current request is an AJAX request as determined by
L<SL::Request/is_ajax>. If it is a normal request then it outputs a
standard HTTP redirect header (HTTP code 302). If it is an AJAX
request then it outputs an AJAX response suitable for the
C<kivi.eval_json_result> function from the L<SL::ClientJS> module.

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

=item C<delay_flash_on_redirect>

May be overridden by a controller. If this method returns true, redirect_to
will delay all flash messages for the current request. Defaults to false for
compatibility reasons.

=item C<get_auth_level $action>

May be overridden by a controller. Determines what kind of
authentication is required for a particular action. Must return either
C<admin> (which means that authentication as an admin is required),
C<user> (authentication as a normal user suffices) with a possible
future value C<none> (which would require no authentication but is not
yet implemented).

=item C<keep_auth_vars_in_form %params>

May be overridden by a controller. If falsish (the default) all form
variables whose name starts with C<{AUTH}> are removed before the
request is routed. Only controllers that handle login requests
themselves should return trueish for this function.

C<$params{action}> contains the action name that the request will be
dispatched to.

=item C<controller_name>

Returns the name of the curernt controller package without the
C<SL::Controller::> prefix. This method can be called both as a class
method and an instance method.

=item C<action_name>

Returns the name of the currently executing action. If the dispatcher
mechanism was used then this is not C<dispatch> but the actual method
name the dispatching resolved to.

=item C<presenter>

Returns the global presenter object by calling
L<SL::Presenter/get>.

=item C<js>

Returns an L<SL::ClientJS> instance for this controller.

=back

=head2 PRIVATE FUNCTIONS

These functions are supposed to be used from this base class only.

=over 4

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
