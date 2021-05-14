package SL::System::ResourceCache;

use strict;
use File::stat;
use File::Find;

our @paths = qw(image css);
our $cache;

sub generate_data {
  return if $cache;

  $cache = {};

  File::Find::find(sub {
    $cache->{ $File::Find::name =~ s{^\./}{}r } = stat($_);
  }, @paths);
}

sub get {
  my ($class, $file) = @_;
  no warnings 'once';

  return stat($file) if ($::dispatcher // { interface => 'cgi' })->{interface} eq 'cgi';

  $class->generate_data;
  $cache->{$file};
}

1;


__END__

=encoding utf-8

=head1 NAME

SL::System::ResourceCache - provides access to resource files without having to access the filesystem all the time

=head1 SYNOPSIS

  use SL::System::ResourceCache;

  SL::System::ResourceCache->get($filename);

=head1 DESCRIPTION

This will stat() all files in the configured paths at startup once, so that
subsequent calls can use the cached values. Particularly useful for icons in
the menu, which would otherwise generate a few hundred file sytem accesses per
request.

The caching will not happen in CGI and script environments.

=head1 FUNCTIONS

=over 4

=item * C<get FILENAME>

If the file exists, returns a L<File::stat> object. If it doesn't exists, returns undef.

=back

=head1 BUGS

None yet :)

=head1 TODO

Make into instance cache and keep it as system wide object

=head1 AUTHOR

Sven Schöling E<lt>sven.schoeling@googlemail.comE<gt>

=cut

