package SL::File;

use strict;

use parent qw(Rose::Object);

use Clone qw(clone);
use SL::File::Backend;
use SL::File::Object;
use SL::DB::History;
use SL::DB::ShopImage;
use SL::DB::File;
use SL::Helper::UserPreferences;
use SL::Controller::Helper::ThumbnailCreator qw(file_probe_type);
use SL::JSON;

use constant RENAME_OK          => 0;
use constant RENAME_EXISTS      => 1;
use constant RENAME_NOFILE      => 2;
use constant RENAME_SAME        => 3;
use constant RENAME_NEW_VERSION => 4;

sub get {
  my ($self, %params) = @_;
  die 'no id' unless $params{id};
  my $dbfile = SL::DB::Manager::File->get_first(query => [id => $params{id}]);
  die 'not found' unless $dbfile;
  $main::lxdebug->message(LXDebug->DEBUG2(), "object_id=".$dbfile->object_id." object_type=".$dbfile->object_type." dbfile=".$dbfile);
  SL::File::Object->new(db_file => $dbfile, id => $dbfile->id, loaded => 1);
}

sub get_version_count {
  my ($self, %params) = @_;
  die "no id or dbfile" unless $params{id} || $params{dbfile};
  $params{dbfile} = SL::DB::Manager::File->get_first(query => [id => $params{id}]) if !$params{dbfile};
  die 'not found' unless $params{dbfile};
  my $backend = $self->_get_backend($params{dbfile}->backend);
  return $backend->get_version_count(%params);
}

sub get_all {
  my ($self, %params) = @_;

  my @files;
  return @files unless $params{object_type};
  return @files unless defined($params{object_id});

  my @query = (
    object_id   => $params{object_id},
    object_type => $params{object_type}
  );
  push @query, (file_name => $params{file_name}) if $params{file_name};
  push @query, (file_type => $params{file_type}) if $params{file_type};
  push @query, (mime_type => $params{mime_type}) if $params{mime_type};
  push @query, (source    => $params{source})    if $params{source};

  my $sortby = $params{sort_by} || 'itime DESC,file_name ASC';

  @files = @{ SL::DB::Manager::File->get_all(query => [@query], sort_by => $sortby) };
  map { SL::File::Object->new(db_file => $_, id => $_->id, loaded => 1) } @files;
}

sub get_all_versions {
  my ($self, %params) = @_;
  my @versionobjs;
  my @fileobjs = $self->get_all(%params);
  if ( $params{dbfile} ) {
    push @fileobjs, SL::File::Object->new(dbfile => $params{db_file}, id => $params{dbfile}->id, loaded => 1);
  } else {
    @fileobjs = $self->get_all(%params);
  }
  foreach my $fileobj (@fileobjs) {
    $main::lxdebug->message(LXDebug->DEBUG2(), "obj=" . $fileobj . " id=" . $fileobj->id." versions=".$fileobj->version_count);
    my $maxversion = $fileobj->version_count;
    $fileobj->version($maxversion);
    push @versionobjs, $fileobj;
    if ($maxversion > 1) {
      for my $version (2..$maxversion) {
        $main::lxdebug->message(LXDebug->DEBUG2(), "clone for version=".($maxversion-$version+1));
        eval {
          my $clone = clone($fileobj);
          $clone->version($maxversion-$version+1);
          $clone->newest(0);
          $main::lxdebug->message(LXDebug->DEBUG2(), "clone version=".$clone->version." mtime=". $clone->mtime);
          push @versionobjs, $clone;
          1;
        }
      }
    }
  }
  return @versionobjs;
}

sub get_all_count {
  my ($self, %params) = @_;
  return 0 unless $params{object_type};

  my @query = (
    object_id   => $params{object_id},
    object_type => $params{object_type}
  );
  push @query, (file_name => $params{file_name}) if $params{file_name};
  push @query, (file_type => $params{file_type}) if $params{file_type};
  push @query, (mime_type => $params{mime_type}) if $params{mime_type};
  push @query, (source    => $params{source})    if $params{source};

  my $cnt = SL::DB::Manager::File->get_all_count(query => [@query]);
  return $cnt;
}

