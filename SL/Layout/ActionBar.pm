package SL::Layout::ActionBar;

use strict;
use parent qw(SL::Layout::Base);

use SL::Layout::ActionBar::Action;

use constant HTML_CLASS => 'layout-actionbar';

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(actions) ],
);


###### Layout overrides

sub pre_content {
  my ($self) = @_;

  my $content = join '', map { $_->render } @{ $self->actions };
  return if !$content;
  $::request->presenter->html_tag('div', $content, class => HTML_CLASS);
}

sub javascripts_inline {
  join '', map { $_->script } @{ $_[0]->actions };
}

sub javascripts {
  'kivi.ActionBar.js'
}

###### interface

sub add_actions {
  my ($self, @actions) = @_;
  push @{ $self->actions }, map {
       !ref $_ ? SL::Layout::ActionBar::Action->from_descriptor($_)
     :  ref $_ && 'ARRAY' eq ref $_ ? SL::Layout::ActionBar::Action->simple($_)
     :  ref $_ && $_->isa('SL::Layout::Action') ? $_
     : do { die 'invalid action' };
  } @actions;
}

sub init_actions {
  []
}




1;

__END__

=encoding utf-8

=head1 NAME

SL::Layout::ActionBar - Unified action buttons for controllers

=head1 CONCEPT

This is a layout block that does a unified action bar for any controller who
wants to use it. It's designed to be rendered above the content and to be
fixed when scrolling.

While it can be used as a generic widget container, it's designed to be able to
provide commonly used functionality as a short cut. These shortcuts include:

=over 4

=item *

Calling a controller with parameters

=item *

Submitting a form with added parameters

=item *

Arrangement utility

=back


=head1 METHODS

=over 4

=item C<add_actions LIST>

Dispatches each each argument to C<add_action>

=item C<add_action>


=item C<add_separator>

=item C<add_

=head1 ACCESS FROM CODE

This is accessable through

  $::request->layout->get('actionbar')

=head1 DOM MODEL

The entire block is rendered into a div with the class 'layout-actionbar'.

=head1 ACTION WIDGETS

Each individual action must be an instance of C<SL::Layout::ActionBar::Action>.

=head1 BUGS

none yet. :)

=head1 AUTHOR

Sven Schoeling E<lt>s.schoeling@linet-services.deE<gt>

=cut
