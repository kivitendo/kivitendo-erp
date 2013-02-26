-- @tag: add_chart_link_to_acc_trans
-- @description: Neue Spalte chart_link in der acc_trans
-- @depends: release_3_0_0 

--neue Spalte hinzufügen:
ALTER TABLE acc_trans ADD COLUMN chart_link text;

--Spalte mit Werten füllen:
UPDATE acc_trans SET chart_link = (SELECT link FROM chart WHERE id=chart_id);

--Spalte als Pflichtfeld definieren:
ALTER TABLE acc_trans ALTER chart_link SET NOT NULL;
