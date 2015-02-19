-- @tag: defaults_sales_purchase_order_show_ship_missing_column
-- @description: Mandantenkonfiguration: Optionale Spalte »Nicht gelieferte Menge« in Auftragsbestätigungen und Lieferantenaufträgen
-- @depends: release_3_1_0

ALTER TABLE defaults ADD COLUMN sales_purchase_order_ship_missing_column BOOLEAN;
UPDATE defaults SET sales_purchase_order_ship_missing_column = FALSE;
ALTER TABLE defaults ALTER COLUMN sales_purchase_order_ship_missing_column SET DEFAULT FALSE;
