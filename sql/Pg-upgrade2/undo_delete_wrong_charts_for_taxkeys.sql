-- @tag: undo_delete_wrong_charts_for_taxkeys
-- @description: chart_id kann doch mehrdeutig sein in der Tabelle für SKR04
-- @depends: release_3_7_0 delete_wrong_charts_for_taxkeys delete_wrong_charts_for_taxkeys_04
ALTER TABLE tax DROP CONSTRAINT IF EXISTS chart_id_unique_tax;
-- skr04

update tax set chart_id = (select chart_id from tax where chart_id is not null and taxkey=7 and rate=0.16) where chart_id is null
AND taxkey=9 and rate=0.16 AND EXISTS (SELECT * FROM defaults WHERE coa = 'Germany-DATEV-SKR04EU');

update tax set chart_id = (select chart_id from tax where chart_id is not null and taxkey=5 and rate=0.16) where chart_id is null and taxkey=3 and rate=0.16
AND EXISTS (SELECT * FROM defaults WHERE coa = 'Germany-DATEV-SKR04EU');

