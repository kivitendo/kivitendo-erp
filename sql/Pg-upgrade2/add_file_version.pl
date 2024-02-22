# @tag: add_file_version
# @description: Versionen für files in extra Tabelle erzeugen
# @depends: release_3_8_0 file_version files_add_uid
package SL::DBUpgrade2::add_file_version;

use strict;
use utf8;

use SL::DB::File;
use SL::File::Backend::Webdav;

use SL::System::Process;

use UUID::Tiny ':std';

use parent qw(SL::DBUpgrade2::Base);

sub get_all_versions {
  my ($fileobj) = @_;

  my @versionobjs;

  my $maxversion = $fileobj->version_count;
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
}

sub run {
  my ($self) = @_;

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
          $tofile = $version->get_file();
        } or do {
          my @values;
          push @values, $@; # error message
          push @values, $version->file_name;
          push @values, $version->id;
          push @errors, '<td>' . join('</td><td>', @values) . '</td>';;
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
    if (scalar @errors) {
      my $error_message = 'Please resolve the errors by removing invalid database entries or by adding the corresponding files under the expected paths:
      <table class="tbl-list" border="1" style="border-collapse: collapse">
        <thead><tr>
          <th>error message</th>
          <th>file_name</th>
          <th>file_id</th>
        </tr></thead>
      ';
      $error_message .= '<tr>' . join('</tr><tr>', @errors) . '</tr>';
      $error_message .= '</table>';
      die $error_message;
    }
    1;
  }) or do { die SL::DB->client->error };

  return 1;
}

1;
