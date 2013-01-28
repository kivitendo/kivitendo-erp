package SL::Template::Plugin::L;

use base qw( Template::Plugin );
use Template::Plugin;
use List::MoreUtils qw(apply);
use List::Util qw(max);
use Scalar::Util qw(blessed);

use SL::Presenter;

use strict;

{ # This will give you an id for identifying html tags and such.
  # It's guaranteed to be unique unless you exceed 10 mio calls per request.
  # Do not use these id's to store information across requests.
my $_id_sequence = int rand 1e7;
sub _tag_id {
  return "id_" . ( $_id_sequence = ($_id_sequence + 1) % 1e7 );
}
}

my %_valueless_attributes = map { $_ => 1 } qw(
  checked compact declare defer disabled ismap multiple noresize noshade nowrap
  readonly selected
);

sub _H {
  my $string = shift;
  return $::locale->quote_special_chars('HTML', $string);
}

sub _J {
  my $string = shift;
  $string    =~ s/(\"|\'|\\)/\\$1/g;
  return $string;
}

sub _hashify {
  return (@_ && (ref($_[0]) eq 'HASH')) ? %{ $_[0] } : @_;
}

sub new {
  my ($class, $context, @args) = @_;

  return bless {
    CONTEXT => $context,
  }, $class;
}

sub _context {
  die 'not an accessor' if @_ > 1;
  return $_[0]->{CONTEXT};
}

sub name_to_id {
  my $self =  shift;
  my $name =  shift;

  $name    =~ s/[^\w_]/_/g;
  $name    =~ s/_+/_/g;

  return $name;
}

sub attributes {
  my ($self, @slurp)    = @_;
  my %options = _hashify(@slurp);

  my @result = ();
  while (my ($name, $value) = each %options) {
    next unless $name;
    next if $_valueless_attributes{$name} && !$value;
    $value = '' if !defined($value);
    push @result, $_valueless_attributes{$name} ? _H($name) : _H($name) . '="' . _H($value) . '"';
  }

  return @result ? ' ' . join(' ', @result) : '';
}

sub html_tag {
  my ($self, $tag, $content, @slurp) = @_;
  my $attributes = $self->attributes(@slurp);

  return "<${tag}${attributes}>" unless defined($content);
  return "<${tag}${attributes}>${content}</${tag}>";
}

sub img_tag {
  my ($self, @slurp) = @_;
  my %options = _hashify(@slurp);

  $options{alt} ||= '';

  return $self->html_tag('img', undef, %options);
}

sub select_tag {
  my $self            = shift;
  my $name            = shift;
  my $collection      = shift;
  my %attributes      = _hashify(@_);

  $attributes{id}   ||= $self->name_to_id($name);

  my $value_key       = delete($attributes{value_key}) || 'id';
  my $title_key       = delete($attributes{title_key}) || $value_key;
  my $default_key     = delete($attributes{default_key}) || 'selected';


  my $value_title_sub = delete($attributes{value_title_sub});

  my $value_sub       = delete($attributes{value_sub});
  my $title_sub       = delete($attributes{title_sub});
  my $default_sub     = delete($attributes{default_sub});

  my $with_empty      = delete($attributes{with_empty});
  my $empty_title     = delete($attributes{empty_title});

  my %selected;

  if ( ref($attributes{default}) eq 'ARRAY' ) {

    foreach my $entry (@{$attributes{default}}) {
      $selected{$entry} = 1;
    }
  } elsif ( defined($attributes{default}) ) {
    $selected{$attributes{default}} = 1;
  }

  delete($attributes{default});


  my @options;

  if ( $with_empty ) {
    push(@options, [undef, $empty_title || '']);
  }

  my $normalize_entry = sub {

    my ($type, $entry, $sub, $key) = @_;

    if ( $sub ) {
      return $sub->($entry);
    }

    my $ref = ref($entry);

    if ( !$ref ) {

      if ( $type eq 'value' || $type eq 'title' ) {
        return $entry;
      }

      return 0;
    }

    if ( $ref eq 'ARRAY' ) {

      if ( $type eq 'value' ) {
        return $entry->[0];
      }

      if ( $type eq 'title' ) {
        return $entry->[1];
      }

      return $entry->[2];
    }

    if ( $ref eq 'HASH' ) {
      return $entry->{$key};
    }

    if ( $type ne 'default' || $entry->can($key) ) {
      return $entry->$key;
    }

    return undef;
  };

  foreach my $entry ( @{ $collection } ) {
    my $value;
    my $title;

    if ( $value_title_sub ) {
      ($value, $title) = @{ $value_title_sub->($entry) };
    } else {

      $value = $normalize_entry->('value', $entry, $value_sub, $value_key);
      $title = $normalize_entry->('title', $entry, $title_sub, $title_key);
    }

    my $default = $normalize_entry->('default', $entry, $default_sub, $default_key);

    push(@options, [$value, $title, $default]);
  }

  foreach my $entry (@options) {
    if ( exists($selected{$entry->[0]}) ) {
      $entry->[2] = 1;
    }
  }

  my $code = '';

  foreach my $entry (@options) {
    my %args = (value => $entry->[0]);

    $args{selected} = $entry->[2];

    $code .= $self->html_tag('option', _H($entry->[1]), %args);
  }

  $code = $self->html_tag('select', $code, %attributes, name => $name);

  return $code;
}

sub textarea_tag {
  my ($self, $name, $content, @slurp) = @_;
  my %attributes      = _hashify(@slurp);

  $attributes{id}   ||= $self->name_to_id($name);
  $attributes{rows}  *= 1; # required by standard
  $attributes{cols}  *= 1; # required by standard
  $content            = $content ? _H($content) : '';

  return $self->html_tag('textarea', $content, %attributes, name => $name);
}

sub checkbox_tag {
  my ($self, $name, @slurp) = @_;
  my %attributes       = _hashify(@slurp);

  $attributes{id}    ||= $self->name_to_id($name);
  $attributes{value}   = 1 unless defined $attributes{value};
  my $label            = delete $attributes{label};
  my $checkall         = delete $attributes{checkall};

  if ($attributes{checked}) {
    $attributes{checked} = 'checked';
  } else {
    delete $attributes{checked};
  }

  my $code  = $self->html_tag('input', undef,  %attributes, name => $name, type => 'checkbox');
  $code    .= $self->html_tag('label', $label, for => $attributes{id}) if $label;
  $code    .= $self->javascript(qq|\$('#$attributes{id}').checkall('$checkall');|) if $checkall;

  return $code;
}

sub radio_button_tag {
  my $self             = shift;
  my $name             = shift;
  my %attributes       = _hashify(@_);

  $attributes{value}   = 1 unless defined $attributes{value};
  $attributes{id}    ||= $self->name_to_id($name . "_" . $attributes{value});
  my $label            = delete $attributes{label};

  if ($attributes{checked}) {
    $attributes{checked} = 'checked';
  } else {
    delete $attributes{checked};
  }

  my $code  = $self->html_tag('input', undef,  %attributes, name => $name, type => 'radio');
  $code    .= $self->html_tag('label', $label, for => $attributes{id}) if $label;

  return $code;
}

sub input_tag {
  my ($self, $name, $value, @slurp) = @_;
  my %attributes      = _hashify(@slurp);

  $attributes{id}   ||= $self->name_to_id($name);
  $attributes{type} ||= 'text';

  return $self->html_tag('input', undef, %attributes, name => $name, value => $value);
}

sub hidden_tag {
  return shift->input_tag(@_, type => 'hidden');
}

sub div_tag {
  my ($self, $content, @slurp) = @_;
  return $self->html_tag('div', $content, @slurp);
}

sub ul_tag {
  my ($self, $content, @slurp) = @_;
  return $self->html_tag('ul', $content, @slurp);
}

sub li_tag {
  my ($self, $content, @slurp) = @_;
  return $self->html_tag('li', $content, @slurp);
}

sub link {
  my ($self, $href, $content, @slurp) = @_;
  my %params = _hashify(@slurp);

  $href ||= '#';

  return $self->html_tag('a', $content, %params, href => $href);
}

sub submit_tag {
  my ($self, $name, $value, @slurp) = @_;
  my %attributes = _hashify(@slurp);

  if ( $attributes{confirm} ) {
    $attributes{onclick} = 'return confirm("'. _J(delete($attributes{confirm})) .'");';
  }

  return $self->input_tag($name, $value, %attributes, type => 'submit', class => 'submit');
}

sub button_tag {
  my ($self, $onclick, $value, @slurp) = @_;
  my %attributes = _hashify(@slurp);

  $attributes{id}   ||= $self->name_to_id($attributes{name}) if $attributes{name};
  $attributes{type} ||= 'button';

  return $self->html_tag('input', undef, %attributes, value => $value, onclick => $onclick);
}

sub yes_no_tag {
  my ($self, $name, $value) = splice @_, 0, 3;
  my %attributes            = _hashify(@_);

  return $self->select_tag($name, [ [ 1 => $::locale->text('Yes') ], [ 0 => $::locale->text('No') ] ], default => $value ? 1 : 0, %attributes);
}

sub javascript {
  my ($self, $data) = @_;
  return $self->html_tag('script', $data, type => 'text/javascript');
}

sub stylesheet_tag {
  my $self = shift;
  my $code = '';

  foreach my $file (@_) {
    $file .= '.css'        unless $file =~ m/\.css$/;
    $file  = "css/${file}" unless $file =~ m|/|;

    $code .= qq|<link rel="stylesheet" href="${file}" type="text/css" media="screen" />|;
  }

  return $code;
}

sub date_tag {
  my ($self, $name, $value, @slurp) = @_;
  my %params   = _hashify(@slurp);
  my $name_e   = _H($name);
  my $seq      = _tag_id();
  my $datefmt  = apply {
    s/d+/\%d/gi;
    s/m+/\%m/gi;
    s/y+/\%Y/gi;
  } $::myconfig{"dateformat"};

  my $cal_align = delete $params{cal_align} || 'BR';
  my $onchange  = delete $params{onchange};
  my $str_value = blessed $value ? $value->to_lxoffice : $value;

  $self->input_tag($name, $str_value,
    id     => $name_e,
    size   => 11,
    title  => _H($::myconfig{dateformat}),
    onBlur => 'check_right_date_format(this)',
    ($onchange ? (
    onChange => $onchange,
    ) : ()),
    %params,
  ) . ((!$params{no_cal} && !$params{readonly}) ?
  $self->html_tag('img', undef,
    src    => 'image/calendar.png',
    alt    => $::locale->text('Calendar'),
    id     => "trigger$seq",
    title  => _H($::myconfig{dateformat}),
    %params,
  ) .
  $self->javascript(
    "Calendar.setup({ inputField: '$name_e', ifFormat: '$datefmt', align: '$cal_align', button: 'trigger$seq' });"
  ) : '');
}

sub customer_picker {
  my ($self, $name, $value, %params) = @_;
  my $name_e    = _H($name);

  $::request->{layout}->add_javascripts('autocomplete_customer.js');

  $self->hidden_tag($name, (ref $value && $value->can('id') ? $value->id : ''), class => 'customer_autocomplete') .
  $self->input_tag("$name_e\_name", (ref $value && $value->can('name')) ? $value->name : '', %params);
}

# simple version with select_tag
sub vendor_selector {
  my ($self, $name, $value, %params) = @_;

  my $actual_vendor_id = (defined $::form->{"$name"})? ((ref $::form->{"$name"}) ? $::form->{"$name"}->id : $::form->{"$name"}) :
                         (ref $value && $value->can('id')) ? $value->id : '';

  return $self->select_tag($name, SL::DB::Manager::Vendor->get_all(),
                                  default      => $actual_vendor_id,
                                  title_sub    => sub { $_[0]->vendornumber . " : " . $_[0]->name },
                                  'with_empty' => 1,
                                  %params);
}


# simple version with select_tag
sub part_selector {
  my ($self, $name, $value, %params) = @_;

  my $actual_part_id = (defined $::form->{"$name"})? ((ref $::form->{"$name"})? $::form->{"$name"}->id : $::form->{"$name"}) :
                       (ref $value && $value->can('id')) ? $value->id : '';

  return $self->select_tag($name, SL::DB::Manager::Part->get_all(),
                           default      => $actual_part_id,
                           title_sub    => sub { $_[0]->partnumber . " : " . $_[0]->description },
                           with_empty   => 1,
                           %params);
}


sub javascript_tag {
  my $self = shift;
  my $code = '';

  foreach my $file (@_) {
    $file .= '.js'        unless $file =~ m/\.js$/;
    $file  = "js/${file}" unless $file =~ m|/|;

    $code .= qq|<script type="text/javascript" src="${file}"></script>|;
  }

  return $code;
}

sub tabbed {
  my ($self, $tabs, @slurp) = @_;
  my %params   = _hashify(@slurp);
  my $id       = $params{id} || 'tab_' . _tag_id();

  $params{selected} *= 1;

  die 'L.tabbed needs an arrayred of tabs for first argument'
    unless ref $tabs eq 'ARRAY';

  my (@header, @blocks);
  for my $i (0..$#$tabs) {
    my $tab = $tabs->[$i];

    next if $tab eq '';

    my $selected = $params{selected} == $i;
    my $tab_id   = "__tab_id_$i";
    push @header, $self->li_tag(
      $self->link('', $tab->{name}, rel => $tab_id),
        ($selected ? (class => 'selected') : ())
    );
    push @blocks, $self->div_tag($tab->{data},
      id => $tab_id, class => 'tabcontent');
  }

  return '' unless @header;
  return $self->ul_tag(
    join('', @header), id => $id, class => 'shadetabs'
  ) .
  $self->div_tag(
    join('', @blocks), class => 'tabcontentstyle'
  ) .
  $self->javascript(
    qq|var $id = new ddtabcontent("$id");$id.setpersist(true);| .
    qq|$id.setselectedClassTarget("link");$id.init();|
  );
}

sub tab {
  my ($self, $name, $src, @slurp) = @_;
  my %params = _hashify(@slurp);

  $params{method} ||= 'process';

  return () if defined $params{if} && !$params{if};

  my $data;
  if ($params{method} eq 'raw') {
    $data = $src;
  } elsif ($params{method} eq 'process') {
    $data = $self->_context->process($src, %{ $params{args} || {} });
  } else {
    die "unknown tag method '$params{method}'";
  }

  return () unless $data;

  return +{ name => $name, data => $data };
}

sub areainput_tag {
  my ($self, $name, $value, @slurp) = @_;
  my %attributes      = _hashify(@slurp);

  my ($rows, $cols);
  my $min  = delete $attributes{min_rows} || 1;

  if (exists $attributes{cols}) {
    $cols = delete $attributes{cols};
    $rows = $::form->numtextrows($value, $cols);
  } else {
    $rows = delete $attributes{rows} || 1;
  }

  return $rows > 1
    ? $self->textarea_tag($name, $value, %attributes, rows => max($rows, $min), ($cols ? (cols => $cols) : ()))
    : $self->input_tag($name, $value, %attributes, ($cols ? (size => $cols) : ()));
}

sub multiselect2side {
  my ($self, $id, @slurp) = @_;
  my %params              = _hashify(@slurp);

  $params{labelsx}        = "\"" . _J($params{labelsx} || $::locale->text('Available')) . "\"";
  $params{labeldx}        = "\"" . _J($params{labeldx} || $::locale->text('Selected'))  . "\"";
  $params{moveOptions}    = 'false';

  my $vars                = join(', ', map { "${_}: " . $params{$_} } keys %params);
  my $code                = <<EOCODE;
<script type="text/javascript">
  \$().ready(function() {
    \$('#${id}').multiselect2side({ ${vars} });
  });
</script>
EOCODE

  return $code;
}

sub sortable_element {
  my ($self, $selector, @slurp) = @_;
  my %params                    = _hashify(@slurp);

  my %attributes = ( distance => 5,
                     helper   => <<'JAVASCRIPT' );
    function(event, ui) {
      ui.children().each(function() {
        $(this).width($(this).width());
      });
      return ui;
    }
JAVASCRIPT

  my $stop_event = '';

  if ($params{url} && $params{with}) {
    my $as      = $params{as} || $params{with};
    my $filter  = ".filter(function(idx) { return this.substr(0, " . length($params{with}) . ") == '$params{with}'; })";
    $filter    .= ".map(function(idx, str) { return str.replace('$params{with}_', ''); })";

    $stop_event = <<JAVASCRIPT;
        \$.post('$params{url}', { '${as}[]': \$(\$('${selector}').sortable('toArray'))${filter}.toArray() });
JAVASCRIPT
  }

  if (!$params{dont_recolor}) {
    $stop_event .= <<JAVASCRIPT;
        \$('${selector}>*:odd').removeClass('listrow1').removeClass('listrow0').addClass('listrow0');
        \$('${selector}>*:even').removeClass('listrow1').removeClass('listrow0').addClass('listrow1');
JAVASCRIPT
  }

  if ($stop_event) {
    $attributes{stop} = <<JAVASCRIPT;
      function(event, ui) {
        ${stop_event}
        return ui;
      }
JAVASCRIPT
  }

  $params{handle}     = '.dragdrop' unless exists $params{handle};
  $attributes{handle} = "'$params{handle}'" if $params{handle};

  my $attr_str = join(', ', map { "${_}: $attributes{$_}" } keys %attributes);

  my $code = <<JAVASCRIPT;
<script type="text/javascript">
  \$(function() {
    \$( "${selector}" ).sortable({ ${attr_str} })
  });
</script>
JAVASCRIPT

  return $code;
}

sub online_help_tag {
  my ($self, $tag, @slurp) = @_;
  my %params               = _hashify(@slurp);
  my $cc                   = $::myconfig{countrycode};
  my $file                 = "doc/online/$cc/$tag.html";
  my $text                 = $params{text} || $::locale->text('Help');

  die 'malformed help tag' unless $tag =~ /^[a-zA-Z0-9_]+$/;
  return unless -f $file;
  return $self->html_tag('a', $text, href => $file, class => 'jqModal')
}

sub dump {
  my $self = shift;
  require Data::Dumper;
  return '<pre>' . Data::Dumper::Dumper(@_) . '</pre>';
}

sub truncate {
  my ($self, $text, @slurp) = @_;
  my %params                = _hashify(@slurp);

  $params{at}             ||= 50;
  $params{at}               =  3 if 3 > $params{at};
  $params{at}              -= 3;

  return $text if length($text) < $params{at};
  return substr($text, 0, $params{at}) . '...';
}

sub sortable_table_header {
  my ($self, $by, @slurp) = @_;
  my %params              = _hashify(@slurp);

  my $controller          = $self->{CONTEXT}->stash->get('SELF');
  my $sort_spec           = $controller->get_sort_spec;
  my $by_spec             = $sort_spec->{$by};
  my %current_sort_params = $controller->get_current_sort_params;
  my ($image, $new_dir)   = ('', $current_sort_params{dir});
  my $title               = delete($params{title}) || $::locale->text($by_spec->{title});

  if ($current_sort_params{by} eq $by) {
    my $current_dir = $current_sort_params{dir} ? 'up' : 'down';
    $image          = '<img border="0" src="image/' . $current_dir . '.png">';
    $new_dir        = 1 - ($current_sort_params{dir} || 0);
  }

  $params{ $sort_spec->{FORM_PARAMS}->[0] } = $by;
  $params{ $sort_spec->{FORM_PARAMS}->[1] } = ($new_dir ? '1' : '0');

  return '<a href="' . $controller->get_callback(%params) . '">' . _H($title) . $image . '</a>';
}

sub paginate_controls {
  my ($self)          = @_;

  my $controller      = $self->{CONTEXT}->stash->get('SELF');
  my $paginate_spec   = $controller->get_paginate_spec;
  my %paginate_params = $controller->get_current_paginate_params;

  my %template_params = (
    pages             => \%paginate_params,
    url_maker         => sub {
      my %url_params                                    = _hashify(@_);
      $url_params{ $paginate_spec->{FORM_PARAMS}->[0] } = delete $url_params{page};
      $url_params{ $paginate_spec->{FORM_PARAMS}->[1] } = delete $url_params{per_page} if exists $url_params{per_page};

      return $controller->get_callback(%url_params);
    },
  );

  return SL::Presenter->get->render('common/paginate', %template_params);
}

1;

__END__

=head1 NAME

SL::Templates::Plugin::L -- Layouting / tag generation

=head1 SYNOPSIS

Usage from a template:

  [% USE L %]

  [% L.select_tag('direction', [ [ 'left', 'To the left' ], [ 'right', 'To the right', 1 ] ]) %]

  [% L.select_tag('direction', [ { direction => 'left',  display => 'To the left'  },
                                 { direction => 'right', display => 'To the right' } ],
                               value_key => 'direction', title_key => 'display', default => 'right')) %]

  [% L.select_tag('direction', [ { direction => 'left',  display => 'To the left'  },
                                 { direction => 'right', display => 'To the right', selected => 1 } ],
                               value_key => 'direction', title_key => 'display')) %]

