package SL::DB::AuthClient;

use strict;

use Carp;
use File::Path ();

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

  $self->ensure_webdav_symlink_correctness($self->{__before_save_remember_old_name}) if $self->id && $::lx_office_conf{features}->{webdav};
  return 1;
}

sub _after_delete_delete_webdav_symlink {
  my ($self) = @_;

  return 1 if !$::lx_office_conf{features}->{webdav};
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

  return unless $::lx_office_conf{features}->{webdav};

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

1;
