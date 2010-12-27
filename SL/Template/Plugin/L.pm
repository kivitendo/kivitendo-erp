package SL::Template::Plugin::L;

use base qw( Template::Plugin );
use Template::Plugin;
use List::MoreUtils qw(apply);

use strict;

{ # This will give you an id for identifying html tags and such.
  # It's guaranteed to be unique unless you exceed 10 mio calls per request.
  # Do not use these id's to store information across requests.
my $_id_sequence = int rand 1e7;
sub _tag_id {
  return $_id_sequence = ($_id_sequence + 1) % 1e7;
}
}

sub _H {
  my $string = shift;
  return $::locale->quote_special_chars('HTML', $string);
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
  my $self    = shift;
  my %options = _hashify(@_);

  my @result = ();
  while (my ($name, $value) = each %options) {
    next unless $name;
    $value = '' if !defined($value);
    push @result, _H($name) . '="' . _H($value) . '"';
  }

  return @result ? ' ' . join(' ', @result) : '';
}

sub html_tag {
  my $self       = shift;
  my $tag        = shift;
  my $content    = shift;
  my $attributes = $self->attributes(@_);

  return "<${tag}${attributes}/>" unless defined($content);
  return "<${tag}${attributes}>${content}</${tag}>";
}

sub select_tag {
  my $self            = shift;
  my $name            = shift;
  my $options_str     = shift;
  my %attributes      = _hashify(@_);

  $attributes{id}   ||= $self->name_to_id($name);
  $options_str        = $self->options_for_select($options_str) if ref $options_str;

  return $self->html_tag('select', $options_str, %attributes, name => $name);
}

sub textarea_tag {
  my $self            = shift;
  my $name            = shift;
  my $content         = shift;
  my %attributes      = _hashify(@_);

  $attributes{id}   ||= $self->name_to_id($name);
  $content            = $content ? _H($content) : '';

  return $self->html_tag('textarea', $content, %attributes, name => $name);
}

sub checkbox_tag {
  my $self             = shift;
  my $name             = shift;
  my %attributes       = _hashify(@_);

  $attributes{id}    ||= $self->name_to_id($name);
  $attributes{value}   = 1 unless defined $attributes{value};
  my $label            = delete $attributes{label};

  if ($attributes{checked}) {
    $attributes{checked} = 'checked';
  } else {
    delete $attributes{checked};
  }

  my $code  = $self->html_tag('input', undef,  %attributes, name => $name, type => 'checkbox');
  $code    .= $self->html_tag('label', $label, for => $attributes{id}) if $label;

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
  my %attributes                    = _hashify(@slurp);

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
  my $self             = shift;
  my $name             = shift;
  my $value            = shift;
  my %attributes       = _hashify(@_);

  $attributes{onclick} = "if (confirm('" . delete($attributes{confirm}) . "')) return true; else return false;" if $attributes{confirm};

  return $self->input_tag($name, $value, %attributes, type => 'submit', class => 'submit');
}

sub options_for_select {
  my $self            = shift;
  my $collection      = shift;
  my %options         = _hashify(@_);

  my $value_key       = $options{value} || 'id';
  my $title_key       = $options{title} || $value_key;

  my $value_sub       = $options{value_sub};
  my $title_sub       = $options{title_sub};

  my $value_title_sub = $options{value_title_sub};

  my $access = sub {
    my ($element, $index, $key, $sub) = @_;
    my $ref = ref $element;
    return  $sub            ? $sub->($element)
         : !$ref            ? $element
         :  $ref eq 'ARRAY' ? $element->[$index]
         :  $ref eq 'HASH'  ? $element->{$key}
         :                    $element->$key;
  };

  my @elements = ();
  push @elements, [ undef, $options{empty_title} || '' ] if $options{with_empty};
  push @elements, map [
    $value_title_sub ? $value_title_sub->($_) : (
      $access->($_, 0, $value_key, $value_sub),
      $access->($_, 1, $title_key, $title_sub),
    )
  ], @{ $collection } if $collection && ref $collection eq 'ARRAY';

  my $code = '';
  foreach my $result (@elements) {
    my %attributes = ( value => $result->[0] );
    $attributes{selected} = 'selected' if $options{default} && ($options{default} eq ($result->[0] || ''));

    $code .= $self->html_tag('option', _H($result->[1]), %attributes);
  }

  return $code;
}

