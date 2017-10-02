package SL::Version;

use strict;

our $instance;

sub new {
  bless \my $instace, __PACKAGE__;
}

sub get_instance {
  $instance //= $_[0]->new;
}

sub get_version {
  $$instance //= do {
    open my $version_file, '<', "VERSION" or die 'can not open VERSION file';
    my $version = <$version_file>;
    close $version_file;

    if ( -f "BUILD" ) {
      open my $build_file, '<', "BUILD" or die 'can not open BUILD file';
      my $build =  <$build_file>;
      close $build_file;
      $version .= '-' . $build;
    }

    # only allow numbers, letters, points, underscores and dashes. Prevents injecting of malicious code.
    $version =~ s/[^0-9A-Za-z\.\_\-]//g;

    $version;
  }
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Version

=head1 SYNOPSIS

  use SL::Version;

  my $version = SL::Version->get_version

=head1 DESCRIPTION

This module is a singleton for the sole reason that SL::Form doesn't have to
cache the version.

=head1 FUNCTIONS

=head2 C<new>

Creates a new object. Should never be called.

=head2 C<get_instance>

Creates a singleton instance if none exists and returns.

=head2 C<get_version>

Parses the version from the C<VERSION> file.

If the file C<BUILD> exists, appends its contents as a build number.

Returns a sanitized version string.

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
