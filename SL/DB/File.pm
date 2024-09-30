# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::File;

use strict;

use SL::DB::MetaSetup::File;
use SL::DB::Manager::File;
use SL::DB::Helper::AttrSorted;

__PACKAGE__->meta->add_relationship(
  full_text            => {
    type               => 'one to one',
    class              => 'SL::DB::FileFullText',
    column_map         => { id => 'file_id' },
  },
);

__PACKAGE__->meta->add_relationship(
  file_versions        => {
    type               => 'one to many',
    class              => 'SL::DB::FileVersion',
    column_map         => { id => 'file_id' },
  },
);


__PACKAGE__->meta->initialize;

__PACKAGE__->attr_sorted({unsorted => 'file_versions', position => 'version'});

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::File - Databaseclass for File

=head1 SYNOPSIS

use SL::DB::File;

# synopsis...

=head1 DESCRIPTION

# longer description.

=head1 INTERFACE

=head1 DEPENDENCIES

=head1 SEE ALSO

=head1 AUTHOR

Werner Hahn E<lt>wh@futureworldsearch.netE<gt>

=cut
