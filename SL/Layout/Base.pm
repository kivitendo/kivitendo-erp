package SL::Layout::Base;

use strict;
use parent qw(Rose::Object);

use SL::Version;

use File::Slurp qw(read_file);
use List::MoreUtils qw(uniq);
use Time::HiRes qw();

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(menu auto_reload_resources_param sub_layouts_by_name) ],
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
use SL::System::Process;

my %menu_cache;

sub new {
  my ($class, @slurp) = @_;

  my $self = $class->SUPER::new(@slurp);
}

sub init_menu {
  SL::Menu->new('user');
}

sub init_sublayouts_by_name {
  {}
}

sub webpages_path {
  "templates/design40_webpages";
}

sub webpages_fallback_path {
}

sub html_dialect {
  'transitional'
}

sub allow_stylesheet_fallback {
  1
}

sub get {
  $_[0]->sub_layouts;
  return grep { $_ } ($_[0]->sub_layouts_by_name->{$_[1]});
}

sub _current_git_ref {
  my $git_dir = SL::System::Process::exe_dir() . '/.git';

  return unless -d $git_dir;

  my $content = eval { scalar(read_file($git_dir . '/HEAD')) };

  return unless ($content // '') =~ m{\Aref: ([^\r\n]+)};

  $content = eval { scalar(read_file($git_dir . '/' . $1)) };

  return unless ($content // '') =~ m{\A([0-9a-fA-F]+)};

  return $1;
}

sub init_auto_reload_resources_param {
  my $value;

  $value   = sprintf('%d-%d-%d', Time::HiRes::gettimeofday(), int(rand 1000000000000)) if $::lx_office_conf{debug}->{auto_reload_resources};
  $value ||= _current_git_ref();
  $value ||= SL::Version->get_version;

  return $value ? "?rand=${value}" : '';
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

sub init_sub_layouts_by_name { +{} }


#########################################
# Stylesheets
########################################

# override in sub layouts
sub static_stylesheets {}

sub add_stylesheets {
  &use_stylesheet;
}

sub use_stylesheet {
  my $self = shift;
  push @{ $self->{stylesheets} ||= [] }, @_ if @_;
    (map { $_->use_stylesheet } $self->sub_layouts), $self->static_stylesheets, @{ $self->{stylesheets} ||= [] };
}

sub stylesheets {
  my ($self) = @_;
  my $css_path = $self->get_stylesheet_for_user;

  return uniq grep { $_ } map { $self->_find_stylesheet($_, $css_path)  }
    $self->use_stylesheet;
}

sub _find_stylesheet {
  my ($self, $stylesheet, $css_path) = @_;

  return "$css_path/$stylesheet" if -f "$css_path/$stylesheet";
  return "css/$stylesheet"       if -f "css/$stylesheet" && $self->allow_stylesheet_fallback;
  return $stylesheet             if -f $stylesheet;
  return $stylesheet             if $stylesheet =~ /^http/; # external
}

sub get_stylesheet_for_user {
  my $css_path = 'css';
  if (my $user_style = $::myconfig{stylesheet}) {
    $user_style =~ s/\.css$//; # nuke trailing .css, this is a remnant of pre 2.7.0 stylesheet handling
    if (-d "$css_path/$user_style" &&
        -f "$css_path/$user_style/main.css") {
      $css_path = "$css_path/$user_style";
    } else {
      $css_path = "$css_path/kivitendo";
    }
  } else {
    $css_path = "$css_path/kivitendo";
  }

  return $css_path;
}

#########################################
# Javascripts
########################################

# override in sub layouts
sub static_javascripts {}

sub add_javascripts {
  &use_javascript
}

sub use_javascript {
  my $self = shift;
  push @{ $self->{javascripts} ||= [] }, @_ if @_;
  map({ $_->use_javascript } $self->sub_layouts), $self->static_javascripts, @{ $self->{javascripts} ||= [] };
}

sub javascripts {
  my ($self) = @_;

  return uniq grep { $_ } map { $self->_find_javascript($_)  }
     $self->use_javascript;
}

sub _find_javascript {
  my ($self, $javascript) = @_;

  return "js/$javascript"        if -f "js/$javascript";
  return $javascript             if -f $javascript;
  return $javascript             if $javascript =~ /^http/;
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

__END__

=encoding utf-8

=head1 NAME

SL::Layout::Base - Base class for layouts

=head1 SYNOPSIS

  package SL::Layout::MyLayout;

  use parent qw(SL::Layout::Base);

=head1 DESCRIPTION

For a description of the external interface of layouts in general see
L<SL::Layout::Dispatcher>.

This is a base class for layouts in general. It provides the basic interface
and some capabilities to extend and cascade layouts.


=head1 IMPLEMENTING LAYOUT CALLBACKS

There are eight callbacks (C<pre_content>, C<post_content>, C<start_content>,
C<end_content>, C<stylesheets>, C<stylesheets_inline>, C<javascripts>,
C<javascripts_inline>) which are documented in L<SL::Layout::Dispatcher>. If
you are writing a new simple layout, you can just override some of them like
this:

  package SL::Layout::MyEvilLayout;

  sub pre_content {
    '<h1>This is MY page now</h1>'
  }

  sub post_content {
    '<p align="right"><small><em>Brought to you by my own layout class</em></small></p>'
  }


To preserve the sanitizing effects of C<stylesheets> and C<javascripts> you should instead do the following:

  sub stylesheets {
    $_[0]->add_stylesheets(qw(mystyle1.css mystyle2.css);
    $_[0]->SUPER::stylesheets;
  }

If you want to add something to a different layout, you should write a sub
layout and add it to the other layouts.


=head1 SUB LAYOUTS

Layouts can be aggregated, so that common elements can be used in different
layouts. Currently this is used for the L<None|SL::Layout::None> sub layout,
which contains a lot of the stylesheets and javascripts necessary. Another
example is the L<Top|SL::Layout::Top> layout, which is used to generate a
common top bar for all menu types.

To add a sub layout to your layout just overwrite the sub_layout method:

  package SL::Layout::MyFinalLayout;

  sub init_sub_layout {
    [
      SL::Layout::None->new,
      SL::Layout::MyEvilLayout->new,
    ]
  }

You can also add a sublayout at runtime:

  $layout->add_sub_layout(SL::Layout::SideBar->new);

The standard implementation for the callbacks will see to it that the contents
of all sub layouts will get rendered.


=head1 COMBINING SUB LAYOUTS AND OWN BEHAVIOUR

This is still somewhat rough, and improvements are welcome.

For the C<*_content> callbacks this works if you just remember to dispatch to the base method:

  sub post_content {
    return $_[0]->render_status_bar .
    $_[0]->SUPER::post_content
  }


Stylesheets and Javascripts can be added to every layout and sub-layout at
runtime with L<SL::Layout::Dispatcher/add_stylesheets> and
L<SL::Layout::Dispatcher/add_javascripts> (C<use_stylesheets> and
C<use_javascripts> are aliases for backwards compatibility):

  $layout->add_stylesheets("custom.css");
  $layout->add_javascripts("app.js", "widget.js");

Or they can be overwritten in sub layouts with the calls
L<SL::Layout::Displatcher/static_stylesheets> and
L<SL::Layout::Dispatcher/static_javascripts>:

  sub static_stylesheets {
    "custom.css"
  }

  sub static_javascripts {
    qw(app.css widget.js)
  }

Note how these are relative to the base dirs of the currently selected
stylesheets. Javascripts are resolved relative to the C<js/> basedir.

Setting directly with C<stylesheets> and C<javascripts> is eprecated.


=head1 BEHAVIOUR SWITCHES FOR SUB LAYOUTS

Certain methods have been added to adjust behaviour in sub layouts. Most of these are single case uses.

=over 4

=item * sublayouts_by_name

Contains a map that holds named sublayouts. If a sublayout needs to targeted
directly, the compositing layout needs to add it here. Initially introduced for
the ActionPlan.

=item * webpages_path

Overrides the default webpages path "templates/design40_webpages". Used
for mobile and design40 styles.

Note that this does not have fallback behaviour by default. It is intended for
stylesheets where the templates are so incompatible that a complete fork of the
templates dir is sensible.

=item * webpages_fallback_path

Allows partial template sets to fallback to other paths in case a template
wasn't found. Intended to be used in conjunction with L</webpages_path>.

Note: in case a template can't be found at all, generic/error.html will be
rendered, and the fallback doesn't work in this case.


=item * allow_stylesheet_fallback

Defaults to true. The default behaviour is that stylesheets not found in the
stylesheet path of the user will fallback to files found in css/. This is
usually desirable for shared stuff like common.css, which contains behaviour
styling. If a stylesheet comes from a separate generator, this can be used to
turn falllback off. Files can still be included with the complete path though.
A request for "common.css" would not find "css/common.css", but a request for
"css/common.css" would be found.

Also see the next section L</GORY DETAILS ABOUT JAVASCRIPT AND STYLESHEET OVERLOADING>

=item * html_dialect

Default 'transitional'. Controls the html dialect that the header will
generate. Used in combination with template overriding for html5.

See also L<SL::Form/header>

=back



=head1 GORY DETAILS ABOUT JAVASCRIPT AND STYLESHEET OVERLOADING

The original code used to store one stylesheet in C<< $form->{stylesheet} >> and
allowed/expected authors of potential C<bin/mozilla/> controllers to change
that into their own modified stylesheet.

This was at some point cleaned up into a method C<use stylesheet> which took a
string of space separated stylesheets and processed them into the response.

A lot of controllers are still using this method so the layout interface
supports it to change as little controller code as possible, while providing the
more intuitive C<add_stylesheets> method.

At the same time the following things need to be possible:

=over 4

=item 1.

Runtime additions.

  $layout->add_stylesheets(...)

Since add_stylesheets adds to C<< $self->{stylesheets} >> there must be a way to read
from it. Currently this is the deprecated C<use_stylesheet>.

=item 2.

Overriding Callbacks

A leaf layout should be able to override a callback to return a list.

=item 3.

Sanitizing

C<stylesheets> needs to retain its sanitizing behaviour.

=item 4.

Aggregation

The standard implementation should be able to collect from sub layouts.

=item 5.

Preserving Inclusion Order

Since there is currently no standard way of mixing own content and including
sub layouts, this has to be done manually. Certain things like jquery get added
in L<SL::Layout::None> so that they get rendered first.

=back

The current implementation provides no good candidate for overriding in sub
classes, which should be changed. The other points work pretty well.

=head1 BUGS

* stylesheet/javascript interface is a horrible mess.

* It's currently not possible to do compositor layouts without assupmtions
about the position of the content. That's because the content will return
control to the actual controller, so the layouts need to know where to split
pre- and post-content.

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
