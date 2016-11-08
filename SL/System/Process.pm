package SL::System::Process;

use strict;

use parent qw(Rose::Object);

use English qw(-no_match_vars);
use FindBin;
use File::Spec;
use File::Basename;
use List::Util qw(first);

my $cached_exe_dir;

sub exe_dir {
  return $cached_exe_dir if defined $cached_exe_dir;

  my $bin_dir       = File::Spec->rel2abs($FindBin::Bin);
  my @dirs          = File::Spec->splitdir($bin_dir);

  $cached_exe_dir   = first { -f File::Spec->catdir(@dirs[0..$_], 'SL', 'System', 'TaskServer.pm') }
                      reverse(0..scalar(@dirs) - 1);
  $cached_exe_dir   = defined($cached_exe_dir) ? File::Spec->catdir(@dirs[0..$cached_exe_dir]) : File::Spec->curdir;

  return $cached_exe_dir;
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
