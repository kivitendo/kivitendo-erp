package SL::Template::Plugin::Base64;

use strict;
use vars qw($VERSION);

$VERSION = 0.01;

use base qw(Template::Plugin);
use Template::Plugin;
use Template::Stash;
use MIME::Base64 ();

$Template::Stash::SCALAR_OPS->{'encode_base64'} = \&_encode_base64;
$Template::Stash::SCALAR_OPS->{'decode_base64'} = \&_decode_base64;

sub new {
  my ($class, $context, $options) = @_;

  $context->define_filter('encode_base64', \&_encode_base64);
  $context->define_filter('decode_base64', \&_decode_base64);
  return bless {}, $class;
}

sub _encode_base64 {
  return MIME::Base64::encode_base64(shift, '');
}

sub _decode_base64 {
  my ($self, $var) = @_;
  return MIME::Base64::decode_base64(shift);
}

1;

__END__

=head1 NAME

SL::Template::Plugin::Base64 - TT2 interface to base64 encoding/decoding

=head1 SYNOPSIS

  [% USE Base64 -%]
  [% SELF.some_object.binary_stuff.encode_base64 -%]
  [% SELF.some_object.binary_stuff FILTER encode_base64 -%]

=head1 DESCRIPTION

The I<Base64> Template Toolkit plugin provides access to the Base64
routines from L<MIME::Base64>.

The following filters (and vmethods of the same name) are installed
into the current context:

=over 4

=item C<encode_base64>

Returns the string encoded as Base64.

=item C<decode_base64>

Returns the Base64 string decoded back to binary.

=back

As the filters are also available as vmethods the following are all
equivalent:

    FILTER encode_base64; content; END;
    content FILTER encode_base64;
    content.encode_base64;

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.de<gt>

=cut
