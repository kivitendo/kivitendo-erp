package SL::Layout::Dispatcher;

use strict;

use SL::Layout::Admin;
use SL::Layout::AdminLogin;
use SL::Layout::Login;
use SL::Layout::Classic;
use SL::Layout::V3;
use SL::Layout::Javascript;
use SL::Layout::Material;
use SL::Layout::MobileLogin;

sub new {
  my ($class, %params) = @_;

  return SL::Layout::Classic->new    if $params{style} eq 'old';
  return SL::Layout::V3->new         if $params{style} eq 'v3';
  return SL::Layout::Javascript->new if $params{style} eq 'neu';
  return SL::Layout::Admin->new      if $params{style} eq 'admin';
  return SL::Layout::AdminLogin->new if $params{style} eq 'admin_login';
  return SL::Layout::Login->new      if $params{style} eq 'login';
  return SL::Layout::Material->new   if $params{style} eq 'mobile';
  return SL::Layout::MobileLogin->new if $params{style} eq 'mobile_login';
  return SL::Layout::None->new;
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Layout::Dispatcher - provides layouts by name.

=head1 SYNOPSIS

  use SL::Layout::Dispatcher;
  $::request->layout(SL::Layout::Dispatcher->new(style => 'login'));

  # same as

  use SL::Layout::Login;
  $::request->layout(SL::Layout::Login->new);

=head1 INTRODUCTION

A layout in kivitendo is anything that should be included into a text/html
response without having each controller do it manually. This includes:

=over 4

=item *

menus

=item *

status bars

=item

div containers for error handling and ajax responses

=item *

javascript and css includes

=item *

html header and body

=back

It does not include:

=over 4

=item *

http headers

=item *

anthing that is not a text/html response

=back

All of these tasks are handled by a layout object, which is stored in the
global L<$::request|SL::Request> object. An appropriate layout object will be
chosen during the login/session_restore process.


=head1 INTERFACE

Every layout must be instantiated from L<SL::Layout::Base> and must implement
the following eight callbacks:

=over 4

=item C<pre_content>

Content that must, for whatever reason, appear before the main content.

=item C<start_content>

An introcutory clause for the main content. Usually something like C<< <div
class='content'> >>.

=item C<end_content>

The corresponding end of L</start_content> like C<< </div> >>

=item C<post_content>

Any extra content that should appear after the main content in the response
source. Note that it is preferred to put extra content after the main content,
so that it gets rendered faster.

=item C<stylesheets>

A list of stylesheets that should be included as a full relative web path. Will
be rendered into the html header.

=item C<stylesheets_inline>

A list of stylesheet snippets that need to be included in the response. Will be
added to the html header.

=item C<javascripts>

A list of javascripts that should be included as a full relative web path.

Note:
There is no guarantee where these will end up in the content. Currently they
will be rendered into the header, but are likely to be moved into the footer in
the future.

=item C<javascripts_inline>

A list of javascript snippets that need to be included in the response.

Note:
These will end up in the footer, so make sure they don't contain
initializations to static javascript includes that may be included earlier.

=back

=head1 RUNTIME INTERFACE

Each layout object can add stylesheets and javascripts at runtime, as long as
its before the actual rendering has begun. This can be used to add special
javascripts only your controller needs.

=over 4

=item C<add_stylesheets>

Adds the list of arguments to the list of used stylesheets.

These will first be searched in the theme folder for the current user, and only
after that be searched from the common C<css/> folder.

Duplicated files will be only included once.

Non-existing files will be pruned from the list.

=item C<use_stylesheet>

Backwards compatible alias for C<add_stylesheets>. Deprecated.

=item C<static_stylesheets>

Can be overwritten in sub-layouts to return a list of needed stylesheets. The
values will be resolved by the actual layout in addition to the
C<add_stylesheets> accumulator.

=item C<add_javascripts>

Adds the list of arguments to the list of used javascripts.

Duplicated files will be only included once.

Non-existing files will be pruned from the list.

=item C<use_javascript>

Backwards compatible alias for C<add_javascripts>. Deprecated.


=item C<static_javascripts>

Can be overwritten in sub-layouts to return a list of needed javascripts. The
values will be resolved by the actual layout in addition to the
C<add_javascripts> accumulator.

=item C<add_javascripts_inline>

Add a snippet of javascript.

=item C<add_stylesheets_inline>

Add a snippet of css.

=item C<focus>

If set with a selector, the layout will generate javascript to set the page
focus to that selector on document.ready.

=back

=head1 BUGS

None yet :)

=head1 TODO

non existing css or js includes should generate a log entry.

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
