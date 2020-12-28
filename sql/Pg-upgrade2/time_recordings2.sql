-- @tag: time_recordings2
-- @description: Ergänzung zur Zeiterfassung
-- @depends: time_recordings
ALTER TABLE time_recordings ADD column booked boolean DEFAULT false;
ALTER TABLE time_recordings ADD column payroll boolean DEFAULT false;