=head1 DESCRIPTION

A module modeled a bit after Rails' ActionView helpers. Several small
functions that create HTML tags from various kinds of data sources.

=head1 FUNCTIONS

=head2 LOW-LEVEL FUNCTIONS

=over 4

=item C<name_to_id $name>

Converts a name to a HTML id by replacing various characters.

=item C<attributes %items>

Creates a string from all elements in C<%items> suitable for usage as
HTML tag attributes. Keys and values are HTML escaped even though keys
must not contain non-ASCII characters for browsers to accept them.

=item C<html_tag $tag_name, $content_string, %attributes>

Creates an opening and closing HTML tag for C<$tag_name> and puts
C<$content_string> between the two. If C<$content_string> is undefined
or empty then only a E<lt>tag/E<gt> tag will be created. Attributes
are key/value pairs added to the opening tag.

C<$content_string> is not HTML escaped.

=back

=head2 HIGH-LEVEL FUNCTIONS

=over 4

=item C<select_tag $name, \@collection, %attributes>

Creates a HTML 'select' tag named C<$name> with the contents of one
'E<lt>optionE<gt>' tag for each element in C<\@collection> and with arbitrary
HTML attributes from C<%attributes>. The value
to use and the title to display are extracted from the elements in
C<\@collection>. Each element can be one of four things:

