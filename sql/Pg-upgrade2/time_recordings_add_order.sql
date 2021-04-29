-- @tag: time_recordings_add_order
-- @description: Erweiterung Zeiterfassung um Fremdschlüssel zu Auftrag
-- @depends: time_recordings_date_duration

ALTER TABLE time_recordings ADD COLUMN order_id INTEGER REFERENCES oe (id);
