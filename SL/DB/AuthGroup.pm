package SL::DB::AuthGroup;

use strict;

use SL::DB::MetaSetup::AuthGroup;
use SL::DB::Manager::AuthGroup;
use SL::DB::AuthGroupRight;

__PACKAGE__->meta->add_relationship(
  users => {
    type      => 'many to many',
    map_class => 'SL::DB::AuthUserGroup',
    map_from  => 'group',
    map_to    => 'user',
  },
  rights => {
    type       => 'one to many',
    class      => 'SL::DB::AuthGroupRight',
    column_map => { id => 'group_id' },
  },
  clients => {
    type      => 'many to many',
    map_class => 'SL::DB::AuthClientGroup',
    map_from  => 'group',
    map_to    => 'client',
  },
);

__PACKAGE__->meta->initialize;

sub get_employees {
  my @logins = map { $_->login } $_[0]->users;
  return @logins ? @{ SL::DB::Manager::Employee->get_all(query => [ login => \@logins ]) } : ();
}

1;
