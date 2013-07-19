package SL::DB::AuthClient;

use strict;

use Carp;
use File::Path ();

use SL::DBConnect;
use SL::DB::MetaSetup::AuthClient;
use SL::DB::Manager::AuthClient;
use SL::DB::Helper::Util;

__PACKAGE__->meta->add_relationship(
  users => {
    type      => 'many to many',
    map_class => 'SL::DB::AuthClientUser',
    map_from  => 'client',
    map_to    => 'user',
  },
  groups => {
    type      => 'many to many',
    map_class => 'SL::DB::AuthClientGroup',
    map_from  => 'client',
    map_to    => 'group',
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->before_save('_before_save_remember_old_name');
__PACKAGE__->after_save('_after_save_ensure_webdav_symlink_correctness');
__PACKAGE__->after_delete('_after_delete_delete_webdav_symlink');

sub _before_save_remember_old_name {
  my ($self) = @_;

  delete $self->{__before_save_remember_old_name};
  if ($self->id && $::lx_office_conf{features}->{webdav}) {
    $self->{__before_save_remember_old_name} = SL::DB::AuthClient->new(id => $self->id)->load->name;
  }

  return 1;
}

sub _after_save_ensure_webdav_symlink_correctness {
  my ($self) = @_;

  $self->ensure_webdav_symlink_correctness($self->{__before_save_remember_old_name}) if $self->id;
  return 1;
}

sub _after_delete_delete_webdav_symlink {
  my ($self) = @_;

  my $name = $self->webdav_symlink_basename;
  unlink "webdav/links/${name}";
  return 1;
}

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The name is missing.')                                           if !$self->name;
  push @errors, $::locale->text('The database name is missing.')                                  if !$self->dbname;
  push @errors, $::locale->text('The database host is missing.')                                  if !$self->dbhost;
  push @errors, $::locale->text('The database port is missing.')                                  if !$self->dbport;
  push @errors, $::locale->text('The database user is missing.')                                  if !$self->dbuser;
  push @errors, $::locale->text('The name is not unique.')                                        if !SL::DB::Helper::Util::is_unique($self, 'name');
  push @errors, $::locale->text('The combination of database host, port and name is not unique.') if !SL::DB::Helper::Util::is_unique($self, 'dbhost', 'dbport', 'dbname');

  return @errors;
}

sub webdav_symlink_basename {
  my ($self, $name) =  @_;

  $name             =  $name || $self->name || '';
  $name             =~ s:/+:_:g;

  return $name;
}

sub ensure_webdav_symlink_correctness {
  my ($self, $old_name) = @_;

  croak "Need object ID" unless $self->id;

  my $new_symlink = $self->webdav_symlink_basename;

  croak "Need name" unless $new_symlink;

  my $base_path = 'webdav/links';

  if ($old_name) {
    my $old_symlink = $self->webdav_symlink_basename($old_name);
    return if $old_symlink eq $new_symlink;

    if (-l "${base_path}/${old_symlink}") {
      rename "${base_path}/${old_symlink}", "${base_path}/${new_symlink}";
      return;
    }
  }

  File::Path::make_path('webdav/' . $self->id);
  symlink '../' . $self->id, "${base_path}/${new_symlink}";
}

sub get_dbconnect_args {
  my ($self, %params) = @_;

  return (
    'dbi:Pg:dbname=' . $self->dbname . ';host=' . ($self->dbhost || 'localhost') . ';port=' . ($self->dbport || 5432),
    $self->dbuser,
    $self->dbpasswd,
    SL::DBConnect->get_options(%params),
  );
}

sub dbconnect {
  my ($self, %params) = @_;
  return SL::DBConnect->connect($self->get_dbconnect_args(%params));
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::AuthClient - RDBO model for the auth.clients table

=head1 FUNCTIONS

=over 4

=item C<dbconnect [%params]>

Establishes a new database connection to the database configured for
C<$self>. Returns a database handle as returned by
L<SL::DBConnect/connect> (which is either a normal L<DBI> handle or
one handled by L<DBIx::Log4perl>).

C<%params> are optional parameters passed as the fourth argument to
L<SL::DBConnect/connect>. They're first filtered through
L<SL::DBConnect/get_options> so the UTF-8 flag will be set properly.

=item C<ensure_webdav_symlink_correctness>

Handles the symlink creation/deletion for the WebDAV folder. Does
nothing if WebDAV is not enabled in the configuration.

For each existing client a symbolic link should exist in the directory
C<webdav/links> pointing to the actual WebDAV directory which is the
client's database ID.

The symbolic link's name is the client's name sanitized a bit. It's
calculated by L</webdav_symlink_basename>.

=item C<get_dbconnect_args [%params]>

Returns an array of database connection parameters suitable for
passing to L<SL::DBConnect/connect>.

C<%params> are optional parameters passed as the fourth argument to
L<SL::DBConnect/connect>. They're first filtered through
L<SL::DBConnect/get_options> so the UTF-8 flag will be set properly.

=item C<validate>

Returns an array of human-readable error message if the object must
not be saved and an empty list if nothing's wrong.

=item C<webdav_symlink_basename>

Returns the base name of the symbolic link for the WebDAV C<links>
sub-folder.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
