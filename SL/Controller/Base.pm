package SL::Controller::Base;

use parent qw(Rose::Object);

use Carp;
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

  my $source;
  if ($options->{inline}) {
    $source = \$template;

  } else {
    $source = "templates/webpages/${template}.html";
    croak "Template file ${source} not found" unless -f $source;
  }

  if (!$options->{partial} && !$options->{inline}) {
    $::form->{title} = $locals{title} if $locals{title};
    $::form->header;
  }

  my %params = ( %locals,
                 AUTH     => $::auth,
                 FORM     => $::form,
                 LOCALE   => $::locale,
                 LXCONFIG => { dbcharset              => $::dbcharset,
                               webdav                 => $::webdav,
                               lizenzen               => $::lizenzen,
                               latex_templates        => $::latex,
                               opendocument_templates => $::opendocument_templates,
                               vertreter              => $::vertreter,
                               show_best_before       => $::show_best_before,
                             },
                 LXDEBUG  => $::lxdebug,
                 MYCONFIG => \%::myconfig,
                 SELF     => $self,
               );

  my $output;
  my $parser = $self->_template_obj;
  $parser->process($source, \%params, \$output) || croak $parser->error;

  print $output unless $options->{inline};

  return $output;
}

#
# private functions -- for use in Base only
#

sub _run_action {
  my $self   = shift;
  my $action = "action_" . shift;

  return $self->_dispatch(@_) if $action eq 'action_dispatch';

  $::form->error("Invalid action ${action} for controller " . ref($self)) if !$self->can($action);
  $self->$action(@_);
}

sub _controller_name {
  return (split(/::/, ref($_[0])))[-1];
}

sub _dispatch {
  my $self    = shift;

  my @actions = grep { m/^action_/ } keys %{ ref($self) . "::" };
  my $action  = first { $::form->{$_} } @actions;

  $self->$action(@_);
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
                    COMPILE_DIR  => $::userspath . '/templates-cache',
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
C<< $options->{inline} >> and C<< $options->{partial} >>.

If C<< $options->{inline} >> is trueish then C<$template> is a string
containing the template code to interprete. Additionally the output
will not be sent to the browser. Instead it is only returned to the
caller.

If C<< $options->{inline} >> is falsish then C<$template> is
interpreted as the name of a template file. It is prefixed with
"templates/webpages/" and postfixed with ".html". An exception will be
thrown if that file does not exist.

If C<< $options->{partial} >> is trueish then C<< $::form->header >>
will not be called. Otherwise C<< $::form->{header} >> will be set to
C<$locals{header}> (only if $locals{header} is trueish) and
C<< $::form->header >> will be called before the template itself is
processed.

The template itself has access to the following variables:

=over 2

=item * C<AUTH> -- C<$::auth>

=item * C<FORM> -- C<$::form>

=item * C<LOCALE> -- C<$::locale>

=item * C<LXCONFIG> -- all parameters from C<config/lx-erp.conf> with
the same name they appear in the file (e.g. C<dbcharset>, C<webdav>
etc)

=item * C<LXDEBUG> -- C<$::lxdebug>

=item * C<MYCONFIG> -- C<%::myconfig>

=item * C<SELF> -- the controller instance

=item * All items from C<%locals>

=back

Unless C<< $options->{inline} >> is trueish the function will send the
output to the browser.

The function will always return the output.

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

=item redirect_to %url_params

Redirects the browser to a new URL by outputting a HTTP redirect
header. The URL is generated by calling L</url_for> with
C<%url_params>.

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
