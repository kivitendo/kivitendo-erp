package SL::Template::Plugin::L;

use base qw( Template::Plugin );
use Template::Plugin;

use strict;

sub new {
  my $class   = shift;
  my $context = shift;

  return bless { }, $class;
}

sub attributes {
  my $self    = shift;
  my $options = shift || {};

  my @result = ();
  while (my ($name, $value) = each %{ $options }) {
    next unless $name;
    $value ||= '';
    push @result, "${name}=\"" . $::locale->quote_special_chars('HTML', $value) . '"';
  }

  return @result ? ' ' . join(' ', @result) : '';
}

sub html_tag {
  my $self       = shift;
  my $tag        = shift;
  my $content    = shift;
  my $attributes = $self->attributes(shift || {});

  return "<${tag}${attributes}/>" unless $content;
  return "<${tag}${attributes}>${content}</${tag}>";
}

sub select_tag {
  my $self              = shift;
  my $name              = shift;
  my $options_str       = shift;
  my $attributes        = shift || {};

  $attributes->{name}   = $name;
  $attributes->{id}   ||= $name;

  return $self->html_tag('select', $options_str, $attributes);
}

sub options_for_select {
  my $self          = shift;
  my $collection    = shift;
  my $options       = shift || {};

  my $value_key     = $options->{value} || 'id';
  my $title_key     = $options->{title} || $value_key;

  my @tags          = ();
  if ($collection && (ref $collection eq 'ARRAY')) {
    foreach my $element (@{ $collection }) {
      my @result = !ref $element            ? ( $element,               $element               )
                 :  ref $element eq 'ARRAY' ? ( $element->[0],          $element->[1]          )
                 :  ref $element eq 'HASH'  ? ( $element->{$value_key}, $element->{$title_key} )
                 :                            ( $element->$value_key,   $element->$title_key   );

      my %attributes = ( value => $result[0] );
      $attributes{selected} = 'selected' if $options->{default} && ($options->{default} eq ($result[0] || ''));

      push @tags, $self->html_tag('option', $result[1], \%attributes);
    }
  }

  return join('', @tags);
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

=over 4

=item C<attributes \%items>

Creates a string from all elements in C<\%items> suitable for usage as
HTML tag attributes. Keys and values are HTML escaped even though keys
must not contain non-ASCII characters for browsers to accept them.

=item C<html_tag $tag_name, $content_string, \%attributes>

Creates an opening and closing HTML tag for C<$tag_name> and puts
C<$content_string> between the two. If C<$content_string> is undefined
or empty then only a E<lt>tag/E<gt> tag will be created. Attributes
are key/value pairs added to the opening tag.

=item C<options_for_select \@collection, \%options>

Creates a string suitable for a HTML 'select' tag consisting of one
'E<lt>optionE<gt>' tag for each element in C<\@collection>. The value
to use and the title to display are extracted from the elements in
C<\@collection>. Each element can be one of four things:

=over 12

=item 1. An array reference with at least two elements. The first element is
the value, the second element is its title.

=item 2. A scalar. The scalar is both the value and the title.

=item 3. A hash reference. In this case C<\%options> must contain
I<value> and I<title> keys that name the keys in the element to use
for the value and title respectively.

=item 4. A blessed reference. In this case C<\%options> must contain
I<value> and I<title> keys that name functions called on the blessed
reference whose return values are used as the value and title
respectively.

=back

For cases 3 and 4 C<$options{value}> defaults to C<id> and
C<$options{title}> defaults to C<$options{value}>.

=item C<select_tag $name, $options_string, \%attributes>

Creates a HTML 'select' tag named $name with the contents
$options_string and with arbitrary HTML attributes from
C<\%attributes>. The tag's C<id> defaults to C<$name>.

The $options_string is usually created by the C<options_for_select>
function.

=back

=head1 MODULE AUTHORS

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

L<http://linet-services.de>
