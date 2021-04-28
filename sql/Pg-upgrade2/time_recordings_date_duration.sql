-- @tag: time_recordings_date_duration
-- @description: Erweiterung Zeiterfassung um Datum und Dauer
-- @depends: time_recordings2

ALTER TABLE time_recordings ADD   COLUMN date     DATE;
ALTER TABLE time_recordings ADD   COLUMN duration INTEGER;

UPDATE time_recordings SET date = start_time::DATE;
ALTER TABLE time_recordings ALTER COLUMN start_time DROP NOT NULL;
ALTER TABLE time_recordings ALTER COLUMN date SET NOT NULL;

UPDATE time_recordings SET duration = EXTRACT(EPOCH FROM (end_time - start_time))/60;

-- trigger to set date from start_time
CREATE OR REPLACE FUNCTION time_recordings_set_date_trigger()
RETURNS TRIGGER AS $$
  BEGIN
    IF NEW.start_time IS NOT NULL THEN
      NEW.date = NEW.start_time::DATE;
    END IF;
    RETURN NEW;
  END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER time_recordings_set_date BEFORE INSERT OR UPDATE ON time_recordings FOR EACH ROW EXECUTE PROCEDURE time_recordings_set_date_trigger();

-- trigger to set duration from start_time and end_time
CREATE OR REPLACE FUNCTION time_recordings_set_duration_trigger()
RETURNS TRIGGER AS $$
  BEGIN
    IF NEW.start_time IS NOT NULL AND NEW.end_time IS NOT NULL THEN
      NEW.duration = EXTRACT(EPOCH FROM (NEW.end_time - NEW.start_time))/60;
    END IF;
    RETURN NEW;
  END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER time_recordings_set_duration BEFORE INSERT OR UPDATE ON time_recordings FOR EACH ROW EXECUTE PROCEDURE time_recordings_set_duration_trigger();
