-- @tag: periodic_invoices_order_value_periodicity
-- @description: Wiederkehrende Rechnungen: Einstellung für Periode, auf die sich der Auftragswert bezieht
-- @depends: release_3_1_0

-- Spalte »periodicity«: nur ein Zeichen, und Check auf gültige Werte
ALTER TABLE periodic_invoices_configs
ADD CONSTRAINT periodic_invoices_configs_valid_periodicity
CHECK (periodicity IN ('m', 'q', 'b', 'y'));

ALTER TABLE periodic_invoices_configs
ALTER COLUMN periodicity TYPE varchar(1);

-- Neue Spalte »order_value_periodicity«
ALTER TABLE periodic_invoices_configs
ADD COLUMN order_value_periodicity varchar(1);

UPDATE periodic_invoices_configs
SET order_value_periodicity = 'p';

ALTER TABLE periodic_invoices_configs
ALTER COLUMN order_value_periodicity
SET NOT NULL;

ALTER TABLE periodic_invoices_configs
ADD CONSTRAINT periodic_invoices_configs_valid_order_value_periodicity
CHECK (order_value_periodicity IN ('p', 'm', 'q', 'b', 'y', '2', '3', '4', '5'));