=over 12

=item 1. An array reference with at least two elements. The first element is
the value, the second element is its title. The third element is optional and and should contain a boolean.
If it is true, than the element will be used as default.

=item 2. A scalar. The scalar is both the value and the title.

=item 3. A hash reference. In this case C<%attributes> must contain
I<value_key>, I<title_key> and may contain I<default_key> keys that name the keys in the element to use
for the value, title and default respectively.

=item 4. A blessed reference. In this case C<%attributes> must contain
I<value_key>, I<title_key> and may contain I<default_key> keys that name functions called on the blessed
reference whose return values are used as the value, title and default
respectively.

=back

For cases 3 and 4 C<$attributes{value_key}> defaults to C<id>,
C<$attributes{title_key}> defaults to C<$attributes{value_key}>
and C<$attributes{default_key}> defaults to C<selected>.

In addition to pure keys/method you can also provide coderefs as I<value_sub>
and/or I<title_sub> and/or I<default_sub>. If present, these take precedence over keys or methods,
and are called with the element as first argument. It must return the value, title or default.

Lastly a joint coderef I<value_title_sub> may be provided, which in turn takes
precedence over the C<value_sub> and C<title_sub> subs. It will only be called once for each
element and must return a list of value and title.

If the option C<with_empty> is set then an empty element (value
C<undef>) will be used as the first element. The title to display for
this element can be set with the option C<empty_title> and defaults to
an empty string.

