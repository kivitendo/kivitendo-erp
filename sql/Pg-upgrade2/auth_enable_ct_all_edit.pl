# @tag: auth_enable_ct_all_edit
# @description: Zusätzliches Recht alle Kunden / Lieferanten editieren, war bisher standardmäßig IMMER so und kann jetzt deaktiviert werden
#               falls es deaktiviert wird, kann ich den Kunden / Lieferanten nur editieren wenn ich selber als Verkäufer eingetragen bin
# @depends: release_2_6_3
package SL::DBUpgrade2::auth_enable_ct_all_edit;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  $self->dbh($::auth->dbconnect);
  my $query = <<SQL;
    SELECT id
    FROM auth."group"
    WHERE NOT EXISTS(
      SELECT group_id
      FROM auth.group_rights
      WHERE (auth.group_rights.group_id = auth."group".id)
        AND (auth.group_rights."right"  = 'customer_vendor_all_edit')
    )
SQL

  my @group_ids = selectall_array_query($::form, $self->dbh, $query);
  if (@group_ids) {
    $query = <<SQL;
      INSERT INTO auth.group_rights (group_id, "right",          granted)
      VALUES                        (?,        'customer_vendor_all_edit', TRUE)
SQL
    my $sth = prepare_query($::form, $self->dbh, $query);

    foreach my $id (@group_ids) {
      do_statement($::form, $sth, $query, $id);
    }

    $sth->finish();
    $self->dbh->commit();
  }

  return 1;
}

1;
