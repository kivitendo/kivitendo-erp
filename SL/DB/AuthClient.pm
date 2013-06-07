package SL::DB::AuthClient;

use strict;

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

1;
