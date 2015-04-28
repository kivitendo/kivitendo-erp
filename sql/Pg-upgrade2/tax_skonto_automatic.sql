-- @tag: tax_skonto_automatic
-- @description: Skontoautomatikkonten für Steuern mit minimaler Vorbelegung
-- @depends: release_3_2_0
-- @ignore: 0

ALTER TABLE tax ADD COLUMN skonto_sales_chart_id integer;
ALTER TABLE tax ADD FOREIGN KEY (skonto_sales_chart_id) REFERENCES chart (id);
ALTER TABLE tax ADD COLUMN skonto_purchase_chart_id integer;
ALTER TABLE tax ADD FOREIGN KEY (skonto_purchase_chart_id) REFERENCES chart (id);

UPDATE tax SET skonto_purchase_chart_id = (SELECT id FROM chart WHERE description LIKE '%Erhaltene Skonti %19%' limit 1) WHERE rate = '0.19' AND ( taxkey >= 7 AND taxkey <= 9 );
UPDATE tax SET skonto_purchase_chart_id = (SELECT id FROM chart WHERE description LIKE '%Erhaltene Skonti 7%' limit 1) WHERE rate = '0.07' AND ( taxkey >= 7 AND taxkey <= 9 );
UPDATE tax SET skonto_purchase_chart_id = (SELECT id FROM chart WHERE description LIKE '%Erhaltene Skonti %16%' limit 1) WHERE rate = '0.16' AND ( taxkey = 7 );
UPDATE tax SET skonto_sales_chart_id = (SELECT id FROM chart WHERE description LIKE '%Gewährte Skonti 7%' limit 1) WHERE rate = '0.07' AND ( taxkey >= 2 AND taxkey <= 5 );
UPDATE tax SET skonto_sales_chart_id = (SELECT id FROM chart WHERE description LIKE '%Gewährte Skonti %19%' limit 1) WHERE rate = '0.19' AND ( taxkey >= 2 AND taxkey <= 5 );
UPDATE tax SET skonto_sales_chart_id = (SELECT id FROM chart WHERE description LIKE '%Gewährte Skonti %16%' limit 1) WHERE rate = '0.16' AND ( taxkey = 5 );
UPDATE tax SET skonto_sales_chart_id = (SELECT id FROM chart WHERE description LIKE 'Gewährte Skonti' limit 1) WHERE rate = '0' AND ( taxkey = 0 or taxkey = 1 );
UPDATE tax SET skonto_purchase_chart_id = (SELECT id FROM chart WHERE description LIKE 'Erhaltene Skonti' limit 1) WHERE rate = '0' AND ( taxkey = 0 or taxkey = 1 );
