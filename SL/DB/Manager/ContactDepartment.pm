# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Manager::ContactDepartment;

use strict;

use parent qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;
use SL::DBUtils;

sub object_class { 'SL::DB::ContactDepartment' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'description', 1 ],
           columns => { SIMPLE => 'ALL',
                        map { ( $_ => "lower(contact_departments.$_)" ) } qw(description)
                      });
}

sub delete_unused {
  my ($class) = @_;

  my $dbh  = $::form->get_standard_dbh();

  my $sql_str = qq|DELETE FROM contact_departments cd
                   WHERE NOT EXISTS (
                     SELECT
                     FROM contacts c
                     WHERE c.cp_abteilung IS NOT NULL AND c.cp_abteilung = cd.description
                   )|;

  do_query($::form, $dbh, $sql_str);
}

1;