The option C<default> can be either a scalar or an array reference
containing the values of the options which should be set to be
selected.

The tag's C<id> defaults to C<name_to_id($name)>.

=item C<yes_no_tag $name, $value, %attributes>

Creates a HTML 'select' tag with the two entries C<yes> and C<no> by
calling L<select_tag>. C<$value> determines
which entry is selected. The C<%attributes> are passed through to
L<select_tag>.

=item C<input_tag $name, $value, %attributes>

Creates a HTML 'input type=text' tag named C<$name> with the value
C<$value> and with arbitrary HTML attributes from C<%attributes>. The
tag's C<id> defaults to C<name_to_id($name)>.

=item C<hidden_tag $name, $value, %attributes>

Creates a HTML 'input type=hidden' tag named C<$name> with the value
C<$value> and with arbitrary HTML attributes from C<%attributes>. The
tag's C<id> defaults to C<name_to_id($name)>.

=item C<submit_tag $name, $value, %attributes>

Creates a HTML 'input type=submit class=submit' tag named C<$name> with the
value C<$value> and with arbitrary HTML attributes from C<%attributes>. The
tag's C<id> defaults to C<name_to_id($name)>.

If C<$attributes{confirm}> is set then a JavaScript popup dialog will
be added via the C<onclick> handler asking the question given with
C<$attributes{confirm}>. If request is only submitted if the user
clicks the dialog's ok/yes button.

