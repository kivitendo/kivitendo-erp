-- @tag: remove_taxkey_15_17_skr04
-- @description: Steuer mit Schlüssel 15 und 17 (16%) für SKR04 entfernen, wenn nicht verknüpft
-- @depends: release_3_5_5

DELETE FROM tax
  WHERE (SELECT coa FROM defaults) LIKE 'Germany-DATEV-SKR04EU'
    AND taxkey = 17
    AND chart_id = (SELECT chart_id FROM chart WHERE accno LIKE '1403')
    AND rate = .16
    AND NOT EXISTS (SELECT id FROM taxkeys WHERE tax_id = tax.id)
    AND NOT EXISTS (SELECT id FROM acc_trans WHERE tax_id = tax.id);

DELETE FROM tax
  WHERE (SELECT coa FROM defaults) LIKE 'Germany-DATEV-SKR04EU'
    AND taxkey = 15
    AND chart_id = (SELECT chart_id FROM chart WHERE accno LIKE '3803')
    AND rate = .16
    AND NOT EXISTS (SELECT id FROM taxkeys WHERE tax_id = tax.id)
    AND NOT EXISTS (SELECT id FROM acc_trans WHERE tax_id = tax.id);
