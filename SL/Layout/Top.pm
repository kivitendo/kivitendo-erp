package SL::Layout::Top;

use strict;
use parent qw(SL::Layout::Base);

sub pre_content {
  my ($self) = @_;

  $self->presenter->render('menu/header',
    now        => DateTime->now_local,
    is_fastcgi => $::dispatcher ? scalar($::dispatcher->interface_type =~ /fastcgi/i) : 0,
    is_links   => scalar($ENV{HTTP_USER_AGENT}         =~ /links/i),
  );
}

sub stylesheets {
 'frame_header/header.css';
}

sub javascripts {
  ('jquery-ui.js', 'quicksearch_input.js') x!! $::auth->assert('customer_vendor_edit|part_service_assembly_edit', 1),
  ('jquery-ui.js', 'glquicksearch.js')     x!! $::auth->assert('general_ledger', 1)
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Layout::Top - Top line in classic and v3 menu.

=head1 DOM MODEL

The entire top line is rendered into a div with id C<frame-header>. The following classes are used:

  frame-header-element: any continuous block of entries
  frame-header-left:    the left floating part
  frame-header-right:   the right floating part
  frame-header-center:  the centered part

=head1 BUGS

none yet. :)

=head1 AUTHOR

Sven Schoeling E<lt>s.schoeling@linet-services.deE<gt>

=cut