=item C<textarea_tag $name, $value, %attributes>

Creates a HTML 'textarea' tag named C<$name> with the content
C<$value> and with arbitrary HTML attributes from C<%attributes>. The
tag's C<id> defaults to C<name_to_id($name)>.

=item C<checkbox_tag $name, %attributes>

Creates a HTML 'input type=checkbox' tag named C<$name> with arbitrary
HTML attributes from C<%attributes>. The tag's C<id> defaults to
C<name_to_id($name)>. The tag's C<value> defaults to C<1>.

If C<%attributes> contains a key C<label> then a HTML 'label' tag is
created with said C<label>. No attribute named C<label> is created in
that case.

If C<%attributes> contains a key C<checkall> then the value is taken as a
JQuery selector and clicking this checkbox will also toggle all checkboxes
matching the selector.

=item C<date_tag $name, $value, cal_align =E<gt> $align_code, %attributes>

Creates a date input field, with an attached javascript that will open a
calendar on click. The javascript ist by default anchoered at the bottom right
sight. This can be overridden with C<cal_align>, see Calendar documentation for
the details, usually you'll want a two letter abbreviation of the alignment.
Right + Bottom becomes C<BL>.

=item C<radio_button_tag $name, %attributes>

Creates a HTML 'input type=radio' tag named C<$name> with arbitrary
HTML attributes from C<%attributes>. The tag's C<value> defaults to
C<1>. The tag's C<id> defaults to C<name_to_id($name . "_" . $value)>.