sub delete_all {
  my ($self, %params) = @_;
  return 0 unless defined($params{object_id}) || $params{object_type};
  my $files = SL::DB::Manager::File->get_all(
    query => [
      object_id   => $params{object_id},
      object_type => $params{object_type}
    ]
  );
  foreach my $file (@{$files}) {
    $params{dbfile} = $file;
    $self->delete(%params);
  }
}

sub delete {
  my ($self, %params) = @_;
  die "no id or dbfile in delete" unless $params{id} || $params{dbfile};
  my $rc = 0;
  eval {
    $rc = SL::DB->client->with_transaction(\&_delete, $self, %params);
    1;
  } or do { die $@ };
  return $rc;
}

sub _delete {
  my ($self, %params) = @_;
  $params{dbfile} = SL::DB::Manager::File->get_first(query => [id => $params{id}]) if !$params{dbfile};

  my $backend = $self->_get_backend($params{dbfile}->backend);
  if ( $params{dbfile}->file_type eq 'document' && $params{dbfile}->source ne 'created')
  {
    ## must unimport
    my $hist = SL::DB::Manager::History->get_first(
      where => [
        addition  => 'IMPORT',
        trans_id  => $params{dbfile}->object_id,
        what_done => $params{dbfile}->id
      ]
    );

    if ($hist) {
      if (!$main::auth->assert('import_ar | import_ap', 1)) {
        die 'no permission to unimport';
      }
      my $file = $backend->get_filepath(dbfile => $params{dbfile});
      $main::lxdebug->message(LXDebug->DEBUG2(), "del file=" . $file . " to=" . $hist->snumbers);
      File::Copy::copy($file, $hist->snumbers) if $file;
      $hist->addition('UNIMPORT');
      $hist->save;
    }
  }
  if ($backend->delete(%params)) {
    my $do_delete = 0;
    if ( $params{last} || $params{version} || $params{all_but_notlast} ) {
      if ( $backend->get_version_count(%params) > 0 ) {
        $params{dbfile}->mtime(DateTime->now_local);
        $params{dbfile}->save;
      } else {
        $do_delete = 1;
      }
    } else {
      $do_delete = 1;
    }
    $params{dbfile}->delete if $do_delete;
    return 1;
  }
  return 0;
}

sub save {
  my ($self, %params) = @_;

  my $obj;
  eval {
    $obj = SL::DB->client->with_transaction(\&_save, $self, %params);
    1;
  } or do { die $@ };
  return $obj;
}

sub _save {
  my ($self, %params) = @_;
  my $file = $params{dbfile};
  my $exists = 0;

  if ($params{id}) {
    $file = SL::DB::File->new(id => $params{id})->load;
    die 'dbfile not exists'     unless $file;
  } elsif (!$file) {
  $main::lxdebug->message(LXDebug->DEBUG2(), "obj_id=" .$params{object_id});
    die 'no object type set'    unless $params{object_type};
    die 'no object id set'      unless defined($params{object_id});

    $exists = $self->get_all_count(%params);
    die 'filename still exist' if $exists && $params{fail_if_exists};
    if ($exists) {
      my ($obj1) = $self->get_all(%params);
      $file = $obj1->db_file;
    } else {
      $file = SL::DB::File->new();
      $file->assign_attributes(
        object_id      => $params{object_id},
        object_type    => $params{object_type},
        source         => $params{source},
        file_type      => $params{file_type},
        file_name      => $params{file_name},
        mime_type      => $params{mime_type},
        title          => $params{title},
        description    => $params{description},
      );
      $file->itime($params{mtime})    if $params{mtime};
      $params{itime} = $params{mtime} if $params{mtime};
    }
  } else {
    $exists = 1;
  }
  if ($exists) {
    #change attr on existing file
    $file->file_name  ($params{file_name})   if $params{file_name};
    $file->mime_type  ($params{mime_type})   if $params{mime_type};
    $file->title      ($params{title})       if $params{title};
    $file->description($params{description}) if $params{description};
  }
  if ( !$file->backend ) {
    $file->backend($self->_get_backend_by_file_type($file));
    # load itime for new file
    $file->save->load;
  }

  $file->mtime(DateTime->now_local) unless $params{mtime};
  $file->mtime($params{mtime}     ) if     $params{mtime};

  my $backend = $self->_get_backend($file->backend);
  $params{dbfile} = $file;
  $backend->save(%params);

  $file->save;
  #ShopImage
  if($file->object_type eq "shop_image"){
    my $image_content = $params{file_contents};
    my $thumbnail = file_probe_type($image_content);
    my $shopimage = SL::DB::ShopImage->new();
    $shopimage->assign_attributes(
                                  file_id                => $file->id,
                                  thumbnail_content      => $thumbnail->{thumbnail_img_content},
                                  org_file_height        => $thumbnail->{file_image_height},
                                  org_file_width         => $thumbnail->{file_image_width},
                                  thumbnail_content_type => $thumbnail->{thumbnail_img_content_type},
                                  object_id              => $file->object_id,
                                 );
    $shopimage->save;
  }
  if ($params{file_type} eq 'document' && $params{source} ne 'created') {
    SL::DB::History->new(
      addition    => 'IMPORT',
      trans_id    => $params{object_id},
      snumbers    => $params{file_path},
      employee_id => SL::DB::Manager::Employee->current->id,
      what_done   => $params{dbfile}->id
    )->save();
  }
  return $params{obj} if $params{dbfile} && $params{obj};
  return SL::File::Object->new(db_file => $file, id => $file->id, loaded => 1);
}

