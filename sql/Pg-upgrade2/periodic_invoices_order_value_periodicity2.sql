-- @tag: periodic_invoices_order_value_periodicity2
-- @description:periodic_invoices_configs_valid_periodicity Wiederkehrende Rechnungen: Einstellung für Periode, auf die sich der Auftragswert bezieht
-- @depends: release_3_4_1 periodic_invoices_order_value_periodicity

-- Spalte »periodicity«: Erweiterung um Periode o (one time). Einmalige Ausführung
ALTER TABLE periodic_invoices_configs
DROP CONSTRAINT periodic_invoices_configs_valid_periodicity;

ALTER TABLE periodic_invoices_configs
ADD CONSTRAINT periodic_invoices_configs_valid_periodicity
CHECK (periodicity IN ('o', 'm', 'q', 'b', 'y'));
