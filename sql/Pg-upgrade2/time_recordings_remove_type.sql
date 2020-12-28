-- @tag: time_recordings_remove_type
-- @description: Zeiterfassungs-Typen entfernen
-- @depends: time_recordings time_recordings2

ALTER TABLE time_recordings DROP column type_id;
DROP TABLE time_recording_types;
