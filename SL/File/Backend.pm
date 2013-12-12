package SL::File::Backend;

use strict;

use parent qw(Rose::Object);

sub store { die 'store needs to be implemented' }

sub delete { die 'delete needs to be implemented' }

sub rename { die 'rename needs to be implemented' }

sub get_content { die 'get_content needs to be implemented' }

sub get_filepath { die 'get_filepath needs to be implemented' }

sub get_mtime { die 'get_mtime needs to be implemented' }

sub get_version_count { die 'get_version_count needs to be implemented' }

sub enabled { 0; }

sub sync_from_backend { }

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::File::Backend  - Base class for file storage backend

=head1 SYNOPSIS

See the synopsis of L<SL::File> and L<SL::File::Object>

=head1 OVERVIEW

The most methods must be overridden by the specific storage backend

See also the overview of L<SL::File> and L<SL::File::Object>.


=head1 METHODS

=over 4

=item C<store PARAMS>

The file data is stored in the backend.

Available C<PARAMS>:

=over 4

=item C<dbfile>

The object SL::DB::File as param.

=item C<file_contents>

The data of the file to store

=item C<file_path>

If the data is still in a file, the contents of this file is copied.

=back

If both parameter C<file_contents> and C<file_path> exists,
the backend is responsible in which way the contents is fetched.

If the file exists the backend is responsible to decide to save a new version of the file or override the
latest existing file.

=item C<delete PARAMS>

The file data is deleted in the backend.

Available C<PARAMS>:

=over 4

=item C<dbfile>

The object SL::DB::File as param.

=item C<last>

If this parameter is set only the latest version of the file are deleted.

=item C<all_but_notlast>

If this parameter is set all versions of the file are deleted except the latest version.

If none of the two parameters C<all_versions> or C<all__but_notlast> is set
all version of the file are deleted.

=back

=item C<rename PARAMS>

The Filename of the file is changed. If the backend is not dependant from the filename
nothing must happens. The rename must work on all versions of the file.

Available C<PARAMS>:

=over 4

=item C<dbfile>

The object SL::DB::File as param.

=back

=item C<get_version_count PARAMS>

The count of the available versions of a file will returned.
The versions are numbered from 1 up to the returned value

Available C<PARAMS>:

=over 4

=item C<dbfile>

=back

=item C<get_mtime PARAMS>

Available C<PARAMS>:

=over 4

=item C<dbfile>

The object SL::DB::File as param.

=item C<version>

The version number of the file for which the modification timestamp is wanted.
If no version set or version is 0 , the mtime of the latest version is returned.

=back

=item C<get_content PARAMS>

For downloading or printing the real data need to retrieve.
A reference of the data must be returned.

Available C<PARAMS>:

=over 4

=item C<dbfile>

The object SL::DB::File as param.

=back

=item C<get_file_path PARAMS>

If the backend has files as storage, the file path can returned.
If a file is not available in the backend a temporary file must be created with the contents.

Available C<PARAMS>:

=over 4

=item C<dbfile>

The object SL::DB::File as param.

=back

=item C<enabled>

returns 1 if the backend is enabled and has all config to work.
In other cases it must return 0

=item C<sync_from_backend>

For Backends which may be changed outside of kivitendo a synchronization of the database is done.
Normally the backend is responsible to actualise the data if it needed.
This interface can be used if a long work must be done and runs in a extra task.

=back

=head1 SEE ALSO

L<SL::File>, L<SL::File::Object>

=head1 AUTHOR

Martin Helmling E<lt>martin.helmling@opendynamic.deE<gt>

=cut


