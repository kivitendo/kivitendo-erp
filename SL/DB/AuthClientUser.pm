package SL::DB::AuthClientUser;

use strict;

use SL::DB::MetaSetup::AuthClientUser;

__PACKAGE__->meta->initialize;

__PACKAGE__->meta->make_manager_class;

1;
