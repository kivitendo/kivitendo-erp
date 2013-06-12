package SL::System::InstallationLock;

use strict;

sub lock {
  my ($class) = @_;

  return 1 if $::lx_office_conf{debug}->{keep_installation_unlocked};

  my $fh;
  if (!open($fh, ">", $class->lock_file_name)) {
    die $::locale->text('Lock file handling failed. Please verify that the directory "#1" is writeable by the webserver.', $::lx_office_conf{paths}->{userspath});
  }

  close $fh;

  return 1;
}

sub unlock {
  my ($class) = @_;

  return 1 if $::lx_office_conf{debug}->{keep_installation_unlocked};

  my $name = $class->lock_file_name;
  if ((-f $name)  && !unlink($name)) {
    die $::locale->text('Lock file handling failed. Please verify that the directory "#1" is writeable by the webserver.', $::lx_office_conf{paths}->{userspath});
  }

  return 1;
}

sub is_locked {
  my ($class) = @_;

  return 0 if $::lx_office_conf{debug}->{keep_installation_unlocked};
  return -f $class->lock_file_name;
}

sub lock_file_name {
  $::lx_office_conf{paths}->{userspath} . "/nologin";
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::System::InstallationLock - Handle locking the installation with a
global lock file

=head1 SYNOPSIS

  SL::System::InstallationLock->lock;
  # Do important and uninterruptable work!
  SL::System::InstallationLock->unlock;


=head1 OVERVIEW

If the global lock file exists then no user may login. The
administration area is not affected.

There's a configuration setting
C<debug.keep_installation_unlocked>. If it is trueish then all of
these commands will always keep the installation unlocked: L</lock>
and L</unlock> won't do anything and L</is_locked> always returns 0.

=head1 FUNCTIONS

=over 4

=item C<is_locked>

Returns 1 or 0 depending on whether or not the installation is currently locked.

=item C<lock>

Creates the lock file. Throws an exception if writing to the lock file
location fails.

=item C<lock_file_name>

Returns the file name for the global lock file.

=item C<unlock>

Removed the lock file. Throws an exception if the lock exists and
removing the lock file fails.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
