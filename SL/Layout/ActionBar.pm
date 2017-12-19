package SL::Layout::ActionBar;

use strict;
use parent qw(SL::Layout::Base);

use Carp;
use Scalar::Util qw(blessed);
use SL::Layout::ActionBar::Action;
use SL::Layout::ActionBar::ComboBox;
use SL::Layout::ActionBar::Link;
use SL::Layout::ActionBar::Separator;

use SL::Presenter::Tag qw(html_tag);

use constant HTML_CLASS => 'layout-actionbar';

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(actions) ],
);

my %class_descriptors = (
  action    => { class => 'SL::Layout::ActionBar::Action',    num_params => 1, },
  combobox  => { class => 'SL::Layout::ActionBar::ComboBox',  num_params => 1, },
  link      => { class => 'SL::Layout::ActionBar::Link',      num_params => 1, },
  separator => { class => 'SL::Layout::ActionBar::Separator', num_params => 0, },
);

###### Layout overrides

sub pre_content {
  my ($self) = @_;

  my $content = join '', map { $_->render } @{ $self->actions };
  return if !$content;
  html_tag('div', $content, class => HTML_CLASS);
}

sub javascripts_inline {
  join '', map { $_->script } @{ $_[0]->actions };
}

sub javascripts {
  'kivi.ActionBar.js'
}

###### interface

sub add {
  my ($self, @actions) = @_;

  push @{ $self->actions }, $self->parse_actions(@actions);

  return $self->actions->[-1];
}

sub parse_actions {
  my ($self_or_class, @actions) = @_;

  my @parsed;

  while (my $type = shift(@actions)) {
    if (blessed($type) && $type->isa('SL::Layout::ActionBar::Action')) {
      push @parsed, $type;
      next;
    }

    my $descriptor = $class_descriptors{lc $type} || croak("Unknown action type '${type}'");
    my @params     = splice(@actions, 0, $descriptor->{num_params});

    push @parsed, $descriptor->{class}->from_params(@params);
  }

  return @parsed;
}

sub init_actions {
  []
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Layout::ActionBar - Unified action buttons for controllers

=head1 SYNOPSIS

  # short sugared syntax:
  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Description'),
        call      => [ 'kivi.Javascript.function', @arguments ],
        accesskey => 'enter',
        disabled  => $tooltip_with_reason_or_falsish,
        only_if   => $precomputed_condition,
        not_if    => $precomputed_condition,
        id        => 'html-element-id',
      ],
      combobox => [
        action => [...],
        action => [...],
        action => [...],
        action => [...],
      ],
      link => [
        t8('Description'),
        link => $url,
      ],
      'separator',
    );
  }

  # full syntax without sugar
  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      (SL::Layout::ActionBar::Action->new(
        text => t8('Description'),
        params => {
          call      => [ 'kivi.Javascript.function', @arguments ],
          accesskey => 'enter',
          disabled  => $tooltip_with_reason_or_falsish,
        },
      )) x(!!$only_id && !$not_if),
      SL::Layout::ActionBar::ComboBox->new(
        actions => [
          SL::Layout::ActionBar::Action->new(...),
          SL::Layout::ActionBar::Action->new(...),
          SL::Layout::ActionBar::Action->new(...),
          SL::Layout::ActionBar::Action->new(...),
        ],
      ),
      SL::Layout::ActionBar::Link->new(
        text => t8('Description'),
        params => {
          link => $url,
        },
      ),
      SL::Layout::ActionBar::Separator->new,
    );
  }

=head1 CONCEPT

This is a layout block that creates an action bar for any controller who
wants to use it. It's designed to be rendered above the content and to be
fixed when scrolling. It's structured as a container for elements that can be
extended when needed.

=head1 METHODS

=over 4

=item * C<new>

Will be used during initialization of the layout. You should never have to
instanciate an action bar yourself. Get the current request instances from

  $::request->layout->get('actionbar')

instead.

=item * C<add>

Add new elements to the bar. Can be instances of
L<SL::Layout::ActionBar::Action> or scalar strings matching the sugar syntax
which is described further down.

=back

=head1 SYNTACTIC SUGAR

Instead of passing full objects to L</add>, you can instead pass the arguments
to be used for instantiation to make the code easier to read. The short syntax
looks like this:

  type => [
    localized_description,
    param => value,
    param => value,
    ...
  ]

A string type, followed by the parameters needed for that type. Type may be one of:

=over 4

=item * C<action>

=item * C<combobox>

=item * C<link>

=item * C<separator>

=back

C<separator> will use no parameters, the other three will expect one arrayref.

Two additional pseudo parameters are supported for those:

=over 4

=item * C<only_if>

=item * C<not_if>

=back

These are meant to reduce enterprise operators (C<()x!!>) when conditionally adding lots
of elements.

The combobox element is in itself a container and will simply expect the same
syntax in an arrayref.

For the full list of parameters supported by the elements, see L<SL::Layout::ActionBar::Action/RECOGNIZED PARAMETERS>.


=head1 GUIDELINES

The current implementation follows these design guidelines:

=over 4

=item *

Don't put too many elements into the action bar. Group into comboboxes if
possible. Consider seven elements a reasonable limit.

=item *

If you've got an update button, put it first and bind the enter accesskey to
it.

=item *

Put mutating actions (save, post, delete, check out, ship) before the separator
and non mutating actions (export, search, history, workflow) after the
separator. Combined actions (save and close) still mutate and go before the
separator.

=item *

Avoid abusing the actionbar as a secondary menu. As a principle every action
should act upon the current element or topic.

=item *

Hide elements with C<only_if> if they are known to be useless for the current
topic, but disable when they would be useful in principle but are not
applicable right now. For example C<delete> does not make sense in a creating
form, but makes still sense because the element can be deleted later. This
keeps the actionbar stable and reduces surprising elements that only appear in
rare situations.

=item *

Always add a tooltip when disabling an action.

=item *

Try to always add a default action with accesskey enter. Since the actionbar
lies outside of the main form, the usual submit on enter does not work out of
the box.

=back

=head1 DOM MODEL AND IMPLEMENTATION DETAILS

The entire block is rendered into a div with the class 'layout-actionbar'. Each
action will render itself and will get added to the div. To keep the DOM small
and reduce startup overhead, the presentation is pure CSS and only the sticky
expansion of comboboxes is done with javascript.

To keep startup times and HTML parsing fast the action data is simply written
into the data elements of the actions and handlers are added in a ready hook.

=head1 BUGS

none yet. :)

=head1 SEE ALSO

L<SL::Layout::ActioBar::Base>,
L<SL::Layout::ActioBar::Action>,
L<SL::Layout::ActioBar::Submit>,
L<SL::Layout::ActioBar::ComboBox>,
L<SL::Layout::ActioBar::Separator>,
L<SL::Layout::ActioBar::Link>,

=head1 AUTHOR

Sven Schoeling E<lt>s.schoeling@linet-services.deE<gt>

=cut
