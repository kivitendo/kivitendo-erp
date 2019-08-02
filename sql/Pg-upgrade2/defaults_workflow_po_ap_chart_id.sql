-- @tag: defaults_workflow_po_ap_chart_id
-- @description: Voreingestelltes Konto für Workflow Lieferantenauftrag -> Kreditorenbuchung
-- @depends: release_3_5_4

ALTER TABLE defaults ADD COLUMN workflow_po_ap_chart_id INTEGER;
