package SL::ClientJS;

use strict;

use parent qw(Rose::Object);

use Carp;
use SL::JSON ();

use Rose::Object::MakeMethods::Generic
(
  scalar                  => [ qw() ],
  'scalar --get_set_init' => [ qw(controller _actions _error) ],
);

my %supported_methods = (
  # ## jQuery basics ##

  # Basic effects
  hide         => 1,
  show         => 1,
  toggle       => 1,

  # DOM insertion, around
  unwrap       => 1,
  wrap         => 2,
  wrapAll      => 2,
  wrapInner    => 2,

  # DOM insertion, inside
  append       => 2,
  appendTo     => 2,
  html         => 2,
  prepend      => 2,
  prependTo    => 2,
  text         => 2,

  # DOM insertion, outside
  after        => 2,
  before       => 2,
  insertAfter  => 2,
  insertBefore => 2,

  # DOM removal
  empty        => 1,
  remove       => 1,

  # DOM replacement
  replaceAll   => 2,
  replaceWith  => 2,

  # General attributes
  attr         => 3,
  prop         => 3,
  removeAttr   => 2,
  removeProp   => 2,
  val          => 2,

  # Class attribute
  addClass     => 2,
  removeClass  => 2,
  toggleClass  => 2,

  # Data storage
  data         => 3,
  removeData   => 2,

  # Form Events
  focus        => 1, # kivi.set_focus(<TARGET>)

  # Generic Event Handling ## pattern: $(<TARGET>).<FUNCTION>(<ARG1>, kivi.get_function_by_name(<ARG2>))
  on           => 3,
  off          => 3,
  one          => 3,

  # ## jQuery UI dialog plugin ## pattern: $(<TARGET>).dialog('<FUNCTION>')

  # Opening and closing a popup
  'dialog:open'          => 1, # kivi.popup_dialog(<TARGET>)
  'dialog:close'         => 1,

  # ## jQuery Form plugin ##
  'ajaxForm'             => 1, # $(<TARGET>).ajaxForm({ success: eval_json_result })

  # ## jstree plugin ## pattern: $.jstree._reference($(<TARGET>)).<FUNCTION>(<ARGS>)

  # Operations on the whole tree
  'jstree:lock'          => 1,
  'jstree:unlock'        => 1,

  # Opening and closing nodes
  'jstree:open_node'     => 2,
  'jstree:open_all'      => 2,
  'jstree:close_node'    => 2,
  'jstree:close_all'     => 2,
  'jstree:toggle_node'   => 2,
  'jstree:save_opened'   => 1,
  'jstree:reopen'        => 1,

  # Modifying nodes
  'jstree:create_node'   => 4,
  'jstree:rename_node'   => 3,
  'jstree:delete_node'   => 2,
  'jstree:move_node'     => 5,

  # Selecting nodes (from the 'ui' plugin to jstree)
  'jstree:select_node'   => 2,  # $.jstree._reference($(<TARGET>)).<FUNCTION>(<ARGS>, true)
  'jstree:deselect_node' => 2,
  'jstree:deselect_all'  => 1,

  # ## ckeditor stuff ##
  'focus_ckeditor'       => 1,  # kivi.focus_ckeditor_when_ready(<TARGET>)

  # ## other stuff ##
  redirect_to            => 1,  # window.location.href = <TARGET>
  save_file              => 4,  # kivi.save_file(<TARGET>, <ARGS>)

  # flash
  flash                  => -2, # kivi.Flash.display_flash.apply({}, action.slice(1, action.length))
  clear_flash            => 0,  # kivi.Flash.clear_flash()
  show_flash             => 0,  # kivi.Flash.show()
  hide_flash             => 0,  # kivi.Flash.hide()

  reinit_widgets         => 0,  # kivi.reinit_widgets()
  run                    => -1, # kivi.run(<TARGET>, <ARGS>)
  run_once_for           => 3,  # kivi.run_once_for(<TARGET>, <ARGS>)

  scroll_into_view       => 1,  # $(<TARGET>)[0].scrollIntoView()

  set_cursor_position    => 2,  # kivi.set_cursor_position(<TARGET>, <ARGS>)
);

my %trim_target_for = map { ($_ => 1) } qw(insertAfter insertBefore appendTo prependTo);

