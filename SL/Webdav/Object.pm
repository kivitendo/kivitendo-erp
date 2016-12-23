package SL::Webdav::Object;

use strict;
use parent qw(Rose::Object);

use DateTime;

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(filename webdav) ],
  'scalar --get_set_init' => [ qw(version basename extension) ],
);

sub init_basename {
  ($_[0]->parse_filename)[0];
}

sub init_version {
  ($_[0]->parse_filename)[1];
}

sub init_extension {
  ($_[0]->parse_filename)[2];
}

sub parse_filename {
  my ($self) = @_;

  my $name = $self->filename;
  my $version_re = $self->webdav->version_scheme->extract_regexp;
  my $sep        = $self->webdav->version_scheme->separator;

  my $extension = $name =~ s/\.(\w+?)$//              ? $1 : '';
  my $version   = $name =~ s/\Q$sep\E($version_re)$// ? $1 : '';
  my $basename  = $name;

  return ($basename, $version, $extension);
}

sub full_filedescriptor {
  my ($self) = @_;

  File::Spec->catfile($self->webdav->webdav_path, $self->filename);
}

sub atime {
  DateTime->from_epoch(epoch => ($_[0]->stat)[8]);
}

sub mtime {
  DateTime->from_epoch(epoch => ($_[0]->stat)[9]);
}

sub data {
  my ($self) = @_;

  open my $fh, '<:raw', $self->full_filedescriptor or die "could not open " . $self->filename . ": $!";

  local $/ = undef;

  my $data = <$fh>;

  close $fh;

  return \$data;
}

sub stat {
  my $file = $_[0]->full_filedescriptor;
  stat($file);
}

sub href {
  my ($self) = @_;

  my $base_path = $ENV{'SCRIPT_NAME'};
  $base_path =~ s|[^/]+$||;

  my $file         = $self->filename;
  my $path         = $self->webdav->webdav_path;
  my $is_directory = -d "$path/$file";

  $file  = join('/', map { $::form->escape($_) } grep { $_ } split m|/+|, "$path/$file");
  $file .=  '/' if ($is_directory);

  return "$base_path/$file";
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Webdav::Object - Webdav object wrapper

=head1 SYNOPSIS

  use SL::Webdav::Object;

  my $object = SL::Webdav::Object->new(filename => $filename, webdav => $webdav);

  my $data_ref  = $object->data;
  my $mtime     = $object->mtime;

  my $basename  = $object->basename;
  my $version   = $object->version;
  my $extension = $object->extension;

  my $link      = $object->href;

=head1 DESCRIPTION

This is a wrapper around a single object in the webdav. These objects are
thought about as immutable, and all manipulation will instead happen in the
associated L<SL::Webdav::File>.

=head1 FUNCTIONS

=over 4

=item C<basename>

Returns the basename with version and extension stripped.

=item C<version>

Returns the version string.

=item C<extension>

Returns the extension.

=item C<atime>

L<DateTime> wrapped stat[8]

=item C<mtime>

L<DateTime> wrapped stat[9]

=item C<data>

Ref to the actual data in raw encoding.

=item C<href>

URL relative to the web base dir for download.

=item C<full_filedescriptor>

Fully qualified path to file.

=back

=head1 SEE ALSO

L<SL::Webdav>, L<SL::Webdav::File>

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
