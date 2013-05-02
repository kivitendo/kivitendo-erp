# @tag: auth_enable_edit_prices
# @description: Zusätzliches Recht readonly für das Attribut readonly bei Preisen und Rabatten im Textfeld. Das Skript hakt standardmässig dieses Recht an, sodass es keinen Unterschied zu vorhergehenden Version gibt.
# @depends: release_2_6_3
package SL::DBUpgrade2::auth_enable_edit_prices;

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
        AND (auth.group_rights."right"  = 'edit_prices')
    )
SQL

  my @group_ids = selectall_array_query($::form, $self->dbh, $query);
  if (@group_ids) {
    $query = <<SQL;
      INSERT INTO auth.group_rights (group_id, "right",          granted)
      VALUES                        (?,        'edit_prices', TRUE)
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
