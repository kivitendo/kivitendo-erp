# @tag: add_file_version
# @description: Versionen für files in extra Tabelle erzeugen
# @depends: release_3_6_0 file_version
package SL::DBUpgrade2::add_file_version;

use strict;
use utf8;

use SL::DB::File;
use SL::File::Backend::Webdav;

use SL::System::Process;

use UUID::Tiny ':std';

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  SL::DB->client->with_transaction(sub {
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

      my @versions = SL::File->get_all_versions(dbfile => $dbfile);
      foreach my $version (@versions) {
        my $tofile = $version->get_file();
        my $rel_file = $tofile;
        $rel_file    =~ s/$doc_path//;

        my $fv = SL::DB::FileVersion->new(
                              file_id       => $dbfile->id,
                              version       => $version->version,
                              file_location => $rel_file,
                              doc_path      => $doc_path,
                              backend       => $dbfile->backend,
                              guid          => create_uuid_as_string(UUID_V4),
                            )->save;
      }
    }
    1;
  }) or do { die SL::DB->client->error };

  return 1;
}

1;
