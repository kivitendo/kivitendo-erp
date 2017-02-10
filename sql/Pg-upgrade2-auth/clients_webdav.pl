# @tag: clients_webdav
# @description: WebDAV-Migration für Mandanten
# @depends: clients
# @ignore: 0
package SL::DBUpgrade2::Auth::clients_webdav;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use File::Find ();
use File::Path qw(make_path);
use IO::Dir;
use List::MoreUtils qw(any all);
use List::Util qw(first);

use SL::DBConnect;
use SL::DBUtils;
use SL::Template;
use SL::Helper::Flash;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(clients old_folders) ],
);

sub init_clients {
  my ($self) = @_;
  return [ selectall_hashref_query($::form, $self->dbh, qq|SELECT * FROM auth.clients ORDER BY lower(name)|) ];
}

sub init_old_folders {
  tie my %dir, 'IO::Dir', 'webdav';
  return [ sort grep { -d } keys %dir ];
}

sub _unlink_old_folders {
  my ($self, %params) = @_;

  rmdir $_ for @{ $self->old_folders };

  return 1;
}

sub _ensure_one_client_exists {
  my ($self, %params) = @_;

  return if 0 != scalar @{ $self->clients };

  my $sql = <<SQL;
    INSERT INTO auth.clients (name, dbhost, dbport, dbname, dbuser, dbpasswd, is_default)
    VALUES                   (?,    ?,      5432,   ?,      ?,      ?,        true)
SQL

  $self->dbh->do($sql, undef, $::locale->text('Default Client (unconfigured)'), ($::locale->text('unconfigured')) x 4);

  undef $self->{clients};
}

sub _move_files_into {
  my ($self, $client) = @_;

  tie my %dir, 'IO::Dir', 'webdav';
  my @entries = grep { !m/^\.\.?$/ } keys %dir;

  make_path('webdav/' . $client->{id});
  rename "webdav/$_", "webdav/" . $client->{id} . "/$_" for @entries;
}

sub _create_folders {
  my ($self, $client) = @_;
  make_path('webdav/' . $client->{id} . "/$_") for qw(angebote bestellungen anfragen lieferantenbestellungen verkaufslieferscheine einkaufslieferscheine gutschriften rechnungen einkaufsrechnungen);
}

sub _create_symlink {
  my ($self, $client) = @_;

  my $name =  $client->{name} // '';
  $name    =~ s:/+:_:g;

  make_path('webdav/links');
  symlink '../' . $client->{id}, "webdav/links/${name}";
}

sub _webdav_folders_used {
  my ($self, %params) = @_;

  my $contains_files  = 0;
  my $wanted          = sub {
    $contains_files   = 1 if -f && !m{/(?:\.gitignore|.dummy|webdav-user)$};
  };

  File::Find::find({ wanted => $wanted, no_chdir => 1 }, 'webdav');

  return $contains_files;
}

sub run {
  my ($self) = @_;

  # WebDAV not used? Remove old folders, and we're done.
  return $self->_unlink_old_folders if !$self->_webdav_folders_used;

  # Ensure at least one client exists.
  $self->_ensure_one_client_exists;

  my $client_to_use;
  if (1 == scalar @{ $self->clients }) {
    # Exactly one client? Great, use that one without bothering the
    # user.
    $client_to_use = $self->clients->[0];

  } else {
    # If there's more than one client then let the user select which
    # client to move the old files into. Maybe she already did?
    $client_to_use = first { $_->{id} == $::form->{client_id} } @{ $self->clients } if $::form->{client_id};

    if (!$client_to_use) {
      # Nope, let's select it.
      print $::form->parse_html_template('dbupgrade/auth/clients_webdav', { SELF => $self, default_client => (first { $_->{is_default} } @{ $self->clients }) });
      return 2;
    }
  }

  # Move files for the selected client.
  $self->_move_files_into($client_to_use);

  # Create the directory structures for all (even the selected client
  # -- folders might be missing).
  for (@{ $self->clients }) {
    $self->_create_folders($_);
    $self->_create_symlink($_);
  }

  return 1;
}

1;
