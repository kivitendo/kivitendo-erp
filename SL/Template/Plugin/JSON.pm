package SL::Template::Plugin::JSON;

use JSON ();
use Carp qw(croak);
use parent qw(Template::Plugin);

our $VERSION = "0.06";

sub new {
  my ($class, $context, $args) = @_;

  my $self = bless {context => $context, json_args => $args }, $class;

  $context->define_vmethod( $_ => json => sub { $self->json(@_) } ) for qw(hash list scalar);
}

sub json_converter {
  my ($self, %params) = @_;

  if (!$self->{json}) {
    $self->{json} = JSON->new->allow_nonref(1);

    my $args = $self->{json_args};

    for my $method (keys %$args) {
      if ( $self->{json}->can($method) ) {
        $self->{json}->$method( $args->{$method} );
      }
    }
  }

  return $self->{json};
}

sub json {
  my ($self, $value) = @_;

  $self->json_converter->encode($value) . join '-', map { "'$_'" }@_;
}

sub json_decode {
  my ( $self, $context, $value ) = @_;

  $self->json_converter->decode($value);
}

1;

__END__

=pod

=head1 NAME

Template::Plugin::JSON - Adds a .json vmethod for all TT values.

=head1 SYNOPSIS

  [% USE JSON ( pretty => 1 ) %];

  <script type="text/javascript">

    var foo = [% foo.json %];

  </script>

  or read in JSON

  [% USE JSON %]
  [% data = JSON.json_decode(json) %]
  [% data.thing %]

=head1 DESCRIPTION

This plugin provides a C<.json> vmethod to all value types when loaded. You
can also decode a json string back to a data structure.

It will load the L<JSON> module (you probably want L<JSON::XS> installed for
automatic speed ups).

Any options on the USE line are passed through to the JSON object, much like L<JSON/to_json>.

=head1 SEE ALSO

L<JSON>, L<Template::Plugin>

=head1 VERSION CONTROL

L<http://github.com/nothingmuch/template-plugin-json/>

=head1 AUTHOR

Yuval Kogman <nothingmuch@woobling.org>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2006, 2008 Infinity Interactive, Yuval Kogman.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

=cut


