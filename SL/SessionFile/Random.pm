package SL::SessionFile::Random;

use strict;
use parent qw(SL::SessionFile);

my @CHARS = ('A'..'Z', 'a'..'z', 0..9, '_');
my $template = 'X' x 10;
use constant MAX_TRIES => 1000;

sub new {
  my ($class, %params) = @_;

  my $filename;
  my $tries = 0;
  $filename = _get_file() while $tries++ < MAX_TRIES && (!$filename || -e $filename);

  $class->SUPER::new($filename, %params);
}

sub _get_file {
  my $filename = $template;
  $filename =~ s/X(?=X*\z)/$CHARS[ int( rand( @CHARS ) ) ]/ge;
  $filename;
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::SessionFile::Random - SessionFile with a random name

=head1 SYNOPSIS

  use SL::SessionFile::Random;

  # Create a session file named "customer.csv" (relative names only)
  my $sfile = SL::SessionFile::Random->new("w");
  $sfile->fh->print("col1;col2;col3\n" .
                    "value1;value2;value3\n");
  $sfile->fh->close;

=head1 DESCRIPTION

This modules gives you a random file in the current session cache that is guaranteed to be unique

=head1 FUNCTIONS

same as SL::SessioNFile

=head1 BUGS

NONE yet.

=head1 AUTHOR

Sven Schoeling E<lt>s.schoeling@linet-services.deE<gt>

=cut
