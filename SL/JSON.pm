package SL::JSON;

use strict;

use JSON ();

use parent qw(Exporter);
our @EXPORT = qw(encode_json decode_json to_json from_json);

sub new {
  shift;
  return JSON->new(@_)->convert_blessed(1);
}

sub encode_json {
  return JSON->new->convert_blessed(1)->encode(@_);
}

sub decode_json {
  goto &JSON::decode_json;
}

sub to_json {
  my ($object, $options)      = @_;
  $options                  ||= {};
  $options->{convert_blessed} = 1;
  return JSON::to_json($object, $options);
}

sub from_json {
  goto &JSON::from_json;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::JSON - Thin wrapper around the JSON module that provides default options

=head1 SYNOPSIS

  use SL::JSON;

  my $escaped_text_object = SL::Presenter->get->render('some/template');
  my $json = encode_json($escaped_text_object);

=head1 OVERVIEW

JSON by default does not dump or stringify blessed
objects. kivitendo's rendering infrastructure always returns thin
proxy objects as instances of L<SL::Presenter::EscapedText>. This
module provides the same functions that L<JSON> does but changes their
default regarding converting blessed arguments.

=head1 FUNCTIONS

=over 4

=item C<decode_json $json>

Same as L<JSON/decode_json>.

=item C<encode_json $object>

Same as L<JSON/encode_json> but sets C<convert_blessed> first.

=item C<from_json $object [, $options]>

Same as L<JSON/from_json>.

=item C<to_json $object [, $options ]>

Same as L<JSON/to_json> but sets C<convert_blessed> first.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
