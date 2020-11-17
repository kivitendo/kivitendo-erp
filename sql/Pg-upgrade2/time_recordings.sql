-- @tag: time_recordings
-- @description: Tabellen zur Zeiterfassung
-- @depends: release_3_5_6_1

CREATE TABLE time_recording_types (
  id                 SERIAL,
  abbreviation       TEXT     NOT NULL,
  description        TEXT,
  position           INTEGER  NOT NULL,
  obsolete           BOOLEAN  NOT NULL DEFAULT false,
  PRIMARY KEY (id)
);

CREATE TABLE time_recordings (
  id                SERIAL,
  customer_id       INTEGER   NOT NULL,
  project_id        INTEGER,
  start_time        TIMESTAMP NOT NULL,
  end_time          TIMESTAMP,
  type_id           INTEGER,
  description       TEXT      NOT NULL,
  staff_member_id   INTEGER   NOT NULL,
  employee_id       INTEGER   NOT NULL,
  itime             TIMESTAMP NOT NULL DEFAULT now(),
  mtime             TIMESTAMP NOT NULL DEFAULT now(),

  PRIMARY KEY (id),
  FOREIGN KEY (customer_id)     REFERENCES customer (id),
  FOREIGN KEY (staff_member_id) REFERENCES employee (id),
  FOREIGN KEY (employee_id)     REFERENCES employee (id),
  FOREIGN KEY (project_id)      REFERENCES project (id),
  FOREIGN KEY (type_id)         REFERENCES time_recording_types (id)
);

CREATE TRIGGER mtime_time_recordings BEFORE UPDATE ON time_recordings FOR EACH ROW EXECUTE PROCEDURE set_mtime();
