-- @tag: get_shipped_qty_config
-- @description: Mandantenweite Konfiguration für das Verhalten von Liefermengenabgleich
-- @depends: release_3_4_1

ALTER TABLE defaults ADD COLUMN shipped_qty_require_stock_out    BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE defaults ADD COLUMN shipped_qty_fill_up              BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN shipped_qty_item_identity_fields TEXT[] NOT NULL DEFAULT '{parts_id}';


