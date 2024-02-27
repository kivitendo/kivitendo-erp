# @tag: add_file_version
# @description: Versionen für files in extra Tabelle erzeugen
# @depends: release_3_8_0 file_version files_add_uid
package SL::DBUpgrade2::add_file_version;

use strict;
use utf8;

use SL::DB::File;
use SL::File::Backend::Webdav;

use SL::Locale::String qw(t8);
use SL::System::Process;

use UUID::Tiny ':std';

use parent qw(SL::DBUpgrade2::Base);

sub get_all_versions {
  my ($dbfile) = @_;

  my @versionobjs;
  my $fileobj = SL::File::Object->new(
    db_file => $dbfile,
    id => $dbfile->id,
    loaded => 1,
  );

  my $maxversion = $fileobj->backend eq 'Filesystem' ? $fileobj->db_file->backend_data : 1;
  $fileobj->version($maxversion);
  push @versionobjs, $fileobj;
  if ($maxversion > 1) {
    for my $version (2..$maxversion) {
      my $clone = $fileobj->clone;
      $clone->version($maxversion-$version+1);
      $clone->newest(0);
      push @versionobjs, $clone;
    }
  }

  return @versionobjs;
}

sub get_filepath {
  my ($file_obj) = @_;

  my $file_id = $file_obj->id;
  my $backend = $file_obj->backend
    or die "File with ID '$file_id' has no backend specified.";
  my $db_file   = $file_obj->db_file;
  my $file_name = $file_obj->file_name;
  my $version   = $file_obj->version;

  my $path;
  if ($backend eq 'Webdav') {
    ($path) = $file_obj->backend_class->webdav_path($db_file);
  } elsif ($backend eq 'Filesystem') {
    # use filesystem with depth 3
    my $iddir   = sprintf("%04d", $db_file->id % 1000);
    my $base_path    = File::Spec->catdir($::lx_office_conf{paths}->{document_path}, $::auth->client->{id}, $iddir, $db_file->id);
    $path = File::Spec->catdir($base_path, $db_file->id . '_' . $version);
  } else {
    die "Unknown backend '$backend' for file with ID '$file_id'.";
  }

  die "No file found at $path. Expected: $file_name, file.id: $file_id" if !-f $path;
  return $path;
}

sub test_all_files_exists {
  my @errors;

  my $all_dbfiles = SL::DB::Manager::File->get_all;

  foreach my $dbfile (@{$all_dbfiles}) {
    my @versions = get_all_versions($dbfile);
    foreach my $version (@versions) {
      eval {
        get_filepath($version);
      } or do {
        push @errors, $@;
      }
    }
  }

  return @errors;
}

sub print_errors {
  my ($self, $errors) = @_;

  print $::form->parse_html_template("dbupgrade/add_file_version_form", {
      ERRORS => $errors
    });
}

sub run {
  my ($self) = @_;

  my $query = <<SQL;
SELECT f.id
FROM files f
FULL OUTER JOIN file_versions fv ON (f.id = fv.file_id)
GROUP BY f.id
HAVING count(fv.file_id) = 0
SQL
  my @file_ids_without_version = map {$_->[0]} @{$self->dbh->selectall_arrayref($query)};

  unless ($::form->{delete_file_entries_of_missing_files}) {
    my @errors = $self->test_all_files_exists();
    if (scalar @errors) {
      $self->print_errors(\@errors);
      return 2;
    }
  }

  SL::DB->client->with_transaction(sub {
    my @errors;
    my $all_dbfiles = SL::DB::Manager::File->get_all;
    foreach my $dbfile (@$all_dbfiles) {
      my $file_id = $dbfile->id;
      my $backend = $dbfile->backend
        or die "File with ID '$file_id' has no backend specified.";

      my $doc_path;
      if ($backend eq 'Webdav') {
        $doc_path = SL::File::Backend::Webdav::get_rootdir();
      } elsif ($backend eq 'Filesystem') {
        $doc_path = $::lx_office_conf{paths}->{document_path};
      } else {
        die "Unknown backend '$backend' for file with ID '$file_id'.";
      }

      my @versions = get_all_versions($dbfile);
      foreach my $version (@versions) {
        my $tofile;
        eval {
          $tofile = get_filepath($version);
        } or do {
          next;
        };
        my $rel_file = $tofile;
        $rel_file    =~ s/$doc_path//;

        my $fv = SL::DB::FileVersion->new(
          file_id       => $dbfile->id,
          version       => $version->version || 1,
          file_location => $rel_file,
          doc_path      => $doc_path,
          backend       => $dbfile->backend,
          guid          => create_uuid_as_string(UUID_V4),
        )->save;
      }
    }

    my $query = <<SQL;
SELECT f.id
FROM files f
FULL OUTER JOIN file_versions fv ON (f.id = fv.file_id)
GROUP BY f.id
HAVING count(fv.file_id) = 0
SQL
    my @file_ids_without_version =
      map {$_->[0]}
      @{SL::DB::->client->dbh->selectall_arrayref($query)};
    if (scalar @file_ids_without_version) {
      if ($::form->{delete_file_entries_of_missing_files}) {
        SL::DB::Manager::File->delete_all(where => [id => \@file_ids_without_version]);
      } else {
        die "Files without versions: " . join(', ', @file_ids_without_version);
      }
    }

    1;
  }) or do { die SL::DB->client->error };

  return 1;
}

1;
