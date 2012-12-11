-- @tag: add_tax_id_to_acc_trans
-- @description: Neue Spalte tax_id in der acc_trans
-- @depends: release_2_7_0 

  --Neue Spalte tax_id in acc_trans:
  ALTER TABLE acc_trans ADD tax_id integer;

  --Spalte mit Werten füllen:
  UPDATE acc_trans ac SET tax_id=
                (select tk.tax_id from taxkeys tk 
                      where tk.taxkey_id=ac.taxkey 
                      AND tk.startdate <= COALESCE(
                            (select ar.deliverydate from ar where ar.id=ac.trans_id), 
                            (select ar.transdate from ar where ar.id=ac.trans_id), 
                            (select ap.transdate from ap where ap.id=ac.trans_id), 
                            (select gl.transdate from gl where gl.id=ac.trans_id), 
                            ac.transdate )
                      order by startdate desc limit 1);

  --Spalten, die noch null sind (nur bei Einträgen möglich, wo auch taxkey null ist)
  UPDATE acc_trans SET tax_id=0 where tax_id is null;
 
  --tax_id als Pflichtfeld definieren:
  ALTER TABLE acc_trans ALTER tax_id SET NOT NULL;