sub AUTOLOAD {
  our $AUTOLOAD;

  my ($self, @args) = @_;

  my $method        =  $AUTOLOAD;
  $method           =~ s/.*:://;
  return if $method eq 'DESTROY';
  return $self->action($method, @args);
}

sub action {
  my ($self, $method, @args) = @_;

  $method      =  (delete($self->{_prefix}) || '') . $method;
  my $num_args =  $supported_methods{$method};

  croak "Unsupported jQuery action: $method" unless defined $num_args;

  if ($num_args > 0) {
    croak "Parameter count mismatch for $method(actual: " . scalar(@args) . " wanted: $num_args)"          if scalar(@args) != $num_args;
  } else {
    $num_args *= -1;
    croak "Parameter count mismatch for $method(actual: " . scalar(@args) . " wanted at least: $num_args)" if scalar(@args) < $num_args;
    $num_args  = scalar @args;
  }

  foreach my $idx (0..$num_args - 1) {
    # Force flattening from SL::Presenter::EscapedText.
    $args[$idx] = "" . $args[$idx] if ref($args[$idx]) eq 'SL::Presenter::EscapedText';
  }

  # Trim leading whitespaces for certain jQuery functions that operate
  # on HTML code: $("<p>test</p>").appendTo('#some-id'). jQuery croaks
  # on leading whitespaces, e.g. on $(" <p>test</p>").
  $args[0] =~ s{^\s+}{} if $trim_target_for{$method};

  push @{ $self->_actions }, [ $method, @args ];

  return $self;
}

sub action_if {
  my ($self, $condition, @args) = @_;

  return $condition ? $self->action(@args) : $self;
}

sub init__actions {
  return [];
}

sub init__error {
  return '';
}

sub to_json {
  my ($self) = @_;

  return SL::JSON::to_json({ error          => $self->_error   }) if $self->_error;
  return SL::JSON::to_json({ eval_actions => $self->_actions });
}

sub to_array {
  my ($self) = @_;
  return $self->_actions;
}

sub transfer_flash {
  my ($self) = @_;
  $self->flash(@$_) for SL::Helper::Flash->flash_contents;
}

sub render {
  my ($self, $controller) = @_;
  $controller ||= $self->controller;
  $self->reinit_widgets if $::request->presenter->need_reinit_widgets;
  $self->transfer_flash;
  return $controller->render(\$self->to_json, { type => 'json' });
}

sub jstree {
  my ($self) = @_;
  $self->{_prefix} = 'jstree:';
  return $self;
}

sub dialog {
  my ($self) = @_;
  $self->{_prefix} = 'dialog:';
  return $self;
}

sub ckeditor {
  my ($self) = @_;
  $self->{_prefix} = 'ckeditor:';
  return $self;
}

sub no_flash_clear{
  $_[0]; # noop for compatibility
}

sub error {
  my ($self, @messages) = @_;

  $self->_error(join ' ', grep { $_ } ($self->_error, @messages));

  return $self;
}

