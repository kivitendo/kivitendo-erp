-- @tag: add_chart_link_to_acc_trans
-- @description: Neue Spalte chart_link in der acc_trans
-- @depends: release_3_0_0 acc_trans_constraints

--Spalte link in der chart updaten:
UPDATE chart SET link = '' WHERE link IS NULL;

--chart.link als Pflichtfeld definieren:
ALTER TABLE chart ALTER link SET NOT NULL;

--neue Spalte chart_link zur acc_trans hinzufügen:
ALTER TABLE acc_trans ADD COLUMN chart_link text;

--Spalte mit Werten füllen:
UPDATE acc_trans SET chart_link = (SELECT link FROM chart WHERE id=chart_id);

--Spalte acc_trans.chart_link als Pflichtfeld definieren:
ALTER TABLE acc_trans ALTER chart_link SET NOT NULL;
