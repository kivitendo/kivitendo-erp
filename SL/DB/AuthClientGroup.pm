package SL::DB::AuthClientGroup;

use strict;

use SL::DB::MetaSetup::AuthClientGroup;

__PACKAGE__->meta->initialize;

__PACKAGE__->meta->make_manager_class;

1;
