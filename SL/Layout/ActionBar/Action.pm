package SL::Layout::ActionBar::Action;

use strict;
use parent qw(Rose::Object);

use SL::Presenter::Tag qw(name_to_id);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(id params text) ],
);

# subclassing interface

sub render {
  die 'needs to be implemented';
}

sub script {
  sprintf q|$('#%s').data('action', %s);|, $_[0]->id, JSON->new->allow_blessed->convert_blessed->encode($_[0]->params);
}

# this is mostly so that outside consumer don't need to load subclasses themselves
sub from_params {
  my ($class, $data) = @_;

  require SL::Layout::ActionBar::Submit;

  my ($text, %params) = @$data;
  return if exists($params{only_if}) && !$params{only_if};
  return if exists($params{not_if})  &&  $params{not_if};
  return SL::Layout::ActionBar::Submit->new(text => $text, params => \%params);
}

sub callable { 0 }

# shortcut for presenter

sub init_params {
  +{}
}

# unique id to tie div and javascript together
sub init_id {
  $_[0]->params->{id} // name_to_id('action[]')
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Layout::ActionBar::Action - base class for action bar actions

=head1 DESCRIPTION

This base class for actions can be used to implement elements that can be
added to L<SL::Layout::ActionBar>.

Elements can be interactive or simply used for layout. Most of the actual
semantics are handled in the corresponding javascript C<js/kivi.ActionBar.js>, so
this is only used to generate the DOM elements and to provide information for
request time logic decisions.


=head1 SYNOPSIS

  # implement:
  package SL::Layout::ActionBar::Custom;
  use parent qw(SL::Layout::ActionBar::Action);

  # unsugared use
  SL::Layout::ActionBar::Custom->new(
    text   => t8('Description'),
    params => {
      key => $attr,
      key => $attr,
      ...
    },
  );

  # parse sugared version:
  SL::Layout::ActionBar::Custom->from_params(
    t8('Description'),
    key => $attr,
    key => $attr,
    ...
  );

=head1 INTERFACE

=over 4

=item * C<render>

Needs to be implemented. Should render only the bare minimum necessary to
identify the element at run time.

=item * C<script>

Will be called during layout rendering. Defaults to dumping the params section
into data field of the rendered DOM element.

=item * C<from_params>

Parse sugared version. Defaults for historic reasons to the implementation of
L<SL::Layout::ActionBar::Submit>, all others must implement their own.

=item * C<callable>

Used to determine whether an instance is callable or only a layout element.

=back

=head1 METHODS

=over 4

=item * C<p>

Returns the current request presenter.

=item * C<id>

Will get initialized to either the provided id from the params or to a
generated unique id. Should be used to tie the rendered DOM and script
together.

=back

=head1 RECOGNIZED PARAMETERS

=over 4

=item * C<< submit => [ $selector, \%params ] >>

On click, submit the form found with the first parameter. If params is present
and a hashref, the key value elements will be added to the form before
submitting. Beware that this will destroy the form if the user uses the browser
history to jump back to this page, so ony use parametrized submits for post
submits that redirect on completion.

=item * C<< link => $url >>

On click, will load the given url.

=item * C<< call => [ $function_name, @args ] >>

On click, will call the function name with the argument array. The return will
be discarded. It is assumed that the fucntion will trigger an asynchronous
action.

Contrast with C<checks>.

=item * C<< checks => \@function_names >>

Before any of C<submit>, C<link>, or C<call> are evaluated all
functions in C<check> are called. Only if all of them return a true value the
action will be triggered.

Checks are expected not to trigger asynchronous actions (contrast with C<call>),
but may change the DOM to indicate to the user why they fail.

Each must return a boolean value.

=item * C<< confirm => t8('Yes/No Question') >>

Before any of C<submit>, C<link>, or C<call> are evaluated, the user
will be asked to confirm. If checks are present and failed, confirm will not be
triggered.

=item * C<< only_if => $bool >>

Pseudo parameter. If present and false, the element will not be rendered.

=item * C<< not_if => $bool >>

Pseudo parameter. If present and true, the element will not be rendered.

=item * C<< only_once => 1 >>

If present, a click will C<disable> the action to prevent multiple activations.

=item * C<< accesskey => $text >>

Registers an accesskey for this element. While the most common accesskey is
'enter', in theory every other should work as well. Modifier keys can be added
to the accesskey string with 'ctrl+', 'alt+', or 'shift+'. 'shift+' is not
necessary for upper case letters.

=item * C<< disabled => t8('tooltip') >>

Renders the element disabled, ignores all actions (C<submit>, C<call>, C<link>)
and adds the given tooltip hopefully explaining why the element is disabled.

=item * C<< id => $id >>

Sets the DOM id of the rendered element. If missing, the element will get a
random id.

=item * C<< tooltip => t8('tooltip') >>

Sets a tooltip for the element.

=back

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
