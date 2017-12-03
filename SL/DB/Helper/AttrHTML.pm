package SL::DB::Helper::AttrHTML;

use strict;

use parent qw(Exporter);
our @EXPORT = qw(attr_html);

sub attr_html {
  my ($package, $attributes, %params) = @_;

  # Set default parameters:
  $params{with_stripped}   //= 1;
  $params{with_restricted} //= 1;
  $params{allowed_tags}    //= { map { ($_ => ['/']) } qw(b strong i em u ul ol li sub sup s strike br p div) };
  $attributes                = [ $attributes ] unless ref($attributes) eq 'ARRAY';

  # Do the work
  foreach my $attribute (@{ $attributes }) {
    _make_stripped(  $package, $attribute, %params) if ($params{with_stripped});
    _make_restricted($package, $attribute, %params) if ($params{with_restricted});
  }
}

sub _make_stripped {
  my ($package, $attribute, %params) = @_;

  no strict 'refs';
  require SL::HTML::Util;

  *{ $package . '::' . $attribute . '_as_stripped_html' } = sub {
    my ($self, $value) = @_;

    return $self->$attribute(SL::HTML::Util->strip($value)) if @_ > 1;
    return SL::HTML::Util->strip($self->$attribute);
  };
}

sub _make_restricted {
  my ($package, $attribute, %params) = @_;

  no strict 'refs';
  require SL::HTML::Restrict;

  my $cleaner = SL::HTML::Restrict->create(%params);

  *{ $package . '::' . $attribute . '_as_restricted_html' } = sub {
    my ($self, $value) = @_;

    return $self->$attribute($cleaner->process($value)) if @_ > 1;
    return $cleaner->process($self->$attribute);
  };
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Helper::AttrHTML - Attribute helper for stripping
all/restricting to wanted HTML tags in columns

=head1 SYNOPSIS

  # In a Rose model:
  use SL::DB::Helper::AttrHTML;
  __PACKAGE__->attr_html(
    'content',
    with_stripped => 0,
    allowed_tags  => { b => [ '/' ], i => [ '/' ] },
  );

  # Use in HTML templates (no usage of HTML.escape() here!):
  <div>
    This is the post's content:<br>
    [% SELF.obj.content_as_restricted_html %]
  </div>

  # Writing to it from a form:
  <form method="post">
    ...
    [% L.textarea_tag('post.content_as_restricted_html', SELF.obj.content_as_restricted_html) %]
  </form>

=head1 OVERVIEW

Sometimes you want an HTML editor on your web page. However, you only
want to allow certain tags. You also need to repeat that stuff when
displaying it without risking HTML/JavaScript injection attacks.

This plugin provides two helper methods for an attribute:
C<attribute_as_stripped_html> which removes all HTML tags, and
C<attribute_as_restricted_html> which removes all but a list of safe
HTML tags. Both are simple accessor methods.

=head1 FUNCTIONS

=over 4

=item C<attr_html $attributes, [%params]>

Package method. Call with the name of the attributes (either a scalar
for a single attribute or an array reference for multiple attributes)
for which the helper methods should be created.

C<%params> can include the following options:

=over 2

=item * C<with_stripped> is a scalar that controls the creation of the
C<attribute_as_stripped_html> method. It is on by default.

=item * C<with_restricted> is a scalar that controls the creation of the
C<attribute_as_restricted_html> method. It is on by default. If it is
on then the parameter C<allowed_tags> contains the tags that are kept
by this method.

=item * C<allowed_tags> must be a hash reference containing the tags
and attributes to keep. It follows the same structural layout as the
C<rules> parameter of L<HTML::Restrict/new>. Only relevant if
C<with_restricted> is trueish. It defaults to allow the following tags
without any attribute safe the trailing slash: C<b i u ul ol li sub
sup strike br p div>.

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
