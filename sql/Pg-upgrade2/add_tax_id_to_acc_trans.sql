-- @tag: add_tax_id_to_acc_trans
-- @description: Neue Spalte tax_id in der acc_trans
-- @depends: release_3_0_0 charts_without_taxkey

  --Neue Spalte tax_id in acc_trans:
  ALTER TABLE acc_trans ADD tax_id integer;

  --Spalte mit Werten füllen:
  UPDATE acc_trans ac SET tax_id=
                (SELECT tk.tax_id FROM taxkeys tk 
                      WHERE tk.taxkey_id=ac.taxkey 
                      AND tk.startdate <= COALESCE(
                            (SELECT ar.deliverydate FROM ar WHERE ar.id=ac.trans_id), 
                            (SELECT ar.transdate FROM ar WHERE ar.id=ac.trans_id), 
                            (SELECT ap.transdate FROM ap WHERE ap.id=ac.trans_id), 
                            (SELECT gl.transdate FROM gl WHERE gl.id=ac.trans_id), 
                            ac.transdate )
                      ORDER BY startdate DESC LIMIT 1);

  --Spalten, die noch null sind (nur bei Einträgen möglich, wo auch taxkey null ist)
  UPDATE acc_trans SET tax_id= (SELECT id FROM tax WHERE taxkey=0 LIMIT 1) WHERE tax_id IS NULL;
 
  --tax_id als Pflichtfeld definieren:
  ALTER TABLE acc_trans ALTER tax_id SET NOT NULL;

