package SL::Controller::Layout::Base;

use strict;
use parent qw(SL::Controller::Base);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => qw(menu),
);

use SL::Menu;

my %menu_cache;

sub new {
  my ($class, @slurp) = @_;

  my $self = $class->SUPER::new(@slurp);
}

sub init_menu {
  Menu->new('menu.ini');
}

##########################################
#  inheritable/overridable
##########################################

sub pre_content {
}

sub start_content {
}

sub end_content {
}

sub post_content {
}

sub stylesheets_inline {
}

sub javascript_inline {
}

#########################################
# Interface
########################################

sub use_stylesheet {
  my $self = shift;
  push @{ $self->{stylesheets} ||= [] }, @_ if @_;
  @{ $self->{stylesheets} ||= [] };
}

sub stylesheets {
  my ($self) = @_;
  my $css_path = $self->get_stylesheet_for_user;

  return grep { $_ } map { $self->_find_stylesheet($_, $css_path)  } $self->use_stylesheet;
}

sub _find_stylesheet {
  my ($self, $stylesheet, $css_path) = @_;

  return "$css_path/$stylesheet" if -f "$css_path/$stylesheet";
  return "css/$stylesheet"       if -f "css/$stylesheet";
  return $stylesheet             if -f $stylesheet;
}

sub get_stylesheet_for_user {
  my $css_path = 'css';
  if (my $user_style = $::myconfig{stylesheet}) {
    $user_style =~ s/\.css$//; # nuke trailing .css, this is a remnand of pre 2.7.0 stylesheet handling
    if (-d "$css_path/$user_style" &&
        -f "$css_path/$user_style/main.css") {
      $css_path = "$css_path/$user_style";
    } else {
      $css_path = "$css_path/lx-office-erp";
    }
  } else {
    $css_path = "$css_path/lx-office-erp";
  }
  $::myconfig{css_path} = $css_path; # needed for menunew, FIXME: don't do this here

  return $css_path;
}


sub use_javascript {
  my $self = shift;
  $::lxdebug->dump(0,  "class", \@_);
  push @{ $self->{javascripts} ||= [] }, @_ if @_;
  @{ $self->{javascripts} ||= [] };
}

sub javascripts {
  my ($self) = @_;

  $::lxdebug->dump(0,  "called", [ map { $self->find_javascript($_)  } $self->use_javascript ]);
  return map { $self->_find_javascript($_)  } $self->use_javascript;
}

sub _find_javascript {
  my ($self, $javascript) = @_;

  return "js/$javascript"        if -f "js/$javascript";
  return $javascript             if -f $javascript;
}

1;
