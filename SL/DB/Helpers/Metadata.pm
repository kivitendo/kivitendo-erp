package SL::DB::Helpers::Metadata;

use strict;

use Rose::DB::Object::Metadata;
use SL::DB::Helpers::ConventionManager;

use base qw(Rose::DB::Object::Metadata);

sub convention_manager_class {
  return 'SL::DB::Helpers::ConventionManager';
}

sub default_manager_base_class {
  return 'SL::DB::Helpers::Manager';
}

1;
