-- @tag: sepa_recommended_execution_date
-- @description: Einstellung, ob das Ausführungsdatum für SEPA-Überweisung vorbelegt werden soll (Fälligkeit/Skontotermin)
-- @depends: release_3_5_2

ALTER TABLE defaults ADD COLUMN sepa_set_duedate_as_default_exec_date boolean DEFAULT FALSE;
ALTER TABLE defaults ADD COLUMN sepa_set_skonto_date_as_default_exec_date boolean DEFAULT FALSE;
ALTER TABLE defaults ADD COLUMN sepa_set_skonto_date_buffer_in_days integer DEFAULT 0;
