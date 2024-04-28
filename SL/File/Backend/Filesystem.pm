package SL::File::Backend::Filesystem;

use strict;

use parent qw(SL::File::Backend);
use SL::DB::File;
use SL::DB::FileVersion;

use Carp;
use List::Util qw(first);

use File::Copy;
use File::Slurp;
use File::stat;
use File::Path qw(make_path);
use UUID::Tiny ':std';

#
# public methods
#

sub delete {
  my ($self, %params) = @_;
  die "no dbfile in backend delete" unless $params{dbfile};

  my @versions_to_delete;
  if ($params{file_version}) {
    croak "file_version has to be of type SL::DB::FileVersion"
      unless ref $params{file_version} eq 'SL::DB::FileVersion';
    @versions_to_delete = ($params{file_version});
  } else {
    my @versions = @{$params{dbfile}->file_versions_sorted};
    if ($params{last}) {
      my $last = pop @versions;
      @versions_to_delete = ($last);
    } elsif ($params{all_but_notlast}) {
      pop @versions; # remove last
      @versions_to_delete = @versions;
    } else {
      @versions_to_delete = @versions;
    }
  }

  foreach my $version (@versions_to_delete) {
    unlink($version->get_system_location());
    $version->delete;
  }

  return 1;
}

sub rename {
}

sub save {
  my ($self, %params) = @_;

  die 'dbfile not exists' unless ref $params{dbfile} eq 'SL::DB::File';
  die 'no file contents'  unless $params{file_path} || $params{file_contents};

  my $dbfile = delete $params{dbfile};

  # Do not save and do not create a new version of the document if file size of last version is the same.
  if ($dbfile->source eq 'created' && $self->get_version_count(dbfile => $dbfile)) {
    my $new_file_size  = $params{file_path} ? stat($params{file_path})->size : length($params{file_contents});
    my $last_file_size = stat($self->_filesystem_path($dbfile))->size;

    return 1 if $last_file_size == $new_file_size;
  }

  my @versions = @{$dbfile->file_versions_sorted};
  my $new_version_number = scalar @versions ? $versions[-1]->version + 1 : 1;

  my $tofile = $self->_filesystem_path($dbfile, $new_version_number);
  if ($params{file_path} && -f $params{file_path}) {
    File::Copy::copy($params{file_path}, $tofile);
  } elsif ($params{file_contents}) {
    open(OUT, "> " . $tofile);
    print OUT $params{file_contents};
    close(OUT);
  }

  # save file version
  my $doc_path = $::lx_office_conf{paths}->{document_path};
  my $rel_file = $tofile;
  $rel_file    =~ s/$doc_path//;
  my $fv = SL::DB::FileVersion->new(
    file_id       => $dbfile->id,
    version       => $new_version_number,
    file_location => $rel_file,
    doc_path      => $doc_path,
    backend       => 'Filesystem',
    guid          => create_uuid_as_string(UUID_V4),
  )->save;

  if ($params{mtime}) {
    utime($params{mtime}, $params{mtime}, $tofile);
  }
  return 1;
}

sub get_version_count {
  my ($self, %params) = @_;
  die "no dbfile" unless $params{dbfile};
  my $file_id = $params{dbfile}->id;
  return 0 unless defined $file_id;
  return SL::DB::Manager::FileVersion->get_all_count(where => [file_id => $file_id]);
}

sub get_mtime {
  my ($self, %params) = @_;
  my $path = $self->get_filepath(%params);

  my $dt = DateTime->from_epoch(epoch => stat($path)->mtime, time_zone => $::locale->get_local_time_zone()->name, locale => $::lx_office_conf{system}->{language})->clone();
  return $dt;
}

sub get_filepath {
  my ($self, %params) = @_;
  die "no dbfile" unless $params{dbfile};
  my $path = $self->_filesystem_path($params{dbfile},$params{version});

  die "No file found at $path. Expected: $params{dbfile}{file_name}, file.id: $params{dbfile}{id}" if !-f $path;

  return $path;
}

sub get_content {
  my ($self, %params) = @_;
  my $path = $self->get_filepath(%params);
  return "" unless $path;
  my $contents = File::Slurp::read_file($path);
  return \$contents;
}

sub enabled {
  return 0 unless $::instance_conf->get_doc_files;
  return 0 unless $::lx_office_conf{paths}->{document_path};
  return 0 unless -d $::lx_office_conf{paths}->{document_path};
  return 1;
}

sub sync_from_backend {
  die "Not implemented";
}

#
# internals
#

sub _filesystem_path {
  my ($self, $dbfile, $version) = @_;

  die "No files backend enabled" unless $::instance_conf->get_doc_files || $::lx_office_conf{paths}->{document_path};

  unless ($version) {
    my $file_version = SL::DB::Manager::FileVersion->get_first(
      where   => [file_id => $dbfile->id],
      sort_by => 'version DESC'
    ) or die "Could not find a file version for file with id " . $dbfile->id;
    $version = $file_version->version;
  }

  # use filesystem with depth 3
  my $iddir   = sprintf("%04d", $dbfile->id % 1000);
  my $path    = File::Spec->catdir($::lx_office_conf{paths}->{document_path}, $::auth->client->{id}, $iddir, $dbfile->id);
  if (!-d $path) {
    File::Path::make_path($path, { chmod => 0770 });
  }
  return File::Spec->catdir($path, $dbfile->id . '_' . $version);
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::File::Backend::Filesystem  - Filesystem class for file storage backend

=head1 SYNOPSIS

See the synopsis of L<SL::File::Backend>.

=head1 OVERVIEW

This specific storage backend use a Filesystem which is only accessed by this interface.
This is the big difference to the Webdav backend where the files can be accessed without the control of that backend.
This backend use the database id of the SL::DB::File object as filename. The filesystem has up to 1000 subdirectories
to store the files not to flat in the filesystem. In this Subdirectories for each file an additional subdirectory exists
for the versions of this file.

The Versioning is done via a Versionnumber which is incremented by one for each version.
So the Version 2 of the file with the database id 4 is stored as path {root}/0004/4/4_2.


=head1 METHODS

See methods of L<SL::File::Backend>.

=head1 SEE ALSO

L<SL::File::Backend>

=head1 AUTHOR

Martin Helmling E<lt>martin.helmling@opendynamic.deE<gt>

=cut