If C<%attributes> contains a key C<label> then a HTML 'label' tag is
created with said C<label>. No attribute named C<label> is created in
that case.

=item C<javascript_tag $file1, $file2, $file3...>

Creates a HTML 'E<lt>script type="text/javascript" src="..."E<gt>'
tag for each file name parameter passed. Each file name will be
postfixed with '.js' if it isn't already and prefixed with 'js/' if it
doesn't contain a slash.

=item C<stylesheet_tag $file1, $file2, $file3...>

Creates a HTML 'E<lt>link rel="text/stylesheet" href="..."E<gt>' tag
for each file name parameter passed. Each file name will be postfixed
with '.css' if it isn't already and prefixed with 'css/' if it doesn't
contain a slash.

=item C<date_tag $name, $value, cal_align =E<gt> $align_code, %attributes>

Creates a date input field, with an attached javascript that will open a
calendar on click. The javascript ist by default anchoered at the bottom right
sight. This can be overridden with C<cal_align>, see Calendar documentation for
the details, usually you'll want a two letter abbreviation of the alignment.
Right + Bottom becomes C<BL>.

=item C<tabbed \@tab, %attributes>

Will create a tabbed area. The tabs should be created with the helper function
C<tab>. Example:

  [% L.tabbed([
    L.tab(LxERP.t8('Basic Data'),       'part/_main_tab.html'),
    L.tab(LxERP.t8('Custom Variables'), 'part/_cvar_tab.html', if => SELF.display_cvar_tab),
  ]) %]

