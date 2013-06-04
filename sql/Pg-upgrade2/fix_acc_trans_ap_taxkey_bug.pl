# @tag: fix_acc_trans_ap_taxkey_bug
# @description: Korrektur falscher Steuerschlüssel in acc_trans bei Eingangsrechnungen
# @depends: release_2_6_0
package SL::DBUpgrade2::fix_acc_trans_ap_taxkey_bug;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  my $q_find = <<SQL;
    SELECT * FROM (
      SELECT
        -- Einige Felder zum Debuggen:
        ap.id, c.accno, c.description AS chartdescription,
        -- Felder, die zum eigentlichen Vergleich und zum spaeteren Update
        -- benoetigt werden:
        ac.acc_trans_id, ac.taxkey AS actual_taxkey,
        -- Zum Rechnungsdatum gueltigen Steuerschluessel fuer Konto auslesen:
        (SELECT tk.taxkey_id
         FROM taxkeys tk
         WHERE (tk.chart_id = c.id)
           AND (tk.startdate <= ap.transdate)
         ORDER BY tk.startdate DESC
         LIMIT 1) AS wanted_taxkey
        FROM acc_trans ac
        LEFT JOIN ap ON (ac.trans_id = ap.id)
        LEFT JOIN chart c ON (ac.chart_id = c.id)
        WHERE
          -- Nur Einkaufsrechnungen, aber keine Kreditorenbuchungen betrachten.
              (ap.id IS NOT NULL)
          AND ap.invoice
          -- Nur Eintraege betrachten, die Konten bebuchen, die fuer die
          -- jeweils aktuelle Rechnung in der dazugehoerigen Buchungsgruppe
          -- angesprochen werden. Die Buchungsgruppen sind all diejenigen,
          -- die in der Rechnung in mindestens einer Position ueber die
          -- Parts verlinkt sind.
          AND (ac.chart_id IN (
                -- Teil 1: Aufwandskonto der Buchungsgruppe fuer die in der
                -- aktuellen Rechnung ausgewaehlte Steuerzone
                SELECT
                  CASE
                    WHEN ap.taxzone_id = 0 THEN bg.expense_accno_id_0
                    WHEN ap.taxzone_id = 1 THEN bg.expense_accno_id_1
                    WHEN ap.taxzone_id = 2 THEN bg.expense_accno_id_2
                    ELSE                        bg.expense_accno_id_3
                  END
                FROM invoice i
                LEFT JOIN parts p ON (i.parts_id = p.id)
                LEFT JOIN buchungsgruppen bg ON (p.buchungsgruppen_id = bg.id)
                WHERE (i.trans_id = ap.id)

                UNION

                -- Teil 2: Inventarkonto der Buchungsgruppe fuer Nicht-Dienstleistungen
                SELECT bg.inventory_accno_id
                FROM invoice i
                LEFT JOIN parts p ON (i.parts_id = p.id)
                LEFT JOIN buchungsgruppen bg ON (p.buchungsgruppen_id = bg.id)
                WHERE (i.trans_id = ap.id)
                  AND (COALESCE(p.inventory_accno_id, 0) <> 0)
              ))
        ORDER BY ap.id
      ) AS the_query
    WHERE the_query.actual_taxkey <> the_query.wanted_taxkey
SQL

  my $q_change = <<SQL;
    UPDATE acc_trans
    SET taxkey = ?
    WHERE acc_trans_id = ?
SQL

  my $h_find   = $self->dbh->prepare($q_find)   || $self->db_error($q_find);
  my $h_change = $self->dbh->prepare($q_change) || $self->db_error($q_change);

  $h_find->execute() || $self->db_error($q_find);

  my $num_changed = 0;

  while (my $ref = $h_find->fetchrow_hashref()) {
    # $::lxdebug->dump(0, "ref", $ref);
    $h_change->execute($ref->{wanted_taxkey}, $ref->{acc_trans_id}) || $self->db_error($q_change);
    $num_changed++;
  }

  $h_find->finish();
  $h_change->finish();

  print $::locale->text('Number of entries changed: #1', $num_changed) . "<br/>\n";

  return 1;
}

1;