sub init_controller {
  # fallback
  require SL::Controller::Base;
  SL::Controller::Base->new;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::ClientJS - Easy programmatic client-side JavaScript generation
with jQuery

=head1 SYNOPSIS

First some JavaScript code:

  // In the client generate an AJAX request whose 'success' handler
  // calls "eval_json_result(data)":
  var data = {
    action: "SomeController/my_personal_action",
    id:     $('#some_input_field').val()
  };
  $.post("controller.pl", data, eval_json_result);

Now some Controller (perl) code for my personal action:

  # my personal action
  sub action_my_personal_action {
    my ($self) = @_;

    # Create a new client-side JS object and do stuff with it!
    my $js = SL::ClientJS->new(controller => $self);

    # Show some element on the page:
    $js->show('#usually_hidden');

    # Set to hidden inputs. Yes, calls can be chained!
    $js->val('#hidden_id', $self->new_id)
       ->val('#other_type', 'Unicorn');

    # Replace some HTML code:
    my $html = $self->render('SomeController/the_action', { output => 0 });
    $js->html('#id_with_new_content', $html);

    # Operations on a jstree: rename a node and select it
    my $text_block = SL::DB::RequirementSpecTextBlock->new(id => 4711)->load;
    $js->jstree->rename_node('#tb-' . $text_block->id, $text_block->title)
       ->jstree->select_node('#tb-' . $text_block->id);

    # Close a popup opened by kivi.popup_dialog():
    $js->dialog->close('#jqueryui_popup_dialog');

    # Finally render the JSON response:
    $self->render($js);

    # Rendering can also be chained, e.g.
    $js->html('#selector', $html)
       ->render;
  }

=head1 OVERVIEW

This module enables the generation of jQuery-using JavaScript code on
the server side. That code is then evaluated in a safe way on the
client side.

The workflow is usually that the client creates an AJAX request, the
server creates some actions and sends them back, and the client then
implements each of these actions.

There are three things that need to be done for this to work:

=over 2

=item 1. The "client_js.js" has to be loaded before the AJAX request is started.

=item 2. The client code needs to call C<kivi.eval_json_result()> with the result returned from the server.

=item 3. The server must use this module.

=back

The functions called on the client side are mostly jQuery
functions. Other functionality may be added later.

Note that L<SL::Controller/render> is aware of this module which saves
you some boilerplate. The following two calls are equivalent:

  $controller->render($client_js);
  $controller->render(\$client_js->to_json, { type => 'json' });

=head1 FUNCTIONS NOT PASSED TO THE CLIENT SIDE

=over 4

=item C<to_array>

Returns the actions gathered so far as an array reference. Each
element is an array reference containing at least two items: the
function's name and what it is called on. Additional array elements
are the function parameters.

=item C<to_json>

Returns the actions gathered so far as a JSON string ready to be sent
to the client.

=item C<render [$controller]>

Renders C<$self> via the controller. Useful for chaining. Equivalent
to the following:

  $controller->render(\$self->to_json, { type => 'json' });

The controller instance to use can be set during object creation (see
synopsis) or as an argument to C<render>.

=item C<dialog>

Tells C<$self> that the next action is to be called on a jQuery UI
dialog instance, e.g. one opened by C<kivi.popup_dialog()>. For
example:

  $js->dialog->close('#jqueryui_popup_dialog');

=item C<jstree>

Tells C<$self> that the next action is to be called on a jstree
instance. For example:

  $js->jstree->rename_node('tb-' . $text_block->id, $text_block->title);

=back

=head1 FUNCTIONS EVALUATED ON THE CLIENT SIDE

=head2 GENERIC FUNCTION

All of the following functions can be invoked in two ways: either by
calling the function name directly on C<$self> or by calling
L</action> with the function name as the first parameter. Therefore
the following two calls are identical:

  $js->insertAfter($html, '#some-id');
  $js->action('insertAfter', $html, '#some-id');

The second form, calling L</action>, is more to type but can be useful
in situations in which you have to call one of two functions depending
on context. For example, when you want to insert new code in a
list. If the list is empty you might have to use C<appendTo>, if it
isn't you might have to use C<insertAfter>. Example:

  my $html = $self->render(...);
  $js->action($list_is_empty ? 'appendTo' : 'insertAfter', $html, '#text-block-' . ($list_is_empty ? 'list' : $self->text_block->id));

Instead of:

  my $html = $self->render(...);
  if ($list_is_empty) {
    $js->appendTo($html, '#text-block-list');
  } else {
    $js->insertAfter($html, '#text-block-' . $self->text_block->id);
  }

The first variation is obviously better suited for chaining.

=over 4

=item C<action $method, @args>

Call the function with the name C<$method> on C<$self> with arguments
C<@args>. Returns the return value of the actual function
called. Useful for chaining (see above).

=item C<action_if $condition, $method, @args>

Call the function with the name C<$method> on C<$self> with arguments
C<@args> if C<$condition> is trueish. Does nothing otherwise.

Returns the return value of the actual function called if
C<$condition> is trueish and C<$self> otherwise. Useful for chaining
(see above).

This function is equivalent to the following:

  if ($condition) {
    $obj->$method(@args);
  }

But it is easier to integrate into a method call chain, e.g.:

  $js->html('#content', $html)
     ->action_if($item->is_flagged, 'toggleClass', '#marker', 'flagged')
     ->render($self);

=back

=head2 ADDITIONAL FUNCTIONS

=over 4

=item C<flash $type, $message [, $details [, timestamp ]]>

Display a C<$message> in the flash of type C<$type> with optional
C<$details>.

=item C<error $message>

Causes L<to_json> (and therefore L<render>) to output a JSON object
that only contains an C<error> field set to this C<$message>. The
client will then show the message in the 'error' flash.

The messages of multiple calls of C<error> on the same C<$self> will
be merged.

=item C<redirect_to $url>

Redirects the browser window to the new URL by setting the JavaScript
property C<window.location.href>. Note that
L<SL::Controller::Base/redirect_to> is AJAX aware and uses this
function if the current request is an AJAX request as determined by
L<SL::Request/is_ajax>.

=back

=head2 KIVITENDO FUNCTIONS

The following functions from the C<kivi> namespace are supported:

=over 4

=item Displaying stuff

C<flash> (don't call directly, use L</flash> instead)

=item Running functions

C<run>, C<run_once_for>

=item Widgets

C<reinit_widgets>

=back

=head2 JQUERY FUNCTIONS

The following jQuery functions are supported:

=over 4

=item Basic effects

C<hide>, C<show>, C<toggle>

=item DOM insertion, around

C<unwrap>, C<wrap>, C<wrapAll>, C<wrapInner>

=item DOM insertion, inside

C<append>, C<appendTo>, C<html>, C<prepend>, C<prependTo>, C<text>

=item DOM insertion, outside

C<after>, C<before>, C<insertAfter>, C<insertBefore>

=item DOM removal

C<empty>, C<remove>

=item DOM replacement

C<replaceAll>, C<replaceWith>

=item General attributes

C<attr>, C<prop>, C<removeAttr>, C<removeProp>, C<val>

=item Class attributes

C<addClass>, C<removeClass>, C<toggleClass>

=item Data storage

C<data>, C<removeData>

=item Form Events

C<focus>

=item Generic Event Handlers

C<on>, C<off>, C<one>

These attach/detach event listeners to specific selectors. The first
argument is the selector, the second the name of the events and the
third argument is the name of the handler function. That function must
already exist when the handler is added.

=back

=head2 JQUERY POPUP DIALOG PLUGIN

Supported functions of the C<popup dialog> plugin to jQuery. They are
invoked by first calling C<dialog> in the ClientJS instance and then
the function itself:

  $js->dialog->close(...);

=over 4

=item Closing and removing the popup

C<close>

=back

=head2 AJAXFORM JQUERY PLUGIN

The following functions of the C<ajaxForm> plugin to jQuery are
supported:

=over 4

=item All functions by the generic accessor function:

C<ajaxForm>

=back

=head2 JSTREE JQUERY PLUGIN

Supported functions of the C<jstree> plugin to jQuery. They are
invoked by first calling C<jstree> in the ClientJS instance and then
the function itself:

  $js->jstree->open_node(...);

=over 4

=item Operations on the whole tree

C<lock>, C<unlock>

=item Opening and closing nodes

C<open_node>, C<close_node>, C<toggle_node>, C<open_all>,
C<close_all>, C<save_opened>, C<reopen>

=item Modifying nodes

C<rename_node>, C<delete_node>, C<move_node>

=item Selecting nodes (from the 'ui' jstree plugin)

C<select_node>, C<deselect_node>, C<deselect_all>

=back

=head1 ADDING SUPPORT FOR ADDITIONAL FUNCTIONS

In order to not have to maintain two files (this one and
C<js/client_js.js>) there's a script that can parse this file's
C<%supported_methods> definition and generate the file
C<js/client_js.js> accordingly. The steps are:

=over 2

=item 1. Add lines in this file to the C<%supported_methods> hash. The
key is the function name and the value is the number of expected
parameters. The value can be negative to indicate that the function
takes at least the absolute of this value as parameters and optionally
more. In such a case the C<E<lt>ARGSE<gt>> format expands to an actual
array (and the individual elements if the value is positive>.

=item 2. Run C<scripts/generate_client_js_actions.pl>. It will
generate C<js/client_js.js> automatically.

=item 3. Reload the files in your browser (cleaning its cache can also
help).

=back

The template file used for generated C<js/client_js.js> is
C<scripts/generate_client_js_actions.tpl>.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
