# @tag: filemanagement_filesystem
# @description: add  directory for filemanagment
# @depends: filemanagement_feature
package SL::DBUpgrade2::filemanagement_filesystem;

use strict;
use utf8;
use File::Path qw(make_path);

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  my $directory = $::instance_conf->get_doc_files_rootpath;

  if ( $directory && !-d $directory ) {
    mkdir $directory;
    if (! -d $directory) {
      return 0;
    }
  }
  return 1;
}

1;