An optional attribute is C<selected>, which accepts the ordinal of a tab which
should be selected by default.

=item C<areainput_tag $name, $content, %PARAMS>

Creates a generic input tag or textarea tag, depending on content size. The
amount of desired rows must be either given with the C<rows> parameter or can
be computed from the value and the C<cols> paramter, Accepted parameters
include C<min_rows> for rendering a minimum of rows if a textarea is displayed.

You can force input by setting rows to 1, and you can force textarea by setting
rows to anything >1.

=item C<multiselect2side $id, %params>

Creates a JavaScript snippet calling the jQuery function
C<multiselect2side> on the select control with the ID C<$id>. The
select itself is not created. C<%params> can contain the following
entries:

=over 2

=item C<labelsx>

The label of the list of available options. Defaults to the
translation of 'Available'.

=item C<labeldx>

The label of the list of selected options. Defaults to the
translation of 'Selected'.

=back

=item C<sortable_element $selector, %params>

Makes the children of the DOM element C<$selector> (a jQuery selector)
sortable with the I<jQuery UI Selectable> library. The children can be
dragged & dropped around. After dropping an element an URL can be
postet to with the element IDs of the sorted children.

If this is used then the JavaScript file C<js/jquery-ui.js> must be
included manually as well as it isn't loaded via C<$::form-gt;header>.