sub rename {
  my ($self, %params) = @_;
  return RENAME_NOFILE unless $params{id} || $params{dbfile};
  my $file = $params{dbfile};
  $file = SL::DB::Manager::File->get_first(query => [id => $params{id}]) if !$file;
  return RENAME_NOFILE unless $file;

  $main::lxdebug->message(LXDebug->DEBUG2(), "rename id=" . $file->id . " to=" . $params{to});
  if ($params{to}) {
    return RENAME_SAME   if $params{to} eq $file->file_name;
    return RENAME_EXISTS if $self->get_all_count( object_id     => $file->object_id,
                                                  object_type   => $file->object_type,
                                                  mime_type     => $file->mime_type,
                                                  source        => $file->source,
                                                  file_type     => $file->file_type,
                                                  file_name     => $params{to}
                                                ) > 0;

    my $backend = $self->_get_backend($file->backend);
    $backend->rename(dbfile => $file) if $backend;
    $file->file_name($params{to});
    $file->save;
  }
  return RENAME_OK;
}

sub get_backend_class {
  my ($self, $backendname) = @_;
  die "no backend name set" unless $backendname;
  $self->_get_backend($backendname);
}

sub get_other_sources {
  my ($self) = @_;
  my $pref = SL::Helper::UserPreferences->new(namespace => 'file_sources');
  $pref->login("#default#");
  my @sources;
  foreach my $tuple (@{ $pref->get_all() }) {
    my %lkeys  = %{ SL::JSON::from_json($tuple->{value}) };
    my $source = {
      'name'        => $tuple->{key},
      'description' => $lkeys{desc},
      'directory'   => $lkeys{dir}
    };
    push @sources, $source;
  }
  return @sources;
}

sub sync_from_backend {
  my ($self, %params) = @_;
  return unless $params{file_type};
  my $file = SL::DB::File->new;
  $file->file_type($params{file_type});
  my $backend = $self->_get_backend($self->_get_backend_by_file_type($file));
  return unless $backend;
  $backend->sync_from_backend(%params);
}

#
# internal
#
sub _get_backend {
  my ($self, $backend_name) = @_;
  my $class = 'SL::File::Backend::' . $backend_name;
  my $obj   = undef;
  die $::locale->text('no backend enabled') if $backend_name eq 'None';
  eval {
    eval "require $class";
    $obj = $class->new;
    die $::locale->text('backend "#1" not enabled',$backend_name) unless $obj->enabled;
    1;
  } or do {
    if ( $obj ) {
      die $@;
    } else {
      die $::locale->text('backend "#1" not found',$backend_name);
    }
  };
  return $obj;
}

