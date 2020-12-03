package SL::Response;

use strict;
use parent qw(Rose::Object);
use Carp;
use SL::MoreCommon qw(listify);

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(status location content_type) ],
  'scalar --get_set_init' => [ qw(cookie) ],
);

my %status_codes = (
  200 => 'OK',
  201 => 'Created',
  202 => 'Accepted',
  302 => 'Found',
  303 => 'See Other',
  307 => 'Temporary Redirect',
  401 => 'Unauthorized',
  403 => 'Forbidden',
  404 => 'Not Found',
  418 => "I'm a teapot",
);

my %supported_generic_header_fields = (
  charset             => 'Charset',
  content_length      => 'Content-Length',
  transfer_encoding   => 'Transfer-Encoding',
  connection          => 'Connection',
);

my %cookie_args = (
  domain    => 1,
  path      => 1,
  expires   => 1,
  samesite  => 1,
  "max-age" => 1,
  secure    => 0,
  HttpOnly  => 0,
);

my $crlf = "\015\012";

sub header {
  my ($self, %header) = @_;

  my @header;

  # these three must come first
  my $content_type = delete $header{content_type} // $self->content_type;
  push @header, "Content-Type: $content_type" if defined $content_type;

  my $status = delete $header{status} // $self->status;
  croak "Unsupported HTTP Status: $status" if defined $status && !$status_codes{$status};
  push @header, "Status: $status $status_codes{$status}" if defined $status;

  my $location = delete $header{location} // $self->location;
  push @header, "Location: $location" if defined $location;

  # handle more than one cookie
  my @cookies = (listify(delete $header{cookie}), listify($self->cookie));
  push @header, "Set-Cookie: $_" for grep defined, @cookies;

  # content-disposition has some weird syntax from RFC1806
  my $attachment = delete $header{attachment};
  push @header, qq|Content-Disposition: attachment; filename="$attachment"| if defined $attachment;

  # process the rest
  for my $field (keys %header) {
    my $keyword = $supported_generic_header_fields{$field} or croak "unknown header '$field'";
    push @header, "$keyword: $header{$field}";
  }

  return join $crlf, @header, '', '';
}

sub redirect {
  my ($self, $url, %params) = @_;
  $self->header(%params, status => 302, location => $url);
}

sub add_cookie {
  my ($self, $name, $value, %args) = @_;

  # we don't care that cookies can have more than one value. if you need it, implement it.
  # we also don't care that technically you have to url encode cookies. simply don't put unicode in cookies.

  my @cookie = "$name=$value";

  for (keys %args) {
    my $need_argument = $cookie_args{$_};
    croak "unknown cookie argument '$_'" unless defined $need_argument;
    push @cookie, $need_argument ? "$_=$args{$_}" : (($_) x !!$args{$_});
  }

  push @{ $self->{cookie} //= [] }, join '; ', @cookie;
}

sub init_cookie { [] }

1;

__END__

=encoding utf-8

=head1 NAME

SL::Response - reponse helper and aggregator

=head1 SYNOPSIS

  use SL::Response;
  my $r = SL::Respone->new

  $r->add_cookie("name", "value", secure => 1, path => $path);
  $r->redirect($url);
  $r->header(
    content_type => 'text/html',
    charset      => 'UTF-8',
    ...
  );

  $r->content_type('text/json');
  $r->status(502);
  $r->header;

=head1 DESCRIPTION

Introduced mainly to get rid of L<CGI.pm>. Also meant to abstract response
header generation, and one day maybe be able to handle all STDOUT printing.
After that we can add more bindings to PSGI or a standalone server.

=head1 ATTRIBUTES

=over 4

=item * C<status>

=item * C<location>

=item * C<content_type>

These three are used for the upcoming response and can be set beforehand.

=item * C<cookie>

Aggregator for cookies. Returns an arrayref. Should be filled with
L</add_cookie>. Aggregated cookies will be added to all generated headers,
including redirects.

=back

=head1 METHODS

=over 4

=item * C<header PARAMS>

Generates a header and returns it as octet stream.

Known arguments:

=over 4

=item * C<content_type>

Corresponds to C<Content-Type>

=item * C<status>

Corresponds to C<Status>

=item * C<location>

Corresponds to C<Location>

=item * C<cookie>

Corresponds to C<Set-Cookie>. Can be arrayref or single value but must contain
valid arguments for the HTTP C<Set-Cookie> header. If cookies have been added
to the response object before, both will be added.

=item * C<attachment>

Corresponds to C<Content-Disposition: attachemnt>. The argument will be added as the filename.

=item * C<charset>

Corresponds to C<Charset>

=item * C<content_length>

Corresponds to C<Content-Length>

=item * C<transfer_encoding>

Corresponds to C<Transfer-Encoding>

=item * C<connection>

Corresponds to C<Connection>

=back

=item * C<redirect URL PARAMS>

Calls header with status code 302 and the location specified by the C<url>
parameter.

=item * C<add_cookie PARAMS>

=back

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@googlemail.comE<gt>

=cut