sub javascript {
  my ($self, $data) = @_;
  return $self->html_tag('script', $data, type => 'text/javascript');
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

  $params{cal_align} ||= 'BR';

  $self->input_tag($name, $value,
    id     => $name_e,
    size   => 11,
    title  => _H($::myconfig{dateformat}),
    onBlur => 'check_right_date_format(this)',
    %params,
  ) . ((!$params{no_cal}) ?
  $self->html_tag('img', undef,
    src    => 'image/calendar.png',
    id     => "trigger$seq",
    title  => _H($::myconfig{dateformat}),
    %params,
  ) .
  $self->javascript(
    "Calendar.setup({ inputField: '$name_e', ifFormat: '$datefmt', align: '$params{cal_align}', button: 'trigger$seq' });"
  ) : '');

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
  my $id       = 'tab_' . _tag_id();

  $params{selected} *= 1;

  die 'L.tabbed needs an arrayred of tabs for first argument'
    unless ref $tabs eq 'ARRAY';

  my (@header, @blocks);
  for my $i (0..$#$tabs) {
    my $tab = $tabs->[$i];

    next if $tab eq '';

    my $selected = $params{selected} == $i;
    my $tab_id = _tag_id();
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

1;

__END__

=head1 NAME

SL::Templates::Plugin::L -- Layouting / tag generation

=head1 SYNOPSIS

Usage from a template:

  [% USE L %]

  [% L.select_tag('direction', [ [ 'left', 'To the left' ], [ 'right', 'To the right' ] ]) %]

  [% L.select_tag('direction', L.options_for_select([ { direction => 'left',  display => 'To the left'  },
                                                      { direction => 'right', display => 'To the right' } ],
                                                    value => 'direction', title => 'display', default => 'right')) %]

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

=item C<select_tag $name, $options_string, %attributes>

Creates a HTML 'select' tag named C<$name> with the contents
C<$options_string> and with arbitrary HTML attributes from
C<%attributes>. The tag's C<id> defaults to C<name_to_id($name)>.

The C<$options_string> is usually created by the
L</options_for_select> function. If C<$options_string> is an array
reference then it will be passed to L</options_for_select>
automatically.

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

=item C<date_tag $name, $value, cal_align =E<gt> $align_code, %attributes>

Creates a date input field, with an attached javascript that will open a
calendar on click. The javascript ist by default anchoered at the bottom right
sight. This can be overridden with C<cal_align>, see Calendar documentation for
the details, usually you'll want a two letter abbreviation of the alignment.
Right + Bottom becomes C<BL>.

=item C<tabbed \@tab, %attributes>

Will create a tabbed area. The tabs should be created with the helper function
C<tab>

=back

=head2 CONVERSION FUNCTIONS

=over 4

=item C<options_for_select \@collection, %options>

Creates a string suitable for a HTML 'select' tag consisting of one
'E<lt>optionE<gt>' tag for each element in C<\@collection>. The value
to use and the title to display are extracted from the elements in
C<\@collection>. Each element can be one of four things:

=over 12

=item 1. An array reference with at least two elements. The first element is
the value, the second element is its title.

=item 2. A scalar. The scalar is both the value and the title.

=item 3. A hash reference. In this case C<%options> must contain
I<value> and I<title> keys that name the keys in the element to use
for the value and title respectively.

=item 4. A blessed reference. In this case C<%options> must contain
I<value> and I<title> keys that name functions called on the blessed
reference whose return values are used as the value and title
respectively.

=back

For cases 3 and 4 C<$options{value}> defaults to C<id> and
C<$options{title}> defaults to C<$options{value}>.

In addition to pure keys/method you can also provide coderefs as I<value_sub>
and/or I<title_sub>. If present, these take precedence over keys or methods,
and are called with the element as first argument. It must return the value or
title.

Lastly a joint coderef I<value_title_sub> may be provided, which in turn takes
precedence over each individual sub. It will only be called once for each
element and must return a list of value and title.

If the option C<with_empty> is set then an empty element (value
C<undef>) will be used as the first element. The title to display for
this element can be set with the option C<empty_title> and defaults to
an empty string.

=back

=head1 MODULE AUTHORS

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

L<http://linet-services.de>
