-- @tag: re_add_sepa_export_items_foreign_keys
-- @description: Versehentlich gelöschte Fremdschlüssel in sepa_export_items wieder hinzufügen
-- @depends: auto_delete_sepa_export_items_on_ap_ar_deletion
ALTER TABLE sepa_export_items
  DROP CONSTRAINT IF EXISTS sepa_export_items_chart_id_fkey,
  ADD CONSTRAINT sepa_export_items_chart_id_fkey
    FOREIGN KEY (chart_id) REFERENCES chart (id);

ALTER TABLE sepa_export_items
  DROP CONSTRAINT IF EXISTS sepa_export_items_sepa_export_id_fkey,
  ADD CONSTRAINT sepa_export_items_sepa_export_id_fkey
    FOREIGN KEY (sepa_export_id) REFERENCES sepa_export (id)
    ON DELETE CASCADE;
