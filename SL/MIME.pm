package SL::MIME;

use strict;

sub mime_type_from_ext {
  $main::lxdebug->enter_sub();

  my $self = shift;
  my $ext  = shift;

  # TODO: Mittels Standardmodulen implementieren.
  my %mime_types = ('ods'  => 'application/vnd.oasis.opendocument.spreadsheet',
                    'odt'  => 'application/vnd.oasis.opendocument.text',
                    'pdf'  => 'application/pdf',
                    'sql'  => 'text/plain',
                    'txt'  => 'text/plain',
                    'html' => 'text/html',
    );

  $ext =~ s/.*\.//;

  $main::lxdebug->leave_sub();

  return $mime_types{$ext};
}

1;
