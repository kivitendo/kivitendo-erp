package SL::SessionFile;

use strict;

use parent qw(Rose::Object);

use Carp;
use File::Path qw(mkpath rmtree);
use English qw(-no_match_vars);
use IO::File;
use POSIX qw(strftime);

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(fh file_name) ],
 'scalar --get_set_init' => [ qw(session_id) ],
);

sub new {
  my ($class, $file_name, %params) = @_;

  my $self   = $class->SUPER::new;

  if ($params{session_id}) {
    $self->session_id($params{session_id})
  }

  my $path   = $self->prepare_path;
  $file_name =~ s{.*/}{}g;
  $file_name =  "${path}/${file_name}";

  $self->file_name($file_name);

  if ($params{mode}) {
    my $mode = $params{mode};

    if ($params{encoding}) {
      $params{encoding} =~ s/[^a-z0-9\-]//gi;
      $mode .= ':encoding(' . $params{encoding} . ')';
    }

    $self->fh(IO::File->new($file_name, $mode));
  }

  return $self;
}

sub open {
  my ($self, $mode) = @_;
  return $self->fh(IO::File->new($self->file_name, $mode));
}

sub exists {
  my ($self) = @_;
  return -f $self->file_name;
}

sub size {
  my ($self) = @_;
  return -s $self->file_name;
}

sub displayable_mtime {
  my ($self) = @_;
  return '' unless $self->exists;

  my @mtime = localtime((stat $self->file_name)[9]);
  return $::locale->format_date(\%::myconfig, $mtime[5] + 1900, $mtime[4] + 1, $mtime[3]) . ' ' . strftime('%H:%M:%S', @mtime);
}

sub get_path {
  die "No session ID" unless $_[0]->session_id;
  return "users/session_files/" . $_[0]->session_id;
}

sub prepare_path {
  my $path = $_[0]->get_path;
  return $path if -d $path;
  mkpath $path;
  die "Creating ${path} failed" unless -d $path;
  return $path;
}

sub init_session_id {
  $::auth->get_session_id;
}

sub destroy_session {
  my ($class, $session_id) = @_;

  $session_id =~ s/[^a-z0-9]//gi;
  rmtree "users/session_files/$session_id" if $session_id;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::SessionFile - Create files that are removed when the session is
destroyed or expires

=head1 SYNOPSIS

  use SL::SessionFile;

  # Create a session file named "customer.csv" (relative names only)
  my $sfile = SL::SessionFile->new('customer.csv', mode => 'w');
  $sfile->fh->print("col1;col2;col3\n" .
                    "value1;value2;value3\n");
  $sfile->fh->close;

  # Does temporary file exist?
  my $sfile = SL::SessionFile->new("customer.csv");
  if ($sfile->exists) {
    print "file exists; size " . $sfile->size . " bytes; mtime " . $sfile->displayable_mtime . "\n";
  }

A small class that wraps around files that only exist as long as the
user's session exists. The session expiration mechanism will delete
all session files when the session itself is removed due to expiry or
the user logging out.

Files are stored in session-specific folders in
C<users/session_files/SESSIONID>.

=head1 MEMBER FUNCTIONS

=over 4

=item C<new $file_name, [%params]>

Create a new instance. C<$file_name> is a relative file name (path
components are stripped) to the session-specific temporary directory.

If C<$params{mode}> is given then try to open the file as an instance
of C<IO::File>. C<${mode}> is passed through to C<IO::File::new>.

If C<$params{encoding}> is given then the file is opened with the
appropriate encoding layer.

=item C<fh>

Returns the instance of C<IO::File> associated with the file.

=item C<file_name>

Returns the full relative file name associated with this instance. If
it has been created for "customer.csv" then the value returned might
be C<users/session_files/e8789b98721347/customer.csv>.

=item C<open [%params]>

Opens the file_name given at creation with the given parameters.

=item C<exists>

Returns trueish if the file exists.

=item C<size>

Returns the file's size in bytes.

=item C<displayable_mtime>

Returns the modification time suitable for display (e.g. date
formatted according to the user's date format), e.g.
C<22.01.2011 14:12:22>.

=back

=head1 OBJECT FUNCTIONS

=over 4

=item C<get_path>

Returns the name of the session-specific directory used for file
storage relative to the kivitendo installation folder.

=item C<prepare_path>

Creates all directories in C<get_path> if they do not exist. Returns
the same as C<get_path>.

=item C<destroy_session $id>

Removes all files and the directory belonging to the session C<$id>.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
