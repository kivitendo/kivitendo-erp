-- @tag: invoicing_period
-- @description: Abrechnungszeitraum als Intervall statt Zeitpunkt Leistungsdatum
-- @depends: release_4_0_0

--ALTER TABLE ap              ADD COLUMN tax_point_start        date;
ALTER TABLE ar              ADD COLUMN tax_point_start        date;
ALTER TABLE invoice         ADD COLUMN invoicing_period_start date,
                            ADD COLUMN invoicing_period_end   date;

ALTER TABLE oe              ADD COLUMN tax_point_start        date;
ALTER TABLE orderitems      ADD COLUMN invoicing_period_start date,
                            ADD COLUMN invoicing_period_end   date;

ALTER TABLE delivery_orders ADD COLUMN tax_point_start        date;
