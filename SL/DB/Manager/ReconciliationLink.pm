# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Manager::ReconciliationLink;

use strict;

use SL::DBUtils;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::ReconciliationLink' }

__PACKAGE__->make_manager_methods;

sub get_new_rec_group {
  my $class = shift;

  my $query = qq|SELECT max(rec_group) FROM reconciliation_links|;

  my ($max) = selectfirst_array_query($::form, $class->object_class->init_db->dbh, $query);

  return ($max // 0) + 1;
}

1;
