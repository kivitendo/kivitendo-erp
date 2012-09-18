package SL::Controller::Layout::V3;

use strict;
use parent qw(SL::Controller::Layout::Base);
use SL::Controller::Layout::Css;

use URI;

sub new {
  my ($class, @slurp) = @_;

  my $self = $class->SUPER::new(@slurp);

  $self->add_sub_layouts([
    SL::Controller::Layout::None->new,
  ]);

  $self;
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
