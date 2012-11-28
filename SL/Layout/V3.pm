package SL::Layout::V3;

use strict;
use parent qw(SL::Layout::Base);
use SL::Layout::Css;

use URI;

sub init_sub_layouts {
  [ SL::Layout::None->new ]
}

sub use_stylesheet {
  my $self = shift;
  qw(
    frame_header/header.css
  ),
  $self->SUPER::use_stylesheet(@_);
}

sub pre_content {
  &render;
}

sub start_content {
  "<div id='content'>\n";
}

sub end_content {
  "</div>\n";
}

sub render {
  my ($self) = @_;

  my $callback            = $::form->unescape($::form->{callback});
  $callback               = URI->new($callback)->rel($callback) if $callback;
  $callback               = "login.pl?action=company_logo"      if $callback =~ /^(\.\/)?$/;

  $self->SUPER::render('menu/menuv3', { no_menu => 1, no_output => 1 },
    force_ul_width => 1,
    date           => $self->clock_line,
    menu           => $self->print_menu,
    callback       => $callback,
  );
}

1;
