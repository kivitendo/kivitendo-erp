# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::AuthGroup;

use strict;

use SL::DB::MetaSetup::AuthGroup;
use SL::DB::AuthGroupRight;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

__PACKAGE__->meta->schema('auth');

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
);

__PACKAGE__->meta->initialize;

sub get_employees {
  my @logins = map { $_->login } $_[0]->users;
  return @logins ? @{ SL::DB::Manager::Employee->get_all(query => [ login => \@logins ]) } : ();
}

1;
