package SL::Layout::Top;

use strict;
use parent qw(SL::Layout::Base);

use SL::Controller::TopQuickSearch;

sub pre_content {
  my ($self) = @_;

  my @options;
  # Only enable the quick search functionality if all database
  # upgrades have already been applied as quick search requires
  # certain columns that are only created by said database upgrades.
  push @options, (quick_search => SL::Controller::TopQuickSearch->new) unless $::request->applying_database_upgrades;

  $self->presenter->render('menu/header',
    now        => DateTime->now_local,
    is_fastcgi => $::dispatcher ? scalar($::dispatcher->interface_type =~ /fastcgi/i) : 0,
    is_links   => scalar($ENV{HTTP_USER_AGENT}         =~ /links/i),
    @options,
  );
}

sub static_stylesheets {
 'frame_header/header.css';
}

sub static_javascripts {
  'jquery-ui.js',
  'kivi.QuickSearch.js',
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
