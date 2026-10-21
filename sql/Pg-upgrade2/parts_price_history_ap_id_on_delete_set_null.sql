-- @tag: parts_price_history_ap_id_on_delete_set_null
-- @description: Preishistorie: beim Löschen einer Einkaufsrechnung den Verweis auf NULL setzen
-- @depends: release_4_1_0
ALTER TABLE parts_price_history
  DROP CONSTRAINT IF EXISTS parts_price_history_ap_id_fkey,
  ADD CONSTRAINT parts_price_history_ap_id_fkey
    FOREIGN KEY (ap_id) REFERENCES ap (id)
    ON DELETE SET NULL;
