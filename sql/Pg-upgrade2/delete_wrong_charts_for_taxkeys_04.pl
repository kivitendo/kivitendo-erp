# @tag: delete_wrong_charts_for_taxkeys_04
# @description: SKR04: Uralte falsch angelegte Automatikkonten raus -> Chance auf tax.chart_id unique setzen
# @depends: release_3_6_0
# @ignore: 0
package SL::DBUpgrade2::delete_wrong_charts_for_taxkeys_04;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub delete_chart_id_tax {
  my $self = shift;

  my $q_fetch = <<SQL;
    SELECT chart_id
    FROM tax where chart_id is not null
    GROUP BY chart_id HAVING COUNT(*) > 1
SQL

  # SKR04
  my $q_update_04 = <<SQL;
    UPDATE tax
    SET chart_id = NULL
    WHERE chart_id = ?
    AND rate = 0.16
    AND (taxkey = 3 OR taxkey = 9)
    AND EXISTS (SELECT * FROM defaults WHERE coa = 'Germany-DATEV-SKR04EU')
SQL


  my $h_fetch = $self->dbh->prepare($q_fetch);
  $h_fetch->execute || $::form->dberror($q_fetch);

  my $h_update_04 = $self->dbh->prepare($q_update_04);

  while (my $entry = $h_fetch->fetchrow_hashref) {
    $h_update_04->execute($entry->{chart_id}) || $::form->dberror($q_update_04);
  }
  # might be unique now
  $h_fetch->execute || $::form->dberror($q_fetch);

  if (!$h_fetch->fetchrow_hashref) {
    my $q_unique = <<SQL;
      alter table tax
      ADD CONSTRAINT chart_id_unique_tax UNIQUE (chart_id)
SQL
    my $q_unique_p = $self->dbh->prepare($q_unique);
    $q_unique_p->execute || $::form->dberror($q_unique_p);
  }
}

sub run {
  my ($self) = @_;

  return 1 unless $self->check_coa('Germany-DATEV-SKR04EU');

  $self->delete_chart_id_tax;

  return 1;
}

1;