C<%params> can contain the following entries:

=over 2

=item C<url>

The URL to POST an AJAX request to after a dragged element has been
dropped. The AJAX request's return value is ignored. If given then
C<$params{with}> must be given as well.

=item C<with>

A string that is interpreted as the prefix of the children's ID. Upon
POSTing the result each child whose ID starts with C<$params{with}> is
considered. The prefix and the following "_" is removed from the
ID. The remaining parts of the IDs of those children are posted as a
single array parameter. The array parameter's name is either
C<$params{as}> or, missing that, C<$params{with}>.

=item C<as>

Sets the POST parameter name for AJAX request after dropping an
element (see C<$params{with}>).

=item C<handle>

An optional jQuery selector specifying which part of the child element
is dragable. If the parameter is not given then it defaults to
C<.dragdrop> matching DOM elements with the class C<dragdrop>.  If the
parameter is set and empty then the whole child element is dragable,
and clicks through to underlying elements like inputs or links might
not work.

=item C<dont_recolor>

If trueish then the children will not be recolored. The default is to
recolor the children by setting the class C<listrow0> on odd and
C<listrow1> on even entries.

=back

Example:

  <script type="text/javascript" src="js/jquery-ui.js"></script>

  <table id="thing_list">
    <thead>
      <tr><td>This</td><td>That</td></tr>
    </thead>
    <tbody>
      <tr id="thingy_2"><td>stuff</td><td>more stuff</td></tr>
      <tr id="thingy_15"><td>stuff</td><td>more stuff</td></tr>
      <tr id="thingy_6"><td>stuff</td><td>more stuff</td></tr>
    </tbody>
  <table>

  [% L.sortable_element('#thing_list tbody',
                        url          => 'controller.pl?action=SystemThings/reorder',
                        with         => 'thingy',
                        as           => 'thing_ids',
                        recolor_rows => 1) %]

After dropping e.g. the third element at the top of the list a POST
request would be made to the C<reorder> action of the C<SystemThings>
controller with a single parameter called C<thing_ids> -- an array
containing the values C<[ 6, 2, 15 ]>.

=item C<dump REF>

Dumps the Argument using L<Data::Dumper> into a E<lt>preE<gt> block.

=item C<sortable_table_header $by, %params>

Create a link and image suitable for placement in a table
header. C<$by> must be an index set up by the controller with
L<SL::Controller::Helper::make_sorted>.

The optional parameter C<$params{title}> can override the column title
displayed to the user. Otherwise the column title from the
controller's sort spec is used.

The other parameters in C<%params> are passed unmodified to the
underlying call to L<SL::Controller::Base::url_for>.

See the documentation of L<SL::Controller::Helper::Sorted> for an
overview and further usage instructions.

=item C<paginate_controls>

Create a set of links used to paginate a list view.

See the documentation of L<SL::Controller::Helper::Paginated> for an
overview and further usage instructions.

=back

=head2 CONVERSION FUNCTIONS

=over 4

=item C<tab, description, target, %PARAMS>

Creates a tab for C<tabbed>. The description will be used as displayed name.
The target should be a block or template that can be processed. C<tab> supports
a C<method> parameter, which can override the process method to apply target.
C<method => 'raw'> will just include the given text as is. I was too lazy to
implement C<include> properly.

Also an C<if> attribute is supported, so that tabs can be suppressed based on
some occasion. In this case the supplied block won't even get processed, and
the resulting tab will get ignored by C<tabbed>:

  L.tab('Awesome tab wih much info', '_much_info.html', if => SELF.wants_all)

=item C<truncate $text, %params>

Returns the C<$text> truncated after a certain number of
characters.

The number of characters to truncate at is determined by the parameter
C<at> which defaults to 50. If the text is longer than C<$params{at}>
then it will be truncated and postfixed with '...'. Otherwise it will
be returned unmodified.

=back

=head1 MODULE AUTHORS

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

L<http://linet-services.de>
