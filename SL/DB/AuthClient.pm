package SL::DB::AuthClient;

use strict;

use SL::DB::MetaSetup::AuthClient;
use SL::DB::Manager::AuthClient;

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

1;
