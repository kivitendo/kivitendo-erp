package SL::File::Object;

use strict;
use parent qw(Rose::Object);
use DateTime;

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw() ],
  'scalar --get_set_init' => [ qw(db_file loaded id version newest) ],
);

#use SL::DB::Helper::Attr;
#__PACKAGE__->_as_timestamp('mtime');
# wie wird das mit dem Attr Helper gemacht damit er bei nicht DB Objekten auch geht?

sub mtime_as_timestamp_s {
  $::locale->format_date_object($_[0]->mtime, precision => 'second');
}

# wrapper methods

sub itime {
  $_[0]->loaded_db_file->itime;
}

sub file_name {
  $_[0]->loaded_db_file->file_name;
}

sub file_type {
  $_[0]->loaded_db_file->file_type;
}

sub object_type {
  $_[0]->loaded_db_file->object_type;
}

sub object_id {
  $_[0]->loaded_db_file->object_id;
}

sub mime_type {
  $_[0]->loaded_db_file->mime_type;
}

sub file_title {
  $_[0]->loaded_db_file->title;
}

sub file_description {
  $_[0]->loaded_db_file->description;
}

sub backend {
  $_[0]->loaded_db_file->backend;
}

sub source {
  $_[0]->loaded_db_file->source;
}

# methods to go directly into the backends

sub get_file {
  $_[0]->backend_class->get_filepath(dbfile => $_[0]->loaded_db_file, version => $_[0]->version)
}

sub get_content {
  $_[0]->backend_class->get_content(dbfile => $_[0]->loaded_db_file,  version => $_[0]->version)
}

sub mtime {
  $_[0]->backend_class->get_mtime(dbfile => $_[0]->loaded_db_file, version => $_[0]->version)
}

sub version_count {
  $_[0]->backend_class->get_version_count(dbfile => $_[0]->loaded_db_file)
}

sub versions {
  SL::File->get_all_versions(dbfile => $_[0]->loaded_db_file)
}

sub save_contents {
  SL::File->save(dbfile => $_[0]->loaded_db_file, file_contents => $_[1] )
}

sub save_file {
  SL::File->save(dbfile => $_[0]->loaded_db_file, file_path => $_[1] )
}

sub delete {
  SL::File->delete(dbfile => $_[0]->loaded_db_file)
}

sub delete_last_version {
  SL::File->delete(dbfile => $_[0]->loaded_db_file, last => 1 )
}

sub delete_version {
  SL::File->delete(dbfile => $_[0]->loaded_db_file, version => $_[0]->version )
}

sub purge {
  SL::File->delete(dbfile => $_[0]->loaded_db_file, all_but_notlast => 1 )
}

sub rename {
  SL::File->rename(dbfile => $_[0]->loaded_db_file, to => $_[1])
}

# internals

sub backend_class {
  SL::File->get_backend_class($_[0]->backend)
}


sub loaded_db_file {  # so, dass wir die nur einmal laden.
  if (!$_[0]->loaded) {
    $_[0]->db_file->load;
    $_[0]->loaded(1);
  }
  $_[0]->db_file;
}


sub init_db_file { die 'must always have a db file'; }
sub init_loaded  { 0 }
sub init_id      { 0 }
sub init_version { 0 }
sub init_newest  { 1 }

1;

__END__

=encoding utf-8

=head1 NAME

SL::File::Object - a filemangement object wrapper

=head1 SYNOPSIS

  use SL::File;

  my ($object) = SL::File->get_all(object_id   => $object_id,
                                   object_type => $object_type,
                                   file_type   => 'images',  # may be optional
                                   source      => 'uploaded' # may be optional
                                  );
# read attributes

  my $object_id   = $object->object_id,
  my $object_type = $object->object_type,
  my $file_type   = $object->file_type;
  my $file_name   = $object->file_name;
  my $mime_type   = $object->mime_type;

  my $mtime       = $object->mtime;
  my $itime       = $object->itime;
  my $id          = $object->id;
  my $newest      = $object->newest;

  my $versions    = $object->version_count;

  my @versionobjs = $object->versions;
  foreach ( @versionobjs ) {
    my $mtime    = $_->mtime;
    my $contents = $_->get_content;
  }

# update

  $object->rename("image1.png");
  $object->save_contents("new text");
  $object->save_file("/tmp/empty.png");
  $object->purge;
  $object->delete_last_version;
  $object->delete;

=head1 DESCRIPTION

This is a wrapper around a single object in the filemangement.

=head1 METHODS

Following methods are wrapper to read the attributes of L<SL::DB::File> :

=over 4

=item C<object_id>

=item C<object_type>

=item C<file_type>

=item C<file_name>

=item C<mime_name>

=item C<file_title>

=item C<file_description>

=item C<backend>

=item C<source>

=item C<itime>

=item C<id>

=back

Additional are there special methods. If the Object is created by SL::File::get_all_versions()
or by "$object->versions"
it has a version number. So the different mtime, filepath or content can be retrieved:

=over 4

=item C<mtime>

get the modification time of a (versioned) object

=item C<get_file>

get the full qualified file path of the (versioned) object

=item C<get_content>

get the content of the (versioned) object

=item C<version_count>

Get the available versions of the file

=item C<versions>

Returns an array of SL::File::Object objects with the available versions of the file, starting with the newest version.

=item C<newest>

If set this is the newest version of the file.

=item C<save_contents $contents>

Store a new contents to the file (as a new version).

=item C<save_file $filepath>

Store the content of an (absolute)file path to the file

=item C<delete>

Delete the file with all of his versions

=item C<delete_last_version>

Delete only the last version of the file with implicit decrement of the version_count.

=item C<purge>

Delete all old versions of the file. Only one version exist after purge. The version count is reset to 1.

=item C<rename $newfilename>

Renames the filename

=back

=head1 SEE ALSO

L<SL::File>

=head1 AUTHOR

Martin Helmling E<lt>martin.helmling@opendynamic.deE<gt>

=cut
