package SL::DB::AuthUserConfig;

use strict;

use SL::DB::MetaSetup::AuthUserConfig;

__PACKAGE__->meta->initialize;

__PACKAGE__->meta->make_manager_class;

1;
