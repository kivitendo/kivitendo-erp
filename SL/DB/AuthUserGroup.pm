package SL::DB::AuthUserGroup;

use strict;

use SL::DB::MetaSetup::AuthUserGroup;

__PACKAGE__->meta->initialize;

__PACKAGE__->meta->make_manager_class;

1;
