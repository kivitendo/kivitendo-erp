# @tag: employee_id_foreignkeys
# @description: Falls ein Benutzer hart in der Datenbank gelöscht werden soll, entsprechende Fremdschlüssel setzen, entfernt ferner verwaiste Einträge
# @depends: release_3_0_0
package SL::DBUpgrade2::employee_id_foreignkeys;

use utf8;

use parent qw(SL::DBUpgrade2::Base);
use strict;

sub run {
  my ($self) = @_;

  # this query will fail if we have orphaned entries
  # should only occur
  $self->db_query(qq|UPDATE customer set salesman_id = NULL where salesman_id not in (select id from employee)|, may_fail => 0);
  $self->db_query(qq|UPDATE vendor set salesman_id = NULL where salesman_id not in (select id from employee)|, may_fail => 0);
  $self->db_query(qq|ALTER TABLE customer ADD FOREIGN KEY (salesman_id) REFERENCES employee (id)|, may_fail => 0);
  $self->db_query(qq|ALTER TABLE vendor ADD FOREIGN KEY (salesman_id) REFERENCES employee (id)|, may_fail => 0);

  return 1;
}

1;
