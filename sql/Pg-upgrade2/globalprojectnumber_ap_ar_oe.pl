# @tag: globalprojectnumber_ap_ar_oe
# @description: Neue Spalte f&uuml;r eine globale Projektnummer in Einkaufs- und Verkaufsbelegen
# @depends: release_2_4_1
package SL::DBUpgrade2::globalprojectnumber_ap_ar_oe;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  my @queries =
    ("ALTER TABLE ap ADD COLUMN globalproject_id integer;",
     "ALTER TABLE ap ADD FOREIGN KEY (globalproject_id) REFERENCES project (id);",
     "ALTER TABLE ar ADD COLUMN globalproject_id integer;",
     "ALTER TABLE ar ADD FOREIGN KEY (globalproject_id) REFERENCES project (id);",
     "ALTER TABLE oe ADD COLUMN globalproject_id integer;",
     "ALTER TABLE oe ADD FOREIGN KEY (globalproject_id) REFERENCES project (id);");

  $self->db_query("ALTER TABLE project ADD PRIMARY KEY (id)", may_fail => 1);
  $self->db_query($_) for @queries;

  return 1;
}

1;
