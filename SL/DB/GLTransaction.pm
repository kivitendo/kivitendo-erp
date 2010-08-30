package SL::DB::GLTransaction;

use strict;

use SL::DB::MetaSetup::GLTransaction;

for my $field (qw(transdate gldate)) {
  __PACKAGE__->attr_date($field);
}

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

1;
