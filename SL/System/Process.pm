package SL::System::Process;

use strict;

use parent qw(Rose::Object);

use English qw(-no_match_vars);
use File::Spec;
use File::Basename;

sub exe_dir {
  my $dir        = dirname(File::Spec->rel2abs($PROGRAM_NAME));
  my $system_dir = File::Spec->catdir($dir, 'SL', 'System');
  return $dir if -d $system_dir && -f File::Spec->catfile($system_dir, 'TaskServer.pm');

  my @dirs = reverse File::Spec->splitdir($dir);
  shift @dirs;
  $dir        = File::Spec->catdir(reverse @dirs);
  $system_dir = File::Spec->catdir($dir, 'SL', 'System');
  return File::Spec->curdir unless -d $system_dir && -f File::Spec->catfile($system_dir, 'TaskServer.pm');

  return $dir;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::System::Process - assorted system-relevant functions

=head1 SYNOPSIS

  # Get base path to kivitendo scripts
  my $path = SL::System::Process->exe_dir;

=head1 FUNCTIONS

=over 4

=item C<exe_dir>

Returns the absolute path to the directory the kivitendo executables
(C<login.pl> etc.) and modules (sub-directory C<SL/> etc.) are located
in.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
