# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::ContactDepartment;

use strict;

use SL::Util qw(trim);

use SL::DB::MetaSetup::ContactDepartment;
use SL::DB::Manager::ContactDepartment;

__PACKAGE__->meta->initialize;

__PACKAGE__->before_save('_before_save_trim_content');

sub _before_save_trim_content {
  $_[0]->description(trim($_[0]->description));
  return 1;
}

1;