sub _get_backend_by_file_type {
  my ($self, $dbfile) = @_;

  $main::lxdebug->message(LXDebug->DEBUG2(), "_get_backend_by_file_type=" .$dbfile." type=".$dbfile->file_type);
  return "Filesystem" unless $dbfile;
  return $::instance_conf->get_doc_storage_for_documents   if $dbfile->file_type eq 'document';
  return $::instance_conf->get_doc_storage_for_attachments if $dbfile->file_type eq 'attachment';
  return $::instance_conf->get_doc_storage_for_images      if $dbfile->file_type eq 'image';
  return "Filesystem";
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::File - The intermediate Layer for handling files

=head1 SYNOPSIS

  # In a controller or helper ( see SL::Controller::File or SL::Helper::File )
  # you can create, remove, delete etc. a file in a backend independent way

  my $file  = SL::File->save(
                     object_id     => $self->object_id,
                     object_type   => $self->object_type,
                     mime_type     => 'application/pdf',
                     file_type     => 'documents',
                     file_contents => 'this is no pdf');

  my $file1  = SL::File->get(id => $id);
  SL::File->delete(id => $id);
  SL::File->delete(dbfile => $file1);
  SL::File->delete_all(object_id   => $object_id,
                       object_type => $object_type,
                       file_type   => $filetype      # may be optional
                      );
  SL::File->rename(id => $id,to => $newname);
  my $files1 = SL::File->get_all(object_id   => $object_id,
                                 object_type => $object_type,
                                 file_type   => 'images',  # may be optional
                                 source      => 'uploaded' # may be optional
                                );

  # Alternativelly some operation can be done with the filemangement object wrapper
  # and additional oparations see L<SL::File::Object>

=head1 OVERVIEW

The Filemanagemt can handle files in a storage independent way. Internal the File
use the configured storage backend for the type of file.
These backends must be configured in L<SL::Controller::ClientConfig> or an extra database table.

There are three types of files:

=over 2

=item - documents,

which can be generated files (for sales), scanned files or uploaded files (for purchase) for an ERP-object.
They can exist in different versions. The versioning is handled implicit. All versions of a file may be
deleted by the user if she/he is allowed to do this.

=item - attachments,

which have additional information for an ERP-objects. They are uploadable. If a filename still exists
on a ERP-Object the new uploaded file is a new version of this or it must be renamed by user.

There are generic attachments for a specific document group (like sales_invoices). This attachments can be
combinide/merged with the document-file in the time of printing.
Today only PDF-Attachmnets can be merged with the generated document-PDF.

=item - images,

they are like attachments, but they may be have thumbnails for displaying.
So the must have an image format like png,jpg. The versioning is like attachments

=back

For each type of files the backend can configured in L<SL::Controller::ClientConfig>.

The files have also the parameter C<Source>:

=over 2

=item - created, generated by LaTeX

=item - uploaded

=item - scanner, import from scanner

( or scanner1, scanner2 if there are different scanner, be configurable via UserPreferences )

=item - email, received by email and imported by hand or automatic.

=back

The files from source 'scanner' or 'email' are not allowed to delete else they must be send back to the sources.
This means they are moved back into the correspondent source directories.

The scanner and email import must be configured  via Table UserPreferences:

=begin text

 id |  login  |  namespace   | version |   key    |                        value
----+---------+--------------+---------+----------+------------------------------------------------------
  1 | default | file_sources | 0.00000 | scanner1 | {"dir":"/var/tmp/scanner1","desc":"Scanner Einkauf" }
  2 | default | file_sources | 0.00000 | emails   | {"dir":"/var/tmp/emails"  ,"desc":"Empfangene Mails"}

=end text

.

The Fileinformation is stored in the table L<SL::DB::File> for saving the information.
The modul and object_id describe the link to the object.

The interface SL::File:Object encapsulate SL::DB:File, see L<SL::DB::Object>

The storage backends are extra classes which depends from L<SL::File::Backend>.
So additional backend classes can be added.

The implementation of versioning is done in the different backends.

=head1 METHODS

=over 4

=item C<save>

Creates a new SL::DB:File object or save an existing object for a specific backend depends of the C<file_type>
and config, like

=begin text

          SL::File->save(
                         object_id    => $self->object_id,
                         object_type  => $self->object_type,
                         content_type => 'application/pdf'
                        );

=end text

.

The file data is stored in the backend. If the file_type is "document" and the source is not "created" the file is imported,
so in the history the import is documented also as a hint to can unimport the file later.

Available C<PARAMS>:

=over 4

=item C<id>

The id of SL::DB::File for an existing file

=item C<object_id>

The Id of the ERP-object for a new file.

=item C<object_type>

The Type of the ERP-object like "sales_quotation" for a new file. A clear mapping to the class/model exists in the controller.

=item C<file_type>

The type may be "documents", "attachments" or "images" for a new file.

=item C<source>

The type may be "created", "uploaded" or email sources or scanner sources for a new file.

=item C<file_name>

The file_name of the file for a new file. This name is used in the WebGUI and as name for download.

=item C<mime_type>

The mime_type of a new file. This is used for downloading or for email attachments.

=item C<description> or C<title>

The description or title of a new file. This must be discussed if this attribute is needed.

=back

=item C<delete PARAMS>

The file data is deleted in the backend. If the file comes from source 'scanner' or 'email'
they moved back to the source folders. This is documented in the history.

Available C<PARAMS>:

=over 4

=item C<id>

The id of SL::DB::File

=item C<dbfile>

As alternative if the SL::DB::File as object is available.

=back

=item C<delete_all PARAMS>

All file data of an ERP-object is deleted in the backend.

=over 4

=item C<object_id>

The Id of the ERP-object.

=item C<object_type>

The Type of the ERP-object like "sales_quotation". A clear mapping to the class/model exists in the controller.

=back

=item C<rename PARAMS>

The Filename of the file is changed

Available C<PARAMS>:

=over 4

=item C<id>

The id of SL::DB::File

=item C<to>

The new filename

=back

=item C<get PARAMS>

The actual file object is retrieved. The id of the object is needed.

Available C<PARAMS>:

=over 4

=item C<id>

The id of SL::DB::File

=back

=item C<get_all PARAMS>

All last versions of file data objects which are related to an ERP-Document,Part,Customer,Vendor,... are retrieved.

Available C<PARAMS>:

=over 4

=item C<object_id>

The Id of the ERP-object.

=item C<object_type>

The Type of the ERP-object like "sales_quotation". A clear mapping to the class/model exists in the controller.

=item C<file_type>

The type may be "documents", "attachments" or "images". This parameter is optional.

=item C<file_name>

The name of the file . This parameter is optional.

=item C<mime_type>

The MIME type of the file . This parameter is optional.

=item C<source>

The type may be "created", "uploaded" or email sources or scanner soureces. This parameter is optional.

=item C<sort_by>

An optional parameter in which sorting the files are retrieved. Default is decrementing itime and ascending filename

=back

=item C<get_all_versions PARAMS>

All versions of file data objects which are related to an ERP-Document,Part,Customer,Vendor,... are retrieved.
If only the versions of one file are wanted, additional parameter like file_name must be set.
If the param C<dbfile> set, only the versions of this file are returned.

Available C<PARAMS> ar the same as L<get_all>



=item C<get_all_count PARAMS>

The count of available files is returned.
Available C<PARAMS> ar the same as L<get_all>


=item C<get_content PARAMS>

The data of a file can retrieved. A reference to the data is returned.

Available C<PARAMS>:

=over 4

=item C<id>

The id of SL::DB::File

=item C<dbfile>

If no Id exists the object SL::DB::File as param.

=back

=item C<get_file_path PARAMS>

Sometimes it is more useful to have a path to the file not the contents. If the backend has not stored the content as file
it is in the responsibility of the backend to create a tempory session file.

Available C<PARAMS>:

=over 4

=item C<id>

The id of SL::DB::File

=item C<dbfile>

If no Id exists the object SL::DB::File as param.

=back

=item C<get_other_sources>

A helpful method to get the sources for scanner and email from UserPreferences. This method is need from SL::Controller::File

=item C<sync_from_backend>

For Backends which may be changed outside of kivitendo a synchronization of the database is done.
This sync must be triggered by a periodical task.

Needed C<PARAMS>:

=over 4

=item C<file_type>

The synchronization is done file_type by file_type.

=back

=back

=head1 AUTHOR

Martin Helmling E<lt>martin.helmling@opendynamic.deE<gt>

=cut
