package SL::HTML::Restrict;

use strict;
use warnings;

use HTML::Restrict ();

sub create {
  my ($class, %params)    = @_;
  $params{allowed_tags} //= { map { ($_ => ['/']) } qw(b strong i em u ul ol li sub sup s strike br p div) };

  return HTML::Restrict->new(rules => $params{allowed_tags});
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::HTML::Restrict - Restrict HTML tags to set of allowed tags

=head1 SYNOPSIS

  my $cleaner = SL::HTML::Restrict->create;
  my $cleaned = $cleaner->process($unsafe_html);

=head1 DESCRIPTION

Often you want to allow a fixed set of well-known HTML tags to be used
– but nothing else. This is a thin wrapper providing a default set of
the following elements:

C<b br div em i li ol p s strike strong sub sup u ul>

This list can be overwritten.

=head1 FUNCTIONS

=over 4

=item C<create [%params]>

Creates and returns a new instance of L<HTML::Restrict>. The optional
parameter C<allowed_tags> must be an array reference of allowed tag
names. If it's missing then the default set will be used (see above).

Returns an instance of L<HTML::Restrict>.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
