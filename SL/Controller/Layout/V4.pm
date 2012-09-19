package SL::Controller::Layout::V4;

use strict;
use parent qw(SL::Controller::Layout::Base);
use SL::Controller::Layout::Css;
use SL::Controller::Layout::Top;

use URI;

sub new {
  my ($class, @slurp) = @_;

  my $self = $class->SUPER::new(@slurp);
  $self->add_sub_layouts(
    SL::Controller::Layout::Top->new,
    SL::Controller::Layout::None->new,
  );
  $self;
}

sub start_content {
  "<div id='content'>\n";
}

sub end_content {
  "</div>\n";
}

sub pre_content {
  my ($self) = @_;

  $self->{sub_class} = 1;

  my $callback            = $::form->unescape($::form->{callback});
  $callback               = URI->new($callback)->rel($callback) if $callback;
  $callback               = "login.pl?action=company_logo"      if $callback =~ /^(\.\/)?$/;

  $self->SUPER::pre_content .

  $self->SUPER::render('menu/menuv4', { no_menu => 1, no_output => 1 },
    force_ul_width => 1,
    date           => $self->clock_line,
    menu           => $self->print_menu,
    callback       => $callback,
  );
}

1;
