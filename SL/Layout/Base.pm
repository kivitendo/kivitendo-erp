package SL::Layout::Base;

use strict;
use parent qw(Rose::Object);

use List::MoreUtils qw(uniq);
use Time::HiRes qw();

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(menu auto_reload_resources_param) ],
  'scalar'                => qw(focus),
  'array'                 => [
    'add_stylesheets_inline' => { interface => 'add', hash_key => 'stylesheets_inline' },
    'add_javascripts_inline' => { interface => 'add', hash_key => 'javascripts_inline' },
    'sub_layouts',           => { interface => 'get_set_init' },
    'add_sub_layouts'        => { interface => 'add', hash_key => 'sub_layouts' },
  ],
);

use SL::Menu;
use SL::Presenter;

my %menu_cache;

sub new {
  my ($class, @slurp) = @_;

  my $self = $class->SUPER::new(@slurp);
}

sub init_menu {
  Menu->new('menu.ini');
}

sub init_auto_reload_resources_param {
  return '' unless $::lx_office_conf{debug}->{auto_reload_resources};
  return sprintf('?rand=%d-%d-%d', Time::HiRes::gettimeofday(), int(rand 1000000000000));
}

##########################################
#  inheritable/overridable
##########################################

sub pre_content {
  join '', map { $_->pre_content } $_[0]->sub_layouts;
}

sub start_content {
  join '', map { $_->start_content } $_[0]->sub_layouts;
}

sub end_content {
  join '', map { $_->end_content } $_[0]->sub_layouts;
}

sub post_content {
  join '', map { $_->post_content } $_[0]->sub_layouts;
}

sub stylesheets_inline {
  uniq ( map { $_->stylesheets_inline } $_[0]->sub_layouts ),
  @{ $_[0]->{stylesheets_inline} || [] };
}

sub javascripts_inline {
  uniq ( map { $_->javascripts_inline } $_[0]->sub_layouts ),
  @{ $_[0]->{javascripts_inline} || [] };
}

sub init_sub_layouts { [] }


#########################################
# Interface
########################################

sub add_stylesheets {
  &use_stylesheet;
}

sub use_stylesheet {
  my $self = shift;
  push @{ $self->{stylesheets} ||= [] }, @_ if @_;
  @{ $self->{stylesheets} ||= [] };
}

sub stylesheets {
  my ($self) = @_;
  my $css_path = $self->get_stylesheet_for_user;

  return uniq grep { $_ } map { $self->_find_stylesheet($_, $css_path)  }
    $self->use_stylesheet, map { $_->stylesheets } $self->sub_layouts;
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
      $css_path = "$css_path/kivitendo";
    }
  } else {
    $css_path = "$css_path/kivitendo";
  }
  $::myconfig{css_path} = $css_path; # needed for menunew, FIXME: don't do this here

  return $css_path;
}

sub add_javascripts {
  &use_javascript
}

sub use_javascript {
  my $self = shift;
  push @{ $self->{javascripts} ||= [] }, @_ if @_;
  @{ $self->{javascripts} ||= [] };
}

sub javascripts {
  my ($self) = @_;

  return uniq grep { $_ } map { $self->_find_javascript($_)  }
    map({ $_->javascripts } $self->sub_layouts), $self->use_javascript;
}

sub _find_javascript {
  my ($self, $javascript) = @_;

  return "js/$javascript"        if -f "js/$javascript";
  return $javascript             if -f $javascript;
}


############################################
# track state of form header
############################################

sub header_done {
  $_[0]{_header_done} = 1;
}

sub need_footer {
  $_[0]{_header_done};
}

sub presenter {
  SL::Presenter->get;
}

1;
