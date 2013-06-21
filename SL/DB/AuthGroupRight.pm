package SL::DB::AuthGroupRight;

use strict;

use SL::DB::MetaSetup::AuthGroupRight;

__PACKAGE__->meta->initialize;

__PACKAGE__->meta->make_manager_class;

1;
