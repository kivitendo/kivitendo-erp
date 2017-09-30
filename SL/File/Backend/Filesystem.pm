package SL::File::Backend::Filesystem;

use strict;

use parent qw(SL::File::Backend);
use SL::DB::File;
use File::Copy;
use File::Slurp;
use File::Path qw(make_path);

#
# public methods
#

sub delete {
  my ($self, %params) = @_;
  die "no dbfile in backend delete" unless $params{dbfile};
  my $last_version  = $params{dbfile}->backend_data;
  my $first_version = 1;
  $last_version     = 0                               if $params{last};
  $last_version     = $params{dbfile}->backend_data-1 if $params{all_but_notlast};
  $last_version     = $params{version}                if $params{version};
  $first_version    = $params{version}                if $params{version};

  if ($last_version > 0 ) {
    for my $version ( $first_version..$last_version) {
      my $file_path = $self->_filesystem_path($params{dbfile},$version);
      unlink($file_path);
    }
    if ($params{version}) {
      for my $version ( $last_version+1 .. $params{dbfile}->backend_data) {
        my $from = $self->_filesystem_path($params{dbfile},$version);
        my $to   = $self->_filesystem_path($params{dbfile},$version - 1);
        die "file not exists in backend delete" unless -f $from;
        rename($from,$to);
      }
      $params{dbfile}->backend_data($params{dbfile}->backend_data-1);
    }
    elsif ($params{all_but_notlast}) {
      my $from = $self->_filesystem_path($params{dbfile},$params{dbfile}->backend_data);
      my $to   = $self->_filesystem_path($params{dbfile},1);
      die "file not exists in backend delete" unless -f $from;
      rename($from,$to);
      $params{dbfile}->backend_data(1);
    } else {
      $params{dbfile}->backend_data(0);
    }
    unless ($params{dbfile}->backend_data) {
      my $dir_path = $self->_filesystem_path($params{dbfile});
      rmdir($dir_path);
    }
  } else {
    my $file_path = $self->_filesystem_path($params{dbfile},$params{dbfile}->backend_data);
    die "file not exists in backend delete" unless -f $file_path;
    unlink($file_path);
    $params{dbfile}->backend_data($params{dbfile}->backend_data-1);
  }
  return 1;
}

sub rename {
}

sub save {
  my ($self, %params) = @_;
  die 'dbfile not exists' unless $params{dbfile};
  my $dbfile = $params{dbfile};
  die 'no file contents' unless $params{file_path} || $params{file_contents};
  $dbfile->backend_data(0) unless $dbfile->backend_data;
  $dbfile->backend_data($dbfile->backend_data*1+1);
  $dbfile->save->load;

  my $tofile = $self->_filesystem_path($dbfile);
  if ($params{file_path} && -f $params{file_path}) {
    File::Copy::copy($params{file_path}, $tofile);
  }
  elsif ($params{file_contents}) {
    open(OUT, "> " . $tofile);
    print OUT $params{file_contents};
    close(OUT);
  }
  if ($params{mtime}) {
    utime($params{mtime}, $params{mtime}, $tofile);
  }
  return 1;
}

sub get_version_count {
  my ($self, %params) = @_;
  die "no dbfile" unless $params{dbfile};
  return $params{dbfile}->backend_data * 1;
}

sub get_mtime {
  my ($self, %params) = @_;
  die "no dbfile" unless $params{dbfile};
  die "unknown version" if $params{version} &&
                          ($params{version} < 0 || $params{version} > $params{dbfile}->backend_data);
  my $path = $self->_filesystem_path($params{dbfile}, $params{version});

  die "No file found at $path. Expected: $params{dbfile}{file_name}, file.id: $params{dbfile}{id}" if !-f $path;

  my @st = stat($path);
  my $dt = DateTime->from_epoch(epoch => $st[9], time_zone => $::locale->get_local_time_zone()->name, locale => $::lx_office_conf{system}->{language})->clone();
  return $dt;
}

sub get_filepath {
  my ($self, %params) = @_;
  die "no dbfile" unless $params{dbfile};
  my $path = $self->_filesystem_path($params{dbfile},$params{version});
  die "no file in backend get_filepath" if !-f $path;
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
  my ($self, %params) = @_;
  my @query = (file_type => $params{file_type});
  push @query, (file_name => $params{file_name}) if $params{file_name};
  push @query, (mime_type => $params{mime_type}) if $params{mime_type};
  push @query, (source    => $params{source})    if $params{source};

  my $sortby = $params{sort_by} || 'itime DESC,file_name ASC';

  my @files = @{ SL::DB::Manager::File->get_all(query => [@query], sort_by => $sortby) };
  for (@files) {
    $main::lxdebug->message(LXDebug->DEBUG2(), "file id=" . $_->id." version=".$_->backend_data);
    my $newversion = $_->backend_data;
    for my $version ( reverse 1 .. $_->backend_data ) {
      my $path = $self->_filesystem_path($_, $version);
      $main::lxdebug->message(LXDebug->DEBUG2(), "path=".$path." exists=".( -f $path?1:0));
      last if -f $path;
      $newversion = $version - 1;
    }
    $main::lxdebug->message(LXDebug->DEBUG2(), "newversion=".$newversion." version=".$_->backend_data);
    if ( $newversion < $_->backend_data ) {
      $_->backend_data($newversion);
      $_->save   if $newversion >  0;
      $_->delete if $newversion <= 0;
    }
  }

}

#
# internals
#

sub _filesystem_path {
  my ($self, $dbfile, $version) = @_;

  die "No files backend enabled" unless $::instance_conf->get_doc_files || $::lx_office_conf{paths}->{document_path};

  # use filesystem with depth 3
  $version    = $dbfile->backend_data if !$version || $version < 1 || $version > $dbfile->backend_data;
  my $iddir   = sprintf("%04d", $dbfile->id % 1000);
  my $path    = File::Spec->catdir($::lx_office_conf{paths}->{document_path}, $::auth->client->{id}, $iddir, $dbfile->id);
  if (!-d $path) {
    File::Path::make_path($path, { chmod => 0770 });
  }
  return $path if !$version;
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
