package SL::Webdav::File;

use strict;
use parent qw(Rose::Object);

use File::Spec;
use File::Copy ();
use Carp;

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(webdav filename loaded) ],
  array  => [
    qw(objects),
    add_objects => { interface => 'push', hash_key => 'objects' },
  ],
);

sub versions {
  $_[0]->load unless $_[0]->loaded;
  my $cmp = $_[0]->webdav->version_scheme->cmp;
  sort { $cmp->($a, $b) } $_[0]->objects;
}

sub latest_version {
  ($_[0]->versions)[-1]
}

sub load {
  my ($self) = @_;
  my @objects = $self->webdav->get_all_objects;
  my $ref = SL::Webdav::Object->new(filename => $self->filename, webdav => $self->webdav);
  my ($ref_basename, undef, $ref_extension) = $ref->parse_filename;

  $self->objects(grep { $_->basename eq $ref_basename && $_->extension eq $ref_extension } @objects);
  $self->loaded(1);
}

sub store {
  my ($self, %params) = @_;

  croak 'Invalid call. Only data or file can be set' if ($params{data} && $params{file});

  $self->load unless $self->loaded;

  my $last = $self->latest_version;
  my $object;

  if (!$last) {
    my ($basename, undef, $extension) = SL::Webdav::Object->new(filename => $self->filename, webdav => $self->webdav)->parse_filename;
    my $new_version  = $self->webdav->version_scheme->first_version;
    my $sep          = $self->webdav->version_scheme->separator;
    my $new_filename = $basename . $sep . $new_version . "." . $extension;
    $object = SL::Webdav::Object->new(filename => $new_filename, webdav => $self->webdav);

    $self->add_objects($object);
  } else {
    if (!$self->webdav->version_scheme->keep_last_version($last)) {
      $params{new_version} = 1;
    }

    # Do not create a new version of the document if file size of last version is the same.
    if ($params{new_version}) {
      my $last_file_size = $last->size;
      my $new_file_size;
      if ($params{file}) {
        croak 'No valid file' unless -f $params{file};
        $new_file_size  = (stat($params{file}))[7];
      } else {
        $new_file_size  = length(${ $params{data} });
      }
      $params{new_version} = 0 if $last_file_size == $new_file_size;
    }

    if ($params{new_version}) {
      my $new_version  = $self->webdav->version_scheme->next_version($last);
      my $sep          = $self->webdav->version_scheme->separator;
      my $new_filename = $last->basename . $sep . $new_version . "." . $last->extension;
      $object = SL::Webdav::Object->new(filename => $new_filename, webdav => $self->webdav);

      $self->add_objects($object);
    } else {
      $object = $last;
    }
  }

  if ($params{file}) {
    croak 'No valid file' unless -f $params{file};
    File::Copy::copy($params{file}, $object->full_filedescriptor) or croak "Copy failed from $params{file} to @{[ $object->filename ]}: $!";
  } else {

    open my $fh, '>:raw', $object->full_filedescriptor or die "could not open " . $object->filename . ": $!";

    $fh->print(${ $params{data} });

    close $fh;
  }


  return $object;
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Webdav::File - Webdav file manipulation

=head1 SYNOPSIS

  use SL::Webdav::File;

  my $webdav_file = SL::Webdav::File->new(
    webdav   => $webdav,  # SL::Webdav instance
    filename => 'technical_drawing_AB28375.pdf',
  );

  # get existing versioned files
  my @webdav_objects = $webdav_file->versions;

  # store new version
  my $data = SL::Helper::CreatePDF->create_pdf(...);
  my $webdav_object = $webdav_file->store(data => \$data);

  # use file instead of data
  my $webdav_object = $webdav_file->store(file => $path_to_file);

  # force new version
  my $webdav_object = $webdav_file->store(data => \$data, new_version => 1);

=head1 DESCRIPTION

A file in this context is the collection of all versions of a single file saved
into the webdav. This module provides methods to access and manipulate these
objects.

=head1 FUNCTIONS

=over 4

=item C<versions>

Will return all L<SL::Webdav::Object>s found in this file, sorted by version
according to the version scheme used.

=item C<latest_version>

Returns only the latest version object.

=item C<load>

Loads objects from disk.

=item C<store PARAMS>

Store a new version on disk. If C<data> is present, it is expected to contain a
reference to the data to be written in raw encoding.

If C<file> is a valid filename then it will be copied.

C<file> and C<data> are exclusive.

If param C<new_version> is set, force a new version, even if the versioning
scheme would keep the old one.

No new version is stored if the file or data size is euqal to the size of
the last stored version.

=back

=head1 SEE ALSO

L<SL::Webdav>, L<SL::Webdav::Object>

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
