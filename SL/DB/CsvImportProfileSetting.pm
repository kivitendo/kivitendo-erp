# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::CsvImportProfileSetting;

use strict;

use SL::DB::MetaSetup::CsvImportProfileSetting;
use Rose::DB::Object::Helpers qw(clone);

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

# Helpers' clone_and_reset also kills compund keys like in this case kay+id
sub clone_and_reset {
  my $clone = $_[0]->clone;
  $clone->id(undef);
  return $clone;
}

1;
