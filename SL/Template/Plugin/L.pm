package SL::Template::Plugin::L;

use base qw( Template::Plugin );
use Template::Plugin;

use strict;

sub _H {
  my $string = shift;
  return $::locale->quote_special_chars('HTML', $string);
}

sub _hashify {
  return (@_ && (ref($_[0]) eq 'HASH')) ? %{ $_[0] } : @_;
}

sub new {
  my $class   = shift;
  my $context = shift;

  return bless { }, $class;
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
    $value ||= '';
    push @result, _H($name) . '="' . _H($value) . '"';
  }

  return @result ? ' ' . join(' ', @result) : '';
}

sub html_tag {
  my $self       = shift;
  my $tag        = shift;
  my $content    = shift;
  my $attributes = $self->attributes(@_);

  return "<${tag}${attributes}/>" unless $content;
  return "<${tag}${attributes}>${content}</${tag}>";
}

sub select_tag {
  my $self            = shift;
  my $name            = shift;
  my $options_str     = shift;
  my %attributes      = _hashify(@_);

  $attributes{id}   ||= $self->name_to_id($name);

  return $self->html_tag('select', $options_str, %attributes, name => $name);
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

sub input_tag {
  my $self            = shift;
  my $name            = shift;
  my $value           = shift;
  my %attributes      = _hashify(@_);

  $attributes{id}   ||= $self->name_to_id($name);
  $attributes{type} ||= 'text';

  return $self->html_tag('input', undef, %attributes, name => $name, value => $value);
}

sub options_for_select {
  my $self          = shift;
  my $collection    = shift;
  my %options       = _hashify(@_);

  my $value_key     = $options{value} || 'id';
  my $title_key     = $options{title} || $value_key;

  my @elements      = ();
  push @elements, [ undef, $options{empty_title} || '' ] if $options{with_empty};

  if ($collection && (ref $collection eq 'ARRAY')) {
    foreach my $element (@{ $collection }) {
      my @result = !ref $element            ? ( $element,               $element               )
                 :  ref $element eq 'ARRAY' ? ( $element->[0],          $element->[1]          )
                 :  ref $element eq 'HASH'  ? ( $element->{$value_key}, $element->{$title_key} )
                 :                            ( $element->$value_key,   $element->$title_key   );

      push @elements, \@result;
    }
  }

  my $code = '';
  foreach my $result (@elements) {
    my %attributes = ( value => $result->[0] );
    $attributes{selected} = 'selected' if $options{default} && ($options{default} eq ($result->[0] || ''));

    $code .= $self->html_tag('option', _H($result->[1]), %attributes);
  }

  return $code;
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

The $options_string is usually created by the C<options_for_select>
function.

=item C<input_tag $name, $value, %attributes>

Creates a HTML 'input type=text' tag named C<$name> with the value
C<$value> and with arbitrary HTML attributes from C<%attributes>. The
tag's C<id> defaults to C<name_to_id($name)>.

=item C<checkbox_tag $name, %attributes>

Creates a HTML 'input type=checkbox' tag named C<$name> with arbitrary
HTML attributes from C<%attributes>. The tag's C<id> defaults to
C<name_to_id($name)>. The tag's C<value> defaults to C<1>.

If C<%attributes> contains a key C<label> then a HTML 'label' tag is
created with said C<label>. No attribute named C<label> is created in
that case.

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

If the option C<with_empty> is set then an empty element (value
C<undef>) will be used as the first element. The title to display for
this element can be set with the option C<empty_title> and defaults to
an empty string.

=back

=head1 MODULE AUTHORS

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

L<http://linet-services.de>
