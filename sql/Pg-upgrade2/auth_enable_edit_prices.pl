# @tag: auth_enable_edit_prices
# @description: Zusätzliches Recht readonly für das Attribut readonly bei Preisen und Rabatten im Textfeld. Das Skript hakt standardmässig dieses Recht an, sodass es keinen Unterschied zu vorhergehenden Version gibt.
# @depends: release_2_6_3
# @charset: utf-8

use utf8;
use strict;
use Data::Dumper;
die("This script cannot be run from the command line.") unless ($main::form);

sub mydberror {
  my ($msg) = @_;
  die($dbup_locale->text("Database update error:") .
      "<br>$msg<br>" . $DBI::errstr);
}

sub do_update {
  my $dbh   = $main::auth->dbconnect();
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

  my @group_ids = selectall_array_query($form, $dbh, $query);
  if (@group_ids) {
    $query = <<SQL;
      INSERT INTO auth.group_rights (group_id, "right",          granted)
      VALUES                        (?,        'edit_prices', TRUE)
SQL
    my $sth = prepare_query($form, $dbh, $query);

    foreach my $id (@group_ids) {
      do_statement($form, $sth, $query, $id);
    }

    $sth->finish();
    $dbh->commit();
  }

  return 1;
}

return do_update();

