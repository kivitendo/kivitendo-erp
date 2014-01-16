package SL::ArchiveZipFixes;

use strict;

use Archive::Zip;
use Archive::Zip::Member;
use version;

# Archive::Zip contains a bug starting with 1.31_04 which prohibits
# re-writing Zips produced by LibreOffice (.odt). See
# https://rt.cpan.org/Public/Bug/Display.html?id=92205

sub _member_writeToFileHandle {
    my $self         = shift;
    my $fh           = shift;
    my $fhIsSeekable = shift;
    my $offset       = shift;

    return _error("no member name given for $self")
      if $self->fileName() eq '';

    $self->{'writeLocalHeaderRelativeOffset'} = $offset;
    $self->{'wasWritten'}                     = 0;

    # Determine if I need to write a data descriptor
    # I need to do this if I can't refresh the header
    # and I don't know compressed size or crc32 fields.
    my $headerFieldsUnknown = (
        ( $self->uncompressedSize() > 0 )
          and ($self->compressionMethod() == Archive::Zip::COMPRESSION_STORED
            or $self->desiredCompressionMethod() == Archive::Zip::COMPRESSION_DEFLATED )
    );

    my $shouldWriteDataDescriptor =
      ( $headerFieldsUnknown and not $fhIsSeekable );

    $self->hasDataDescriptor(1)
      if ($shouldWriteDataDescriptor);

    $self->{'writeOffset'} = 0;

    my $status = $self->rewindData();
    ( $status = $self->_writeLocalFileHeader($fh) )
      if $status == Archive::Zip::AZ_OK;
    ( $status = $self->_writeData($fh) )
      if $status == Archive::Zip::AZ_OK;
    if ( $status == Archive::Zip::AZ_OK ) {
        $self->{'wasWritten'} = 1;
        if ( $self->hasDataDescriptor() ) {
            $status = $self->_writeDataDescriptor($fh);
        }
        elsif ($headerFieldsUnknown) {
            $status = $self->_refreshLocalFileHeader($fh);
        }
    }

    return $status;
}

sub fix_write_to_file_handle_1_30 {
  return if version->new("$Archive::Zip::VERSION")->numify <= version->new("1.30")->numify;

  no warnings 'redefine';

  *Archive::Zip::Member::_writeToFileHandle = \&_member_writeToFileHandle;
}

sub apply_fixes {
  fix_write_to_file_handle_1_30();
}

1;
