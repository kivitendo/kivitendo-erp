# @tag: charts_without_taxkey
# @description: Fügt für jedes Konto, was keinen Steuerschlüssel hat, den Steuerschlüssel 0 hinzu
# @depends: release_3_0_0
package SL::DBUpgrade2::charts_without_taxkey;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  my ($taxkey0_with_taxes_exists) = $self->dbh->selectrow_array("SELECT COUNT(*) FROM tax WHERE taxkey=0 AND NOT rate=0;");

  if ($taxkey0_with_taxes_exists > 0){
    print_error_message();
    return 0;
  }

  my ($taxkey0_exists) = $self->dbh->selectrow_array("SELECT COUNT(*) FROM tax WHERE taxkey=0");

  if ($taxkey0_exists == 0){
    my $insert_taxkey0 = <<SQL;
INSERT INTO tax
  (rate, taxkey, taxdescription)
  VALUES
  (0, 0, 'Keine Steuer');
SQL
    $self->db_query($insert_taxkey0);
    print $::locale->text("taxkey 0 with taxrate 0 was created.");
  };

  my $insert_taxkeys = <<SQL;
INSERT INTO taxkeys
  (chart_id, tax_id, taxkey_id, startdate)
  SELECT
  c.id, (SELECT id FROM tax WHERE taxkey=0), 0, '1970-01-01'
  FROM chart c WHERE c.id NOT IN (SELECT chart_id FROM taxkeys);
SQL
    $self->db_query($insert_taxkeys);
    return 1;
} # end run

sub print_error_message {
  print $::form->parse_html_template("dbupgrade/taxkey_update");
}

1;
