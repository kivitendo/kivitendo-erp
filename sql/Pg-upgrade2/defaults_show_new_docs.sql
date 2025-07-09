-- @tag: defaults_show_new_docs
-- @description: Mandantenkonfiguration für Anzeigen von Angebots-/Auftrags-Eingängen, Lieferantenauftragsbestätigungen und Reklamationen
-- @depends: release_3_9_0

ALTER TABLE defaults ADD COLUMN show_sales_order_intake          BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN show_purchase_quotation_intake   BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN show_purchase_order_confirmation BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN show_sales_reclamation           BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN show_purchase_reclamation        BOOLEAN NOT NULL DEFAULT TRUE;
