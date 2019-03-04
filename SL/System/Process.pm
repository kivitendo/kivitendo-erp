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

sub _parse_number_with_unit {
  my ($number) = @_;

  return undef   unless defined $number;
  return $number unless $number =~ m{^ \s* (\d+) \s* ([kmg])b \s* $}xi;

  my %factors = (K => 1024, M => 1024 * 1024, G => 1024 * 1024 * 1024);

  return $1 * $factors{uc $2};
}

sub memory_usage_is_too_high {
  return undef unless $::lx_office_conf{system};

  my %limits = (
    rss  => _parse_number_with_unit($::lx_office_conf{system}->{memory_limit_rss}),
    size => _parse_number_with_unit($::lx_office_conf{system}->{memory_limit_vsz}),
  );

  # $::lxdebug->dump(0, "limits", \%limits);

  return undef unless $limits{rss} || $limits{vsz};

  my %usage;

  my $in = IO::File->new("/proc/$$/status", "r") or return undef;

  while (<$in>) {
    chomp;
    $usage{lc $1} = _parse_number_with_unit($2) if m{^ vm(rss|size): \s* (\d+ \s* [kmg]b) \s* $}ix;
  }

  $in->close;

  # $::lxdebug->dump(0, "usage", \%usage);

  foreach my $type (keys %limits) {
    next if !$limits{$type};
    next if $limits{$type} >= ($usage{$type} // 0);

    {
      no warnings 'once';
      $::lxdebug->message(LXDebug::WARN(), "Exiting due to memory size limit reached for type '${type}': limit " . $limits{$type} . " bytes, usage " . $usage{$type} . " bytes");
    }

    return 1;
  }

  return 0;
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

=item C<memory_usage_is_too_high>

Returns true if the current process uses more memory than the configured
limits.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
